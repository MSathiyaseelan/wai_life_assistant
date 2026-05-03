import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/ai_parser.dart';
import 'package:wai_life_assistant/features/dashboard/ai_assistant/intent_classifier.dart';
import 'package:wai_life_assistant/features/dashboard/ai_assistant/context_fetcher.dart';
import 'package:wai_life_assistant/features/dashboard/ai_assistant/assistant_response.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AIAssistantWidget
// Dark gradient AI bar with intent classification, context fetching,
// structured response display (highlights, suggestions, deep-links).
// ─────────────────────────────────────────────────────────────────────────────

class AIAssistantWidget extends StatefulWidget {
  final String walletId;
  final void Function(int tabIndex)? onNavigate;

  const AIAssistantWidget({
    super.key,
    required this.walletId,
    this.onNavigate,
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

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  static const _quickQuestions = [
    'How much did I spend this month?',
    'What\'s on my grocery list?',
    'Any upcoming bills?',
    'Summarise my finances',
  ];


  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(String q) async {
    final question = q.trim();
    if (question.isEmpty || _loading) return;
    _focus.unfocus();
    HapticFeedback.lightImpact();

    setState(() {
      _loading = true;
      _response = null;
    });
    _animCtrl.forward(from: 0);

    try {
      final intent = IntentClassifier.instance.classify(question);
      debugPrint('[WAI] walletId=${widget.walletId} sources=${intent.dataSources}');
      final ctx = await ContextFetcher.instance.fetch(intent, widget.walletId);
      final contextBlock = ctx.toPromptBlock();
      debugPrint('[WAI] context block:\n$contextBlock');
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

      final response = AssistantResponse.fromResult(result);
      setState(() {
        _response = response;
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    } catch (e) {
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

  void _clear() {
    setState(() {
      _response = null;
      _ctrl.clear();
    });
    _animCtrl.reverse();
  }

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
            // ── Header ────────────────────────────────────────────────────
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
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Input bar ─────────────────────────────────────────────────
            Container(
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
                        hintText: 'Ask about spending, meals, tasks…',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          color: Colors.white.withAlpha(100),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _loading ? null : _submit(_ctrl.text),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
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

            // ── Quick question chips ───────────────────────────────────────
            if (_response == null && !_loading) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 26,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickQuestions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
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
                        border: Border.all(
                          color: Colors.white.withAlpha(40),
                        ),
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
            ],

            // ── Response ──────────────────────────────────────────────────
            if (_response != null)
              FadeTransition(
                opacity: _fadeAnim,
                child: _ResponseCard(
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
// _ResponseCard
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
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white.withAlpha(120),
                ),
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
              children: response.highlights.map((h) {
                return _HighlightChip(chip: h);
              }).toList(),
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
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withAlpha(50),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(link.emoji, style: const TextStyle(fontSize: 11)),
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
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withAlpha(30),
                      ),
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
        'red' => const Color(0xFFF87171),
        'amber' => const Color(0xFFFBBF24),
        _ => AppColors.primary,
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
