import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/gemini_service.dart';
import 'package:wai_life_assistant/features/dashboard/ai_context_builder.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashboardAiBar
// Full-width AI query bar + collapsible answer card shown on the Dashboard.
// ─────────────────────────────────────────────────────────────────────────────

class DashboardAiBar extends StatefulWidget {
  final String walletId;
  final bool isDark;

  /// Called when the AI answer includes a `GO:tab` deep-link tag.
  /// 0 = Dashboard, 1 = Wallet, 2 = Pantry, 3 = PlanIt
  final void Function(int tabIndex)? onNavigate;

  const DashboardAiBar({
    super.key,
    required this.walletId,
    required this.isDark,
    this.onNavigate,
  });

  @override
  State<DashboardAiBar> createState() => _DashboardAiBarState();
}

class _DashboardAiBarState extends State<DashboardAiBar>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  bool _loading = false;
  String? _answer;
  List<_DeepLink> _deepLinks = [];

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  // Suggested questions shown as chips
  static const _suggestions = [
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
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit(String q) async {
    final question = q.trim();
    if (question.isEmpty || _loading) return;
    _focus.unfocus();
    HapticFeedback.lightImpact();

    setState(() {
      _loading = true;
      _answer = null;
      _deepLinks = [];
    });
    _animCtrl.forward(from: 0);

    try {
      final context = await AiContextBuilder.instance.build(
        question,
        widget.walletId,
      );
      final raw = await GeminiService.instance.ask(context, question);
      if (!mounted) return;

      final parsed = _parseAnswer(raw);
      setState(() {
        _answer = parsed.text;
        _deepLinks = parsed.links;
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _answer = 'Sorry, I couldn\'t fetch an answer right now. Try again.';
        _deepLinks = [];
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    }
  }

  // ── Parse Gemini response for [GO:tab] tags ───────────────────────────────

  _ParsedAnswer _parseAnswer(String raw) {
    final links = <_DeepLink>[];
    final tagPattern = RegExp(r'\[GO:(wallet|pantry|planit)\]', caseSensitive: false);

    for (final m in tagPattern.allMatches(raw)) {
      final tag = m.group(1)!.toLowerCase();
      links.add(_DeepLink(
        label: _tabLabel(tag),
        tabIndex: _tabIndex(tag),
        emoji: _tabEmoji(tag),
      ));
    }

    final cleanText = raw.replaceAll(tagPattern, '').trim();
    return _ParsedAnswer(text: cleanText, links: links);
  }

  String _tabLabel(String tag) => switch (tag) {
        'wallet' => 'Open Wallet',
        'pantry' => 'Open Pantry',
        'planit' => 'Open PlanIt',
        _ => 'Go',
      };

  int _tabIndex(String tag) => switch (tag) {
        'wallet' => 1,
        'pantry' => 2,
        'planit' => 3,
        _ => 0,
      };

  String _tabEmoji(String tag) => switch (tag) {
        'wallet' => '₹',
        'pantry' => '🥗',
        'planit' => '📅',
        _ => '→',
      };

  void _clear() {
    setState(() {
      _answer = null;
      _deepLinks = [];
      _ctrl.clear();
    });
    _animCtrl.reverse();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg   = isDark ? AppColors.surfDark  : const Color(0xFFEDEEF5);
    final card = isDark ? AppColors.cardDark  : Colors.white;
    final tc   = isDark ? AppColors.textDark  : AppColors.textLight;
    final sub  = isDark ? AppColors.subDark   : AppColors.subLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Input bar ───────────────────────────────────────────────────────
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focus.hasFocus
                  ? AppColors.primary.withAlpha(120)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              // Spark icon
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ).createShader(r),
                child: const Text('✦', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  onSubmitted: _submit,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                    color: tc,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Ask anything — spend, meals, tasks…',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Nunito',
                      color: sub.withAlpha(180),
                    ),
                  ),
                ),
              ),
              // Send button
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _submit(_ctrl.text),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Suggestion chips (only when no answer yet) ──────────────────────
        if (_answer == null && !_loading) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () {
                  _ctrl.text = _suggestions[i];
                  _submit(_suggestions[i]);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withAlpha(40)),
                  ),
                  child: Text(
                    _suggestions[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary.withAlpha(200),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],

        // ── Answer card ─────────────────────────────────────────────────────
        if (_answer != null)
          FadeTransition(
            opacity: _fadeAnim,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withAlpha(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(isDark ? 20 : 12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
                      child: Row(
                        children: [
                          ShaderMask(
                            shaderCallback: (r) => const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            ).createShader(r),
                            child: const Text(
                              '✦ WAI',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _clear,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.close_rounded, size: 16, color: sub),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Answer text
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                      child: Text(
                        _answer!,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                          color: tc,
                          height: 1.5,
                        ),
                      ),
                    ),

                    // Deep-link action chips
                    if (_deepLinks.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Wrap(
                          spacing: 8,
                          children: _deepLinks.map((link) {
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onNavigate?.call(link.tabIndex);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4F46E5),
                                      Color(0xFF7C3AED)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      link.emoji,
                                      style: const TextStyle(fontSize: 12),
                                    ),
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
                      )
                    else
                      const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal models
// ─────────────────────────────────────────────────────────────────────────────

class _DeepLink {
  final String label;
  final int tabIndex;
  final String emoji;
  const _DeepLink({required this.label, required this.tabIndex, required this.emoji});
}

class _ParsedAnswer {
  final String text;
  final List<_DeepLink> links;
  const _ParsedAnswer({required this.text, required this.links});
}
