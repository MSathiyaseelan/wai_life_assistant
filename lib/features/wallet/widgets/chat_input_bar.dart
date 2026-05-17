import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/contact_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHAT INPUT BAR  — three modes in one bar
//
//  🎤  MIC   tap → pulsing red   → tap again → speech drops into textbox
//  ⌨️  TYPE  user types → ↑ send → NLP parse → confirm sheet
//  ➕  ADD   field empty → + button → opens flow selector sheet
// ─────────────────────────────────────────────────────────────────────────────

class ChatInputBar extends StatefulWidget {
  final void Function(String text) onSubmit; // NLP parse this text
  final VoidCallback onMicTap; // wallet_screen drives mic state
  final VoidCallback? onMicLongPress; // long-press → language picker
  final VoidCallback onAddTap; // opens flow selector
  final bool isListening;
  final String? hintText; // optional override for the placeholder text
  final String speechLocale; // e.g. 'en-IN', 'hi-IN', 'ta-IN'

  const ChatInputBar({
    super.key,
    required this.onSubmit,
    required this.onMicTap,
    required this.onAddTap,
    this.onMicLongPress,
    this.isListening = false,
    this.hintText,
    this.speechLocale = 'en-IN',
  });

  @override
  State<ChatInputBar> createState() => ChatInputBarState();
}

// Public so wallet_screen can call setTextFromSpeech() via GlobalKey
class ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  // ── Contact mention (@) ───────────────────────────────────────────────────
  List<ContactEntry> _suggestions = [];
  bool _showSuggestions = false;
  int? _mentionStart;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    _focus.addListener(() => setState(() {}));
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseScale = Tween(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    ContactService.instance.preload();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _focus.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;
    setState(() => _hasText = text.isNotEmpty);

    // Find the most recent '@' before the cursor that starts a word
    if (cursor < 0) {
      _hideSuggestions();
      return;
    }
    final beforeCursor = text.substring(0, cursor.clamp(0, text.length));
    final atIdx = beforeCursor.lastIndexOf('@');
    if (atIdx < 0) {
      _hideSuggestions();
      return;
    }
    // Make sure there's no space between '@' and cursor (single @-word)
    final word = beforeCursor.substring(atIdx + 1);
    if (word.contains(' ')) {
      _hideSuggestions();
      return;
    }
    _mentionStart = atIdx;
    _filterContacts(word.toLowerCase()); // async, fire-and-forget
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
    final newText = '$before@${contact.name} $after';
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: before.length + contact.name.length + 2),
    );
    setState(() {
      _showSuggestions = false;
      _mentionStart = null;
      _suggestions = [];
      _hasText = true;
    });
  }

  /// Called by wallet_screen when STT finishes — drops text into field
  void setTextFromSpeech(String text) {
    _ctrl.text = text;
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    setState(() => _hasText = text.isNotEmpty);
    // Brief delay so the UI shows the text before focus steals keyboard
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focus.requestFocus();
    });
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    widget.onSubmit(text);
    _ctrl.clear();
    _hideSuggestions();
    _focus.unfocus();
  }

  /// Returns 2-letter display code from a locale id like 'ta-IN' → 'TA'
  String _localeCode(String localeId) {
    final lang = localeId.split(RegExp(r'[-_]')).first.toUpperCase();
    return lang.length > 2 ? lang.substring(0, 2) : lang;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final inputBg = isDark ? AppColors.surfDark : AppColors.bgLight;
    final hint = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final listening = widget.isListening;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── @-mention contact suggestions ─────────────────────────────────
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            color: bg,
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              reverse: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (_, i) {
                final c = _suggestions[i];
                return InkWell(
                  onTap: () => _selectContact(c),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary.withValues(alpha:0.15),
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
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
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: tc,
                                ),
                              ),
                              if (c.phone.isNotEmpty)
                                Text(
                                  c.phone,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hint,
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
        Container(
          decoration: BoxDecoration(
            color: bg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── 🎤 Mic button ─────────────────────────────────────────────────
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onMicTap();
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                widget.onMicLongPress?.call();
              },
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: listening
                          ? AppColors.expense.withValues(alpha:0.12)
                          : AppColors.primary.withValues(alpha:0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: listening
                            ? AppColors.expense.withValues(alpha:0.5)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: listening
                        ? ScaleTransition(
                            scale: _pulseScale,
                            child: const Icon(
                              Icons.mic_rounded,
                              color: AppColors.expense,
                              size: 22,
                            ),
                          )
                        : const Icon(
                            Icons.mic_none_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                  ),
                  // Language badge (bottom-right corner)
                  if (!listening)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _localeCode(widget.speechLocale),
                          style: const TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // ── ⌨️ Text field ─────────────────────────────────────────────────
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: listening
                        ? AppColors.expense.withValues(alpha:0.35)
                        : _focus.hasFocus
                        ? AppColors.primary.withValues(alpha:0.45)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (listening) ...[_PulsingDot(), const SizedBox(width: 8)],
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        maxLines: null,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 14,
                          color: tc,
                          fontFamily: 'Nunito',
                        ),
                        decoration: InputDecoration.collapsed(
                          hintText: listening
                              ? 'Listening…'
                              : (widget.hintText ?? 'e.g. "paid ₹500 for lunch"'),
                          hintStyle: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Nunito',
                            color: listening
                                ? AppColors.expense.withValues(alpha:0.55)
                                : hint,
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ── ➕ / ↑ right button ────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: _hasText
                  ? _RoundBtn(
                      key: const ValueKey('send'),
                      icon: Icons.arrow_upward_rounded,
                      color: AppColors.primary,
                      onTap: _submit,
                    )
                  : _RoundBtn(
                      key: const ValueKey('add'),
                      icon: Icons.add_rounded,
                      color: AppColors.primary,
                      onTap: widget.onAddTap,
                    ),
            ),
          ],
        ),
      ),
      ),  // Container (input bar)
      ],  // Column
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _RoundBtn({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..repeat(reverse: true);
    _a = Tween(begin: 0.3, end: 1.0).animate(_c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: AppColors.expense,
        shape: BoxShape.circle,
      ),
    ),
  );
}

