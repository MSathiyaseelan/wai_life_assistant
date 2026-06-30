import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/constants/api_endpoints.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/ai_parser.dart';
import 'package:wai_life_assistant/core/services/contact_service.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/dashboard/ai_assistant/intent_classifier.dart';
import 'package:wai_life_assistant/features/dashboard/ai_assistant/context_fetcher.dart';
import 'package:wai_life_assistant/features/dashboard/ai_assistant/assistant_response.dart';
import 'package:wai_life_assistant/features/dashboard/ai_assistant/action_executor.dart';
import 'package:wai_life_assistant/features/wallet/ai/IntentConfirmSheet.dart';
import 'package:wai_life_assistant/features/wallet/screens/sms_history_import_screen.dart';
import 'package:wai_life_assistant/features/wallet/services/sms_parser_service.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AIAssistantWidget
// Dark gradient AI bar with intent classification, context fetching,
// structured response display (highlights, suggestions, deep-links) and
// write-action confirmation (add grocery, task, reminder, expense, etc.).
// ─────────────────────────────────────────────────────────────────────────────

class AIAssistantWidget extends StatefulWidget {
  final List<WalletModel> wallets;
  final void Function(int tabIndex)? onNavigate;
  final void Function(TxModel tx)? onTransactionSaved;

  const AIAssistantWidget({
    super.key,
    required this.wallets,
    this.onNavigate,
    this.onTransactionSaved,
  });

  @override
  State<AIAssistantWidget> createState() => _AIAssistantWidgetState();
}

class _AIAssistantWidgetState extends State<AIAssistantWidget>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  bool _loading = false;
  AssistantResponse? _response;

  // Action confirmation state
  bool _confirmingAction = false;
  bool _actionDone = false;
  String? _actionSuccessMsg;

  // Contact mention (@)
  List<ContactEntry> _suggestions = [];
  bool _showSuggestions = false;
  int? _mentionStart;

  // Speech-to-text
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  // Active wallet for saving actions — may differ from appState.activeWalletId
  // when the user picks a different wallet in the confirmation card.
  String _selectedWalletId = '';

  // Paste SMS loading
  bool _smsLoading = false;

  // Usage limit
  bool _limitChecking = true;
  bool _limitReached = false;
  int _monthlyUsed = 0;
  int _monthlyLimit = 20;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  static const _quickQuestions = [
    'How much did I spend this month?',
    'Any upcoming appointments?',
    'What\'s on my grocery list?',
    'My active medications?',
    'Any upcoming functions?',
    'Summarise my finances',
  ];

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.wallets.isNotEmpty ? widget.wallets.first.id : '';
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _focus.addListener(() => setState(() {}));
    _ctrl.addListener(_onMentionChanged);
    ContactService.instance.preload();
    _checkLimitOnOpen();
  }

  @override
  void didUpdateWidget(AIAssistantWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallets != widget.wallets && widget.wallets.isNotEmpty) {
      final stillValid = widget.wallets.any((w) => w.id == _selectedWalletId);
      if (!stillValid) _selectedWalletId = widget.wallets.first.id;
    }
  }

  Future<void> _checkLimitOnOpen() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) { setState(() => _limitChecking = false); return; }
      final month =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
      final usageRow = await client
          .from('feature_usage')
          .select('count')
          .eq('user_id', userId)
          .eq('feature', 'ai_assistant')
          .eq('month', month)
          .maybeSingle();
      final planLimits = await client.rpc(AppRpc.getPlanLimits) as Map<String, dynamic>?;
      if (!mounted) return;
      final count = (usageRow?['count'] as int?) ?? 0;
      final limit = (planLimits?['ai_assistant_calls_month'] as int?) ?? 20;
      setState(() {
        _monthlyUsed = count;
        _monthlyLimit = limit;
        _limitReached = count >= limit;
        _limitChecking = false;
      });
    } catch (e) {
      ErrorLogger.warning(e, action: 'check_ai_limit');
      if (!mounted) return;
      setState(() => _limitChecking = false);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onMentionChanged);
    _ctrl.dispose();
    _focus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── @-mention helpers ──────────────────────────────────────────────────────

  void _onMentionChanged() {
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;
    if (cursor < 0) { _hideSuggestions(); return; }
    final before = text.substring(0, cursor.clamp(0, text.length));
    final atIdx = before.lastIndexOf('@');
    if (atIdx < 0) { _hideSuggestions(); return; }
    final word = before.substring(atIdx + 1);
    if (word.contains(' ')) { _hideSuggestions(); return; }
    _mentionStart = atIdx;
    _filterContacts(word.toLowerCase());
  }

  void _hideSuggestions() {
    if (_showSuggestions || _mentionStart != null) {
      setState(() {
        _showSuggestions = false;
        _mentionStart = null;
        _suggestions = [];
      });
    }
  }

  Future<void> _filterContacts(String query) async {
    final all = await ContactService.instance.getContacts();
    if (!mounted) return;
    setState(() {
      _suggestions = all
          .where((c) =>
              query.isEmpty ||
              c.name.toLowerCase().contains(query) ||
              c.phone.contains(query))
          .take(6)
          .toList();
      _showSuggestions = _suggestions.isNotEmpty;
    });
  }

  void _selectContact(ContactEntry contact) {
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset.clamp(0, text.length);
    final start = _mentionStart ?? 0;
    final before = text.substring(0, start);
    final after = cursor < text.length ? text.substring(cursor) : '';
    _ctrl.value = TextEditingValue(
      text: '$before@${contact.name} $after',
      selection: TextSelection.collapsed(
          offset: before.length + contact.name.length + 2),
    );
    setState(() {
      _showSuggestions = false;
      _mentionStart = null;
      _suggestions = [];
    });
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit(String q) async {
    final question = q.trim();
    if (question.isEmpty || _loading || _limitReached) return;

    // Local pre-flight guard: if we already know the count is at/over the limit
    // (e.g. another device used up the remaining calls since app open), block here
    // before wasting an AI request.
    if (!_limitChecking && _monthlyUsed >= _monthlyLimit) {
      setState(() => _limitReached = true);
      return;
    }
    _hideSuggestions();
    _focus.unfocus();
    HapticFeedback.lightImpact();

    setState(() {
      _loading = true;
      _response = null;
      _confirmingAction = false;
      _actionDone = false;
      _actionSuccessMsg = null;
    });
    _animCtrl.forward(from: 0);

    try {
      final intent = IntentClassifier.instance.classify(question);
      if (kDebugMode) debugPrint('[WAI] AI intent resolved, sources=${intent.dataSources}');
      final ctx = await ContextFetcher.instance.fetch(intent, _selectedWalletId);
      final contextBlock = ctx.toPromptBlock();
      if (kDebugMode) debugPrint('[WAI] context fetched');
      final familyMembers = ctx.family.isNotEmpty
          ? (ctx.family['members'] as String? ?? 'not specified')
          : 'not specified';
      final result = await AIParser.parseText(
        feature: 'dashboard',
        subFeature: 'ai_assistant',
        text: question,
        context: {
          'question': question,
          'household_context': contextBlock,
          'family_members': familyMembers,
        },
      );
      if (!mounted) return;

      // Increment usage only on a successful AI response
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null && result.success) {
        final allowed = await Supabase.instance.client.rpc(
          AppRpc.checkFeatureLimit,
          params: {'p_user_id': userId, 'p_feature': 'ai_assistant'},
        ) as bool? ?? true;
        if (mounted) {
          setState(() {
            _monthlyUsed = _monthlyUsed + 1;
            // Set limit when server says no OR when local count catches up to limit.
            // The second condition prevents 21/20 display: when the 20th call is
            // allowed by the server (count just hit 20), the next submit is still
            // blocked locally without needing a 21st AI request.
            if (!allowed || _monthlyUsed >= _monthlyLimit) _limitReached = true;
          });
        }
      }

      if (!mounted) return;
      final response = AssistantResponse.fromResult(result);
      setState(() {
        _response = response;
        _loading = false;
        // Auto-select wallet based on AI's scope hint (family/personal)
        if (response.action != null && widget.wallets.length > 1) {
          final scope = response.action!.data['scope'] as String?;
          if (scope == 'family') {
            final family = widget.wallets.where((w) => !w.isPersonal).firstOrNull;
            if (family != null) _selectedWalletId = family.id;
          } else {
            final personal = widget.wallets.where((w) => w.isPersonal).firstOrNull;
            if (personal != null) _selectedWalletId = personal.id;
          }
        }
      });
      _animCtrl.forward(from: 0);
    } catch (e, stack) {
      await ErrorLogger.log(e, stackTrace: stack, action: 'wai_ask');
      if (!mounted) return;
      setState(() {
        _response = const AssistantResponse(
          answer: 'Sorry, I couldn\'t fetch an answer right now. Please try again.',
        );
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    }
  }

  // ── Action confirm / execute ───────────────────────────────────────────────

  Future<void> _confirmAction() async {
    final action = _response?.action;
    if (action == null) return;

    setState(() => _confirmingAction = true);
    HapticFeedback.mediumImpact();

    try {
      final savedTx = await ActionExecutor.instance.execute(action, _selectedWalletId);
      if (!mounted) return;
      if (savedTx != null) widget.onTransactionSaved?.call(savedTx);
      setState(() {
        _confirmingAction = false;
        _actionDone = true;
        _actionSuccessMsg = '${action.icon} ${action.label} — done!';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _clear();
      });
    } catch (e, stack) {
      await ErrorLogger.log(e, stackTrace: stack, action: 'wai_action_execute');
      debugPrint('[WAI Action] execute failed: $e');
      if (!mounted) return;
      setState(() {
        _confirmingAction = false;
        _response = AssistantResponse(
          answer: 'Sorry, something went wrong saving that. Please try again.',
          action: action,
        );
      });
    }
  }

  void _clear() {
    _hideSuggestions();
    setState(() {
      _response = null;
      _confirmingAction = false;
      _actionDone = false;
      _actionSuccessMsg = null;
      _ctrl.clear();
    });
    _animCtrl.reverse();
  }

  // ── Mic / Speech ───────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    final available = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') _onSpeechDone();
      },
      onError: (e) {
        setState(() => _isListening = false);
      },
    );
    if (!available || !mounted) return;
    setState(() { _isListening = true; _ctrl.clear(); });
    await _speech.listen(
      localeId: 'en_IN',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
      onResult: (r) {
        setState(() => _ctrl.text = r.recognizedWords);
        if (r.finalResult) _onSpeechDone();
      },
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    _onSpeechDone();
  }

  void _onSpeechDone() {
    if (!mounted) return;
    setState(() => _isListening = false);
    final text = _ctrl.text.trim();
    if (text.isNotEmpty) _submit(text);
  }

  // ── Paste bank SMS ─────────────────────────────────────────────────────────

  Future<void> _pasteSms() async {
    final clip = await Clipboard.getData('text/plain');
    final text = clip?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Clipboard is empty — copy your bank SMS first.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    setState(() => _smsLoading = true);
    final parsed = await SMSParserService.parseSMSText(text);
    if (!mounted) return;
    setState(() => _smsLoading = false);
    if (parsed == null || !parsed.isTransaction) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not read a transaction from the clipboard text.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    await IntentConfirmSheet.show(
      context,
      intent:     parsed.toParsedIntent(),
      walletId:   _selectedWalletId,
      onSave:     (tx) => widget.onTransactionSaved?.call(tx),
      onOpenFlow: () {},
    );
  }

  // ── Import past transactions ───────────────────────────────────────────────

  void _openImport() {
    SmsHistoryImportScreen.show(context, walletId: _selectedWalletId);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1e1b4b), Color(0xFF312e81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFFA5B4FC), Color(0xFFE0E7FF)],
                  ).createShader(r),
                  child: const Text(
                    '✦ WAI Assistant',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFFA5B4FC)),
                    ),
                  )
                else if (!_limitChecking)
                  Text(
                    '$_monthlyUsed/$_monthlyLimit',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: _limitReached
                          ? Colors.redAccent.withAlpha(200)
                          : Colors.white.withAlpha(100),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Limit reached banner ────────────────────────────────────────
            if (_limitReached) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Text('🚫', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Monthly limit of $_monthlyLimit calls reached.\nUpgrade your plan to continue.',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withAlpha(200),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Input bar ────────────────────────────────────────────────────
            if (!_limitReached) Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _focus.hasFocus
                      ? const Color(0xFFA5B4FC).withAlpha(160)
                      : Colors.white.withAlpha(30),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      onSubmitted: _submit,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Ask or say "add milk to grocery"…',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          color: Colors.white.withAlpha(100),
                        ),
                      ),
                    ),
                  ),
                  // Mic button
                  GestureDetector(
                    onTap: _loading ? null : (_isListening ? _stopListening : _startListening),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6, right: 4),
                      child: Icon(
                        _isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                        size: 20,
                        color: _isListening
                            ? Colors.redAccent
                            : Colors.white.withAlpha(160),
                      ),
                    ),
                  ),
                  // Send button
                  GestureDetector(
                    onTap: () => _loading ? null : _submit(_ctrl.text),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── @-mention suggestions ────────────────────────────────────────
            if (_showSuggestions && _suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  itemBuilder: (_, i) {
                    final c = _suggestions[i];
                    return InkWell(
                      onTap: () => _selectContact(c),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 7),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.white.withAlpha(30),
                              child: Text(
                                c.name.isNotEmpty
                                    ? c.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFA5B4FC),
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      fontFamily: 'Nunito',
                                    ),
                                  ),
                                  if (c.phone.isNotEmpty)
                                    Text(
                                      c.phone,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white.withAlpha(140),
                                        fontFamily: 'Nunito',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // ── Quick question chips ──────────────────────────────────────────
            if (!_showSuggestions && _response == null && !_loading && !_limitReached) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 26,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickQuestions.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () {
                      _ctrl.text = _quickQuestions[i];
                      _submit(_quickQuestions[i]);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: Text(
                        _quickQuestions[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── Action chips (SMS & import) ────────────────────────────────
              Row(
                children: [
                  _ActionChip(
                    icon: Icons.content_paste_rounded,
                    label: _smsLoading ? 'Reading…' : 'Paste bank SMS',
                    onTap: _smsLoading ? null : _pasteSms,
                  ),
                  const SizedBox(width: 8),
                  _ActionChip(
                    icon: Icons.history_rounded,
                    label: 'Import transactions',
                    onTap: _openImport,
                  ),
                ],
              ),
            ],

            // ── Response ──────────────────────────────────────────────────────
            if (_response != null)
              FadeTransition(
                opacity: _fadeAnim,
                child: _response!.isAction
                    ? _ActionCard(
                        response: _response!,
                        confirming: _confirmingAction,
                        done: _actionDone,
                        successMsg: _actionSuccessMsg,
                        onConfirm: _confirmAction,
                        onCancel: _clear,
                        onClear: _clear,
                        wallets: widget.wallets,
                        selectedWalletId: _selectedWalletId,
                        onWalletSelected: (id) => setState(() => _selectedWalletId = id),
                      )
                    : _ResponseCard(
                        response: _response!,
                        onNavigate: widget.onNavigate,
                        onClear: _clear,
                        onFollowUp: (q) {
                          _ctrl.text = q;
                          _submit(q);
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionCard — confirmation UI for write actions
// ─────────────────────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final AssistantResponse response;
  final bool confirming;
  final bool done;
  final String? successMsg;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onClear;
  final List<WalletModel> wallets;
  final String selectedWalletId;
  final ValueChanged<String> onWalletSelected;

  const _ActionCard({
    required this.response,
    required this.confirming,
    required this.done,
    required this.successMsg,
    required this.onConfirm,
    required this.onCancel,
    required this.onClear,
    required this.wallets,
    required this.selectedWalletId,
    required this.onWalletSelected,
  });

  @override
  Widget build(BuildContext context) {
    final action = response.action!;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Close button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    size: 16, color: Colors.white.withAlpha(120)),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // AI's answer text
          Text(
            response.answer,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(230),
              height: 1.55,
            ),
          ),

          const SizedBox(height: 10),

          // Confirmation card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: done
                ? _SuccessContent(message: successMsg ?? 'Done!')
                : _ConfirmContent(
                    action: action,
                    confirming: confirming,
                    onConfirm: onConfirm,
                    onCancel: onCancel,
                    wallets: wallets,
                    selectedWalletId: selectedWalletId,
                    onWalletSelected: onWalletSelected,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmContent extends StatelessWidget {
  final ActionPayload action;
  final bool confirming;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final List<WalletModel> wallets;
  final String selectedWalletId;
  final ValueChanged<String> onWalletSelected;

  const _ConfirmContent({
    required this.action,
    required this.confirming,
    required this.onConfirm,
    required this.onCancel,
    required this.wallets,
    required this.selectedWalletId,
    required this.onWalletSelected,
  });

  @override
  Widget build(BuildContext context) {
    final fields = action.displayFields;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action label row
        Row(
          children: [
            Text(action.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              action.label,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                color: Color(0xFFA5B4FC),
              ),
            ),
          ],
        ),

        // Field chips
        if (fields.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: fields.map((f) => _FieldChip(label: f.$1, value: f.$2)).toList(),
          ),
        ],

        // Wallet picker — only shown when the user has more than one wallet
        if (wallets.length > 1) ...[
          const SizedBox(height: 10),
          Text(
            'Save to',
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              color: Colors.white.withAlpha(120),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: wallets.map((w) {
              final selected = w.id == selectedWalletId;
              return GestureDetector(
                onTap: () => onWalletSelected(w.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withAlpha(40)
                        : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF818CF8)
                          : Colors.white.withAlpha(30),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    '${w.emoji}  ${w.name}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : Colors.white.withAlpha(160),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 12),

        // Confirm / Cancel buttons
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: confirming ? null : onCancel,
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withAlpha(30)),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withAlpha(160),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: confirming ? null : onConfirm,
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: confirming
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Confirm',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SuccessContent extends StatelessWidget {
  final String message;
  const _SuccessContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_rounded,
            color: Color(0xFF4ADE80), size: 18),
        const SizedBox(width: 8),
        Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            color: Color(0xFF4ADE80),
          ),
        ),
      ],
    );
  }
}

class _FieldChip extends StatelessWidget {
  final String label;
  final String value;
  const _FieldChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: TextStyle(
                fontSize: 9,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: Colors.white.withAlpha(120),
                letterSpacing: 0.3,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ResponseCard — read-query answer display
// ─────────────────────────────────────────────────────────────────────────────

class _ResponseCard extends StatelessWidget {
  final AssistantResponse response;
  final void Function(int)? onNavigate;
  final VoidCallback onClear;
  final void Function(String) onFollowUp;

  const _ResponseCard({
    required this.response,
    required this.onNavigate,
    required this.onClear,
    required this.onFollowUp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Close button row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    size: 16, color: Colors.white.withAlpha(120)),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Answer text
          Text(
            response.answer,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(230),
              height: 1.55,
            ),
          ),

          // Highlight chips
          if (response.highlights.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: response.highlights
                  .map((h) => _HighlightChip(chip: h))
                  .toList(),
            ),
          ],

          // Deep-link buttons
          if (response.deepLinks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: response.deepLinks.map((link) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onNavigate?.call(link.tab);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.white.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(link.emoji,
                            style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text(
                          link.label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Follow-up suggestions
          if (response.suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'You might also ask:',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: Colors.white.withAlpha(120),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: response.suggestions.map((s) {
                return GestureDetector(
                  onTap: () => onFollowUp(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.white.withAlpha(30)),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withAlpha(180),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HighlightChip
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightChip extends StatelessWidget {
  final HighlightChip chip;
  const _HighlightChip({required this.chip});

  Color get _color => switch (chip.color) {
        'green' => const Color(0xFF4ADE80),
        'red'   => const Color(0xFFF87171),
        'amber' => const Color(0xFFFBBF24),
        _       => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withAlpha(28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chip.label,
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              color: _color.withAlpha(180),
              letterSpacing: 0.3,
            ),
          ),
          Text(
            chip.value,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionChip — tappable chip for paste SMS / import actions
// ─────────────────────────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(enabled ? 25 : 12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFA5B4FC).withAlpha(enabled ? 80 : 40),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: const Color(0xFFA5B4FC).withAlpha(enabled ? 200 : 120)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: Colors.white.withAlpha(enabled ? 190 : 110),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
