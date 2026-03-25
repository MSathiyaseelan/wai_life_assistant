import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';

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

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() => _hasText = _ctrl.text.isNotEmpty));
    _focus.addListener(() => setState(() {}));
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseScale = Tween(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _pulseCtrl.dispose();
    super.dispose();
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

    return Container(
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
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
                          ? AppColors.expense.withOpacity(0.12)
                          : AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: listening
                            ? AppColors.expense.withOpacity(0.5)
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
                        ? AppColors.expense.withOpacity(0.35)
                        : _focus.hasFocus
                        ? AppColors.primary.withOpacity(0.45)
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
                                ? AppColors.expense.withOpacity(0.55)
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

// class ChatInputBar extends StatefulWidget {
//   final void Function(String text) onSubmit;
//   final VoidCallback onMicTap;
//   final VoidCallback onAddTap;
//   final bool isListening;

//   const ChatInputBar({
//     super.key,
//     required this.onSubmit,
//     required this.onMicTap,
//     required this.onAddTap,
//     this.isListening = false,
//   });

//   @override
//   State<ChatInputBar> createState() => _ChatInputBarState();
// }

// class _ChatInputBarState extends State<ChatInputBar>
//     with SingleTickerProviderStateMixin {
//   final _ctrl = TextEditingController();
//   final _focus = FocusNode();
//   bool _hasText = false;
//   late AnimationController _micAnim;
//   late Animation<double> _micScale;

//   @override
//   void initState() {
//     super.initState();
//     _ctrl.addListener(() => setState(() => _hasText = _ctrl.text.isNotEmpty));
//     _micAnim = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     )..repeat(reverse: true);
//     _micScale = Tween(
//       begin: 1.0,
//       end: 1.2,
//     ).animate(CurvedAnimation(parent: _micAnim, curve: Curves.easeInOut));
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     _focus.dispose();
//     _micAnim.dispose();
//     super.dispose();
//   }

//   void _submit() {
//     final text = _ctrl.text.trim();
//     if (text.isEmpty) return;
//     widget.onSubmit(text);
//     _ctrl.clear();
//     _focus.unfocus();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
//     final inputBg = isDark ? const Color(0xFF16213E) : const Color(0xFFF5F6FA);
//     final hintColor = isDark
//         ? const Color(0xFF6E6E90)
//         : const Color(0xFF8E8EA0);
//     final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

//     return Container(
//       padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
//       decoration: BoxDecoration(
//         color: bg,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
//             blurRadius: 20,
//             offset: const Offset(0, -4),
//           ),
//         ],
//       ),
//       child: SafeArea(
//         top: false,
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             // ── Mic button ────────────────────────────────────────────────
//             GestureDetector(
//               onTap: widget.onMicTap,
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 200),
//                 width: 46,
//                 height: 46,
//                 decoration: BoxDecoration(
//                   color: widget.isListening
//                       ? AppColors.expense.withOpacity(0.15)
//                       : AppColors.primary.withOpacity(0.1),
//                   shape: BoxShape.circle,
//                 ),
//                 alignment: Alignment.center,
//                 child: widget.isListening
//                     ? ScaleTransition(
//                         scale: _micScale,
//                         child: const Icon(
//                           Icons.mic_rounded,
//                           color: AppColors.expense,
//                           size: 22,
//                         ),
//                       )
//                     : const Icon(
//                         Icons.mic_none_rounded,
//                         color: AppColors.primary,
//                         size: 22,
//                       ),
//               ),
//             ),
//             const SizedBox(width: 10),

//             // ── Text field ────────────────────────────────────────────────
//             Expanded(
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 200),
//                 decoration: BoxDecoration(
//                   color: inputBg,
//                   borderRadius: BorderRadius.circular(24),
//                   border: Border.all(
//                     color: _focus.hasFocus
//                         ? AppColors.primary.withOpacity(0.4)
//                         : Colors.transparent,
//                     width: 1.5,
//                   ),
//                 ),
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 10,
//                 ),
//                 child: TextField(
//                   controller: _ctrl,
//                   focusNode: _focus,
//                   maxLines: null, // expands line by line
//                   minLines: 1,
//                   keyboardType: TextInputType.multiline,
//                   textCapitalization: TextCapitalization.sentences,
//                   style: TextStyle(
//                     fontSize: 14,
//                     color: textColor,
//                     fontFamily: 'Nunito',
//                   ),
//                   decoration: InputDecoration.collapsed(
//                     hintText:
//                         'Tell me what happened... (e.g. "spent 500 on food")',
//                     hintStyle: TextStyle(
//                       fontSize: 13,
//                       color: hintColor,
//                       fontFamily: 'Nunito',
//                     ),
//                   ),
//                   onSubmitted: (_) => _submit(),
//                 ),
//               ),
//             ),
//             const SizedBox(width: 10),

//             // ── Send button ───────────────────────────────────────────────
//             AnimatedSwitcher(
//               duration: const Duration(milliseconds: 200),
//               transitionBuilder: (child, anim) =>
//                   ScaleTransition(scale: anim, child: child),
//               child: _hasText
//                   ? GestureDetector(
//                       key: const ValueKey('send'),
//                       onTap: _submit,
//                       child: Container(
//                         width: 46,
//                         height: 46,
//                         decoration: const BoxDecoration(
//                           color: AppColors.primary,
//                           shape: BoxShape.circle,
//                         ),
//                         alignment: Alignment.center,
//                         child: const Icon(
//                           Icons.arrow_upward_rounded,
//                           color: Colors.white,
//                           size: 22,
//                         ),
//                       ),
//                     )
//                   : Container(
//                       key: const ValueKey('add'),
//                       width: 46,
//                       height: 46,
//                       decoration: BoxDecoration(
//                         color: AppColors.primary,
//                         shape: BoxShape.circle,
//                       ),
//                       alignment: Alignment.center,
//                       child: const Icon(
//                         Icons.add_rounded,
//                         color: Colors.white,
//                         size: 22,
//                       ),
//                     ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
