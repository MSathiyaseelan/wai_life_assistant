import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'package:wai_life_assistant/features/wallet/chat_bubble.dart';

// ── Steps ─────────────────────────────────────────────────────────────────────

enum _MealStep { mealTime, mealName, emoji, confirm }

extension _MealStepQ on _MealStep {
  String get botQuestion {
    switch (this) {
      case _MealStep.mealTime:
        return 'Which meal is this? 🍽️';
      case _MealStep.mealName:
        return 'What did you have? 😋 Tell me the dish name.';
      case _MealStep.emoji:
        return 'Pick an emoji that best represents it 🎨';
      case _MealStep.confirm:
        return 'Here\'s your meal summary — looks good? ✅';
    }
  }
}

// ── Local data model ──────────────────────────────────────────────────────────

class _MealFlowData {
  MealTime mealTime = MealTime.lunch;
  String mealName = '';
  String emoji = '🍛';
  List<String> recipeIds = [];
}

// ── Message model ─────────────────────────────────────────────────────────────

class _Msg {
  final bool isBot;
  final String text;
  final _MealStep? step;
  final bool animate;
  final bool done;

  const _Msg({
    required this.isBot,
    required this.text,
    this.step,
    this.animate = false,
    this.done = false,
  });

  _Msg markDone() =>
      _Msg(isBot: isBot, text: text, step: step, animate: animate, done: true);
}

// ── MealConversationFlow ──────────────────────────────────────────────────────

class MealConversationFlow extends StatefulWidget {
  final DateTime date;
  final String walletId;
  final List<RecipeModel> recipes;
  final List<MealEntry> dayMeals;
  final void Function(MealEntry) onSave;
  final void Function(MealEntry)? onUpdate;
  final VoidCallback onClose;

  const MealConversationFlow({
    super.key,
    required this.date,
    required this.walletId,
    required this.recipes,
    required this.dayMeals,
    required this.onSave,
    this.onUpdate,
    required this.onClose,
  });

  @override
  State<MealConversationFlow> createState() => _MealConversationFlowState();
}

class _MealConversationFlowState extends State<MealConversationFlow> {
  final _scrollCtrl = ScrollController();
  final List<_Msg> _messages = [];
  bool _showTyping = false;
  bool _saved = false;

  final _data = _MealFlowData();
  static const _steps = _MealStep.values;
  int _stepIdx = 0;

  @override
  void initState() {
    super.initState();
    _resetData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushBotQuestion(0));
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _resetData() {
    final occupied = widget.dayMeals.map((m) => m.mealTime).toSet();
    final firstEmpty =
        MealTime.values.where((mt) => !occupied.contains(mt)).firstOrNull;
    _data.mealTime = firstEmpty ?? MealTime.lunch;
    _data.mealName = '';
    _data.emoji = '🍛';
    _data.recipeIds = [];
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _pushBotQuestion(int idx) {
    if (idx >= _steps.length) return;
    setState(() => _showTyping = true);
    _scrollToBottom();
    Future.delayed(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      setState(() {
        _showTyping = false;
        _messages.add(_Msg(
          isBot: true,
          text: _steps[idx].botQuestion,
          step: _steps[idx],
          animate: true,
        ));
      });
      _scrollToBottom();
    });
  }

  void _answer(_MealStep step, String display, VoidCallback applyData) {
    applyData();
    setState(() {
      if (_messages.isNotEmpty) {
        _messages[_messages.length - 1] = _messages.last.markDone();
      }
      _messages.add(_Msg(isBot: false, text: display, animate: true));
    });
    _scrollToBottom();
    _stepIdx++;
    // Skip emoji step when a recipe is selected — it already provides an emoji
    if (_stepIdx < _steps.length &&
        _steps[_stepIdx] == _MealStep.emoji &&
        _data.recipeIds.isNotEmpty) {
      _stepIdx++;
    }
    if (_stepIdx < _steps.length) _pushBotQuestion(_stepIdx);
  }

  void _save() {
    // If the chosen slot already has a meal, update it instead of adding.
    final existing = widget.dayMeals
        .where((m) => m.mealTime == _data.mealTime)
        .firstOrNull;

    if (existing != null && widget.onUpdate != null) {
      widget.onUpdate!(existing.copyWith(
        name: _data.mealName,
        emoji: _data.emoji,
        recipeIds: _data.recipeIds,
        ingredients: [],
      ));
    } else {
      final entry = MealEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _data.mealName,
        mealTime: _data.mealTime,
        date: widget.date,
        walletId: widget.walletId,
        emoji: _data.emoji,
        recipeIds: _data.recipeIds,
        ingredients: [],
      );
      widget.onSave(entry);
    }
    setState(() {
      if (_messages.isNotEmpty) {
        _messages[_messages.length - 1] = _messages.last.markDone();
      }
      _messages.add(const _Msg(
        isBot: true,
        text: '🎉 Meal logged! Great job tracking your food.',
        animate: true,
      ));
      _saved = true;
    });
    _scrollToBottom();
  }

  void _restart() {
    setState(() {
      _messages.clear();
      _stepIdx = 0;
      _saved = false;
      _showTyping = false;
    });
    _resetData();
    _pushBotQuestion(0);
  }

  Widget _buildInput(_MealStep step) {
    switch (step) {
      case _MealStep.mealTime:
        return _MealTimeStep(
          initialSelected: _data.mealTime,
          onSelect: (mt) => _answer(
            step,
            '${mt.emoji} ${mt.label}',
            () => _data.mealTime = mt,
          ),
        );
      case _MealStep.mealName:
        return _NameStep(
          color: _data.mealTime.color,
          mealTime: _data.mealTime,
          recipes: widget.recipes,
          onConfirm: (name, emoji, recipeIds) {
            final display = recipeIds.isNotEmpty
                ? '📖 ${widget.recipes.where((r) => recipeIds.contains(r.id)).map((r) => r.name).join(' + ')}'
                : '🍴 $name';
            _answer(
              step,
              display,
              () {
                _data.mealName = name;
                _data.emoji = emoji;
                _data.recipeIds = recipeIds;
              },
            );
          },
        );
      case _MealStep.emoji:
        return _EmojiStep(
          color: _data.mealTime.color,
          onSelect: (e) => _answer(
            step,
            e,
            () => _data.emoji = e,
          ),
        );
      case _MealStep.confirm:
        return _ConfirmStep(
          data: _data,
          date: widget.date,
          color: _data.mealTime.color,
          recipes: widget.recipes,
          onSave: _save,
          onRestart: _restart,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _data.mealTime.color;

    return Column(
      children: [
        // Progress bar
        _ProgressBar(
          current: _stepIdx,
          total: _steps.length,
          color: color,
        ),
        // Chat list
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount:
                _messages.length + (_showTyping ? 1 : 0) + (_saved ? 1 : 0),
            itemBuilder: (ctx, i) {
              // Typing indicator
              if (_showTyping && i == _messages.length) {
                return const TypingIndicator();
              }
              // Done card
              if (_saved &&
                  i == _messages.length + (_showTyping ? 1 : 0)) {
                return _DoneCard(
                  onLogAnother: _restart,
                  onClose: widget.onClose,
                );
              }

              final msg = _messages[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ChatBubble(
                    isBot: msg.isBot,
                    text: msg.text,
                    accentColor: color,
                    animate: msg.animate,
                  ),
                  // Input widget — only on latest unanswered bot msg
                  if (msg.isBot &&
                      msg.step != null &&
                      !msg.done &&
                      i == _messages.length - 1 &&
                      !_showTyping)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, bottom: 6),
                      child: _buildInput(msg.step!),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int current, total;
  final Color color;

  const _ProgressBar({
    required this.current,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);

    return Container(
      height: 3,
      color: isDark ? AppColors.surfDark : AppColors.bgLight,
      alignment: Alignment.centerLeft,
      child: AnimatedFractionallySizedBox(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, AppColors.primaryDark]),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(2),
              bottomRight: Radius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP: MEAL TIME — 2×2 grid of meal time cards
// ═══════════════════════════════════════════════════════════════════════════════

class _MealTimeStep extends StatefulWidget {
  final MealTime initialSelected;
  final void Function(MealTime) onSelect;

  const _MealTimeStep({
    required this.initialSelected,
    required this.onSelect,
  });

  @override
  State<_MealTimeStep> createState() => _MealTimeStepState();
}

class _MealTimeStepState extends State<_MealTimeStep> {
  late MealTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: MealTime.values.map((mt) {
          final sel = mt == _selected;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selected = mt);
                HapticFeedback.lightImpact();
                widget.onSelect(mt);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? mt.color
                      : mt.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(mt.emoji,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 3),
                    Text(
                      mt.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: sel ? Colors.white : mt.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP: NAME — recipe picker + text field
// ═══════════════════════════════════════════════════════════════════════════════

class _NameStep extends StatefulWidget {
  final Color color;
  final MealTime mealTime;
  final List<RecipeModel> recipes;
  /// Called with (name, emoji, recipeIds). recipeIds is empty when typed manually.
  final void Function(String name, String emoji, List<String> recipeIds) onConfirm;

  const _NameStep({
    required this.color,
    required this.mealTime,
    required this.recipes,
    required this.onConfirm,
  });

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  final _ctrl = TextEditingController();
  final List<RecipeModel> _selected = [];

  List<RecipeModel> get _sorted {
    final matched = widget.recipes
        .where((r) => r.suitableFor.contains(widget.mealTime))
        .toList();
    final rest = widget.recipes
        .where((r) => !r.suitableFor.contains(widget.mealTime))
        .toList();
    return [...matched, ...rest];
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _pickRecipe(RecipeModel r) {
    setState(() {
      final idx = _selected.indexWhere((s) => s.id == r.id);
      if (idx >= 0) {
        // ── Deselect: remove this recipe's name from the field (best-effort) ──
        _selected.removeAt(idx);
        var text = _ctrl.text;
        if (text.contains(' + ${r.name}')) {
          text = text.replaceFirst(' + ${r.name}', '');
        } else if (text.startsWith('${r.name} + ')) {
          text = text.replaceFirst('${r.name} + ', '');
        } else if (text == r.name) {
          text = '';
        }
        _ctrl.text = text.trim();
      } else {
        // ── Select: append this recipe's name to whatever is in the field ──
        _selected.add(r);
        final current = _ctrl.text.trim();
        _ctrl.text = current.isEmpty ? r.name : '$current + ${r.name}';
      }
    });
  }

  void _clearRecipe() {
    setState(() {
      _selected.clear();
      _ctrl.clear();
    });
  }

  void _submit() {
    final val = _ctrl.text.trim();
    if (val.isEmpty) return;
    final emoji = _selected.firstOrNull?.emoji ?? '🍛';
    final recipeIds = _selected.map((r) => r.id).toList();
    widget.onConfirm(val, emoji, recipeIds);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Recipe picker (shown only when recipes exist) ───────────
            if (widget.recipes.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    '📖  From Recipe Box',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_selected.length} selected',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: widget.color,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _clearRecipe,
                      child: Text(
                        '✕ Clear',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: widget.color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 62,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _sorted.length,
                  itemBuilder: (_, i) {
                    final r = _sorted[i];
                    final sel = _selected.any((s) => s.id == r.id);
                    return GestureDetector(
                      onTap: () => _pickRecipe(r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? widget.color.withValues(alpha: 0.14)
                              : surfBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sel
                                ? widget.color
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(r.emoji,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  r.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                    color: sel ? widget.color : tc,
                                  ),
                                ),
                                if (r.suitableFor.isNotEmpty)
                                  Text(
                                    r.suitableFor
                                        .map((m) => m.label)
                                        .join(', '),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: sub.withValues(alpha: 0.2),
                            height: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'or type meal name',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          color: sub,
                        ),
                      ),
                    ),
                    Expanded(
                        child: Divider(
                            color: sub.withValues(alpha: 0.2),
                            height: 1)),
                  ],
                ),
              ),
            ],

            // ── Name text field ─────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: surfBg,
                borderRadius: BorderRadius.circular(14),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: TextField(
                controller: _ctrl,
                autofocus: widget.recipes.isEmpty,
                textCapitalization: TextCapitalization.words,
                style:
                    TextStyle(fontSize: 15, color: tc, fontFamily: 'Nunito'),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration.collapsed(
                  hintText: 'e.g. Idli & Sambar, Biryani…',
                  hintStyle: TextStyle(
                      fontSize: 14, color: sub, fontFamily: 'Nunito'),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Confirm button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _ctrl,
                builder: (_, v, _) {
                  final ok = v.text.trim().isNotEmpty;
                  return ElevatedButton(
                    onPressed: ok ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ok ? widget.color : surfBg,
                      foregroundColor: ok ? Colors.white : sub,
                      elevation: ok ? 4 : 0,
                      shadowColor: widget.color.withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      ok ? 'Confirm →' : 'Pick a recipe or type a name',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP: EMOJI — horizontal scrollable emoji row
// ═══════════════════════════════════════════════════════════════════════════════

class _EmojiStep extends StatefulWidget {
  final Color color;
  final void Function(String) onSelect;

  const _EmojiStep({required this.color, required this.onSelect});

  @override
  State<_EmojiStep> createState() => _EmojiStepState();
}

class _EmojiStepState extends State<_EmojiStep> {
  String? _selected;

  static const _emojis = [
    '🍛', '🫓', '🥘', '🍲', '🫕', '🍚', '🥗', '🍽️',
    '☕', '🧋', '🍜', '🫙', '🥟', '🫔', '🍱', '🥞', '🥛', '🌶️',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfBg = isDark ? AppColors.surfDark : AppColors.bgLight;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _emojis.length,
                itemBuilder: (_, i) {
                  final e = _emojis[i];
                  final sel = e == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 46,
                      height: 46,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? widget.color.withValues(alpha: 0.15)
                            : surfBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel
                              ? widget.color
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(e,
                          style: const TextStyle(fontSize: 24)),
                    ),
                  );
                },
              ),
            ),
            if (_selected != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onSelect(_selected!);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor:
                        widget.color.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Use $_selected →',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP: CONFIRM — summary card
// ═══════════════════════════════════════════════════════════════════════════════

class _ConfirmStep extends StatelessWidget {
  final _MealFlowData data;
  final DateTime date;
  final Color color;
  final List<RecipeModel> recipes;
  final VoidCallback onSave;
  final VoidCallback onRestart;

  const _ConfirmStep({
    required this.data,
    required this.date,
    required this.color,
    required this.recipes,
    required this.onSave,
    required this.onRestart,
  });

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Summary row
            Row(
              children: [
                // Emoji bubble
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: data.mealTime.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: data.mealTime.color.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(data.emoji,
                      style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.mealName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: data.mealTime.color
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${data.mealTime.emoji}  ${data.mealTime.label}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: data.mealTime.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _dateLabel(date),
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Linked recipes row
            if (data.recipeIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final linked = recipes
                    .where((r) => data.recipeIds.contains(r.id))
                    .toList();
                if (linked.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: linked.map((r) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${r.emoji}  ${r.name}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: color,
                      ),
                    ),
                  )).toList(),
                );
              }),
            ],
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                // Restart / Edit
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: onRestart,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: sub,
                      side: BorderSide(
                          color: sub.withValues(alpha: 0.4)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '✏️ Edit',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Save
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onSave();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: data.mealTime.color,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: data.mealTime.color
                          .withValues(alpha: 0.4),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Save ${data.mealTime.label} →',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DONE CARD — shown after successful save
// ═══════════════════════════════════════════════════════════════════════════════

class _DoneCard extends StatelessWidget {
  final VoidCallback onLogAnother;
  final VoidCallback onClose;

  const _DoneCard({required this.onLogAnother, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.income.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.income.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        children: [
          const Text('✅', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          const Text(
            'Meal Logged!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: AppColors.income,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onLogAnother,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: sub,
                    side: BorderSide(color: sub.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Log Another',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.income,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: AppColors.income.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Done ✓',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
