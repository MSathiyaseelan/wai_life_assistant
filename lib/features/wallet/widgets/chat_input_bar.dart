import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ChatInputBar extends StatefulWidget {
  final void Function(String text) onSubmit;
  final VoidCallback onMicTap;
  final VoidCallback onAddTap;
  final bool isListening;

  const ChatInputBar({
    super.key,
    required this.onSubmit,
    required this.onMicTap,
    required this.onAddTap,
    this.isListening = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;
  late AnimationController _micAnim;
  late Animation<double> _micScale;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() => _hasText = _ctrl.text.isNotEmpty));
    _micAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _micScale = Tween(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _micAnim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _micAnim.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _ctrl.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final inputBg = isDark ? const Color(0xFF16213E) : const Color(0xFFF5F6FA);
    final hintColor = isDark
        ? const Color(0xFF6E6E90)
        : const Color(0xFF8E8EA0);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Mic button ────────────────────────────────────────────────
            GestureDetector(
              onTap: widget.onMicTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: widget.isListening
                      ? AppColors.expense.withOpacity(0.15)
                      : AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: widget.isListening
                    ? ScaleTransition(
                        scale: _micScale,
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
            ),
            const SizedBox(width: 10),

            // ── Text field ────────────────────────────────────────────────
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _focus.hasFocus
                        ? AppColors.primary.withOpacity(0.4)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  maxLines: null, // expands line by line
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    fontFamily: 'Nunito',
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText:
                        'Tell me what happened... (e.g. "spent 500 on food")',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: hintColor,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ── Send button ───────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: _hasText
                  ? GestureDetector(
                      key: const ValueKey('send'),
                      onTap: _submit,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    )
                  : Container(
                      key: const ValueKey('add'),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
