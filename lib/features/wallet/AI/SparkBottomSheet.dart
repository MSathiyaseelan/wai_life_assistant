import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/services/sms_parser_service.dart';
import 'package:wai_life_assistant/services/ai_parser.dart';
import 'package:wai_life_assistant/features/wallet/ai/IntentConfirmSheet.dart';
import 'package:wai_life_assistant/features/wallet/ai/nlp_parser.dart';

class SparkBottomSheet extends StatefulWidget {
  final String walletId;
  final void Function(TxModel tx) onSave;
  final VoidCallback onOpenFlow;

  /// When true, strips the outer Container decoration, drag handle and header
  /// so the content can be embedded inside another sheet (e.g. a tab).
  final bool embedded;

  const SparkBottomSheet({
    super.key,
    required this.walletId,
    required this.onSave,
    required this.onOpenFlow,
    this.embedded = false,
  });

  @override
  State<SparkBottomSheet> createState() => _SparkBottomSheetState();
}

class _SparkBottomSheetState extends State<SparkBottomSheet> {
  final _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();

  bool _isListening  = false;
  bool _isLoading    = false;
  bool _isSmsLoading = false;
  String _spokenText = '';
  String? _errorMsg;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Speech ──────────────────────────────────────────────────────────────────

  Future<void> _onTapToSpeak() async {
    final available = await _speech.initialize(
      onStatus: (s) => debugPrint('🎧 $s'),
      onError: (e) => debugPrint('❌ ${e.errorMsg}'),
    );
    if (!available) return;

    setState(() {
      _isListening = true;
      _spokenText = '';
      _errorMsg = null;
    });

    await _speech.listen(
      localeId: 'en_IN',
      listenMode: ListenMode.dictation,
      partialResults: true,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
      onResult: (result) {
        setState(() => _spokenText = result.recognizedWords);
        if (result.finalResult) _onSpeechComplete();
      },
    );
  }

  Future<void> _onSpeechComplete() async {
    await _speech.stop();
    setState(() => _isListening = false);
    if (_spokenText.trim().isNotEmpty) {
      _controller.text = _spokenText;
      await _parseInput();
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    if (_spokenText.trim().isNotEmpty) {
      _controller.text = _spokenText;
      await _parseInput();
    }
  }

  // ── Paste bank SMS (Approach 2) ──────────────────────────────────────────────

  Future<void> _pasteSms() async {
    final clip = await Clipboard.getData('text/plain');
    final text = clip?.text?.trim() ?? '';
    if (text.isEmpty) {
      setState(() => _errorMsg = 'Clipboard is empty. Copy your bank SMS first.');
      return;
    }

    setState(() {
      _isSmsLoading = true;
      _errorMsg = null;
    });

    final parsed = await SMSParserService.parseSMSText(text);

    if (!mounted) return;
    setState(() => _isSmsLoading = false);

    if (parsed == null || !parsed.isTransaction) {
      setState(() => _errorMsg = 'Could not read a transaction from the clipboard text.');
      return;
    }

    final intent = parsed.toParsedIntent();
    if (!mounted) return;
    Navigator.pop(context);
    await IntentConfirmSheet.show(
      context,
      intent:      intent,
      walletId:    widget.walletId,
      onSave:      widget.onSave,
      onOpenFlow:  widget.onOpenFlow,
    );
  }

  // ── AI Parse ─────────────────────────────────────────────────────────────────

  Future<void> _parseInput() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final result = await AIParser.parseText(
      feature: 'wallet',
      subFeature: 'expense',
      text: text,
    );

    if (!mounted) return;

    if (!result.success || result.data == null) {
      setState(() {
        _isLoading = false;
        _errorMsg = result.error ?? 'Could not understand. Try rephrasing.';
      });
      return;
    }

    final intent = _mapToIntent(result.data!);

    // Pop Spark sheet then show confirm sheet
    if (!mounted) return;
    Navigator.pop(context);
    await IntentConfirmSheet.show(
      context,
      intent: intent,
      walletId: widget.walletId,
      onSave: widget.onSave,
      onOpenFlow: widget.onOpenFlow,
    );
  }

  ParsedIntent _mapToIntent(Map<String, dynamic> data) {
    // flow type
    FlowType flowType;
    switch ((data['type'] as String? ?? '').toLowerCase()) {
      case 'income':
        flowType = FlowType.income;
      case 'lend':
        flowType = FlowType.lend;
      case 'borrow':
        flowType = FlowType.borrow;
      default:
        flowType = FlowType.expense;
    }

    // pay mode
    PayMode? payMode;
    final pm = (data['payment_mode'] as String? ?? '').toLowerCase();
    if (pm == 'cash') {
      payMode = PayMode.cash;
    } else if (pm.isNotEmpty && pm != 'null') {
      payMode = PayMode.online;
    }

    return ParsedIntent(
      flowType: flowType,
      amount: (data['amount'] as num?)?.toDouble(),
      category: data['category'] as String?,
      person: data['person'] as String?,
      payMode: payMode,
      title: data['title'] as String?,
      note: data['note'] as String?,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.8,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : Colors.white;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) ...[
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Header
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spark Assistant',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  Text(
                    'Tell me what happened',
                    style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ] else ...[
          Text(
            'Tell me what happened',
            style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
          ),
          const SizedBox(height: 12),
        ],

        // Input row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_isLoading,
                onSubmitted: (_) => _parseInput(),
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Nunito',
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                ),
                decoration: InputDecoration(
                  hintText: _isListening ? _spokenText : 'e.g. coffee 120 by UPI',
                  hintStyle: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: _isListening
                        ? AppColors.primary.withValues(alpha: 0.7)
                        : sub,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.surfDark : const Color(0xFFEDEEF5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _isLoading
                ? const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                : FilledButton(
                    onPressed: _parseInput,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
          ],
        ),
        const SizedBox(height: 10),

        // Mic button
        TextButton.icon(
          onPressed: _isLoading ? null : (_isListening ? _stopListening : _onTapToSpeak),
          icon: Icon(
            _isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
            color: _isListening ? Colors.redAccent : AppColors.primary,
            size: 20,
          ),
          label: Text(
            _isListening ? 'Listening… tap to stop' : 'Tap to speak',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              color: _isListening ? Colors.redAccent : AppColors.primary,
            ),
          ),
        ),

        // Paste bank SMS button (Approach 2)
        _isSmsLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reading SMS…',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Nunito',
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            : TextButton.icon(
                onPressed: (_isLoading || _isListening) ? null : _pasteSms,
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text(
                  'Paste bank SMS',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                ),
              ),

        // Error message
        if (_errorMsg != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 4),
      ],
    );

    if (widget.embedded) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: content,
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: content,
    );
  }
}
