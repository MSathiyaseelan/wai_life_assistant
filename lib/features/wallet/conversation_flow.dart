import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';
import 'flow_steps.dart';
import 'chat_bubble.dart';

// ── Internal message model ────────────────────────────────────────────────────

class _Message {
  final ChatRole role;
  final String text;
  final FlowStep? inputWidget; // non-null on bot messages that need a widget
  final bool animate;
  final bool widgetDone; // true once user answered this step

  const _Message({
    required this.role,
    required this.text,
    this.inputWidget,
    this.animate = false,
    this.widgetDone = false,
  });

  _Message done() => _Message(
    role: role,
    text: text,
    inputWidget: inputWidget,
    animate: animate,
    widgetDone: true,
  );
}

// ── ConversationFlow widget ───────────────────────────────────────────────────

class ConversationFlow extends StatefulWidget {
  final FlowType flowType;
  final String walletId;

  /// Called after user saves — receives the new TxModel
  final void Function(TxModel tx) onComplete;

  const ConversationFlow({
    super.key,
    required this.flowType,
    required this.walletId,
    required this.onComplete,
  });

  @override
  State<ConversationFlow> createState() => _ConversationFlowState();
}

class _ConversationFlowState extends State<ConversationFlow> {
  final _scrollCtrl = ScrollController();
  final List<_Message> _messages = [];
  bool _showTyping = false;
  bool _done = false;

  late FlowData _data;
  late List<FlowStep> _steps;
  int _stepIdx = 0;

  @override
  void initState() {
    super.initState();
    _data = FlowData();
    _steps = widget.flowType.steps;
    // Post first bot question
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushBotQuestion(0));
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Scrolling ───────────────────────────────────────────────────────────────

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

  // ── Push bot question for step at index ────────────────────────────────────

  void _pushBotQuestion(int idx) {
    if (idx >= _steps.length) return;
    final step = _steps[idx];
    final question = step.botQuestion(widget.flowType);

    // Show typing indicator briefly
    setState(() => _showTyping = true);
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      setState(() {
        _showTyping = false;
        _messages.add(
          _Message(
            role: ChatRole.bot,
            text: question,
            inputWidget: step,
            animate: true,
          ),
        );
      });
      _scrollToBottom();
    });
  }

  // ── User answers a step ─────────────────────────────────────────────────────

  void _answer(FlowStep step, String displayText, VoidCallback applyData) {
    applyData();

    // Mark the last bot message widget as done (hides its input)
    setState(() {
      if (_messages.isNotEmpty) {
        _messages[_messages.length - 1] = _messages[_messages.length - 1]
            .done();
      }
      // Add user bubble
      _messages.add(
        _Message(role: ChatRole.user, text: displayText, animate: true),
      );
    });
    _scrollToBottom();

    _stepIdx++;
    if (_stepIdx < _steps.length) {
      _pushBotQuestion(_stepIdx);
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  void _save() {
    final tx = _data.toTxModel(widget.flowType, widget.walletId);
    // Add saving message
    setState(() {
      _messages.add(
        const _Message(
          role: ChatRole.bot,
          text: '🎉 Saving your transaction...',
          animate: true,
        ),
      );
      _done = true;
    });
    _scrollToBottom();
    widget.onComplete(tx);
  }

  // ── Restart flow ────────────────────────────────────────────────────────────

  void _restart() {
    setState(() {
      _messages.clear();
      _data = FlowData();
      _stepIdx = 0;
      _done = false;
      _showTyping = false;
    });
    _pushBotQuestion(0);
  }

  // ── Build step input widget ─────────────────────────────────────────────────

  Widget _buildInput(FlowStep step) {
    final color = widget.flowType.color;
    final cats = widget.flowType == FlowType.income
        ? incomeCategories
        : expenseCategories;

    switch (step) {
      // ── Amount ──────────────────────────────────────────────────────────────
      case FlowStep.amount:
        return AmountStep(
          color: color,
          onConfirm: (amt) => _answer(step, '₹${amt.toStringAsFixed(0)}', () {
            _data.amount = amt;
          }),
        );

      // ── Category ────────────────────────────────────────────────────────────
      case FlowStep.category:
        return ChipStep(
          options: cats,
          color: color,
          onSelect: (cat) => _answer(step, cat, () {
            _data.category = cat;
          }),
        );

      // ── Owner ────────────────────────────────────────────────────────────────
      case FlowStep.owner:
        return ToggleStep(
          options: const [
            ToggleOption(
              label: 'Personal',
              emoji: '👤',
              color: AppColors.primary,
            ),
            ToggleOption(
              label: 'Family',
              emoji: '👨\u200D👩\u200D👧',
              color: AppColors.income,
            ),
          ],
          onSelect: (v) => _answer(step, v, () {
            _data.owner = v;
          }),
        );

      // ── Pay mode ─────────────────────────────────────────────────────────────
      case FlowStep.paymode:
        return ToggleStep(
          options: const [
            ToggleOption(label: 'Cash', emoji: '💵', color: AppColors.cash),
            ToggleOption(label: 'Online', emoji: '📱', color: AppColors.online),
          ],
          onSelect: (v) => _answer(step, '${v == "Cash" ? "💵" : "📱"} $v', () {
            _data.paymode = v;
          }),
        );

      // ── Date ─────────────────────────────────────────────────────────────────
      case FlowStep.date:
        return DateStep(
          color: color,
          onSelect: (v) => _answer(step, '📅 $v', () {
            _data.date = v;
          }),
        );

      // ── Persons (multi-select for splits) ────────────────────────────────────
      case FlowStep.persons:
        return PersonStep(
          color: color,
          multiSelect: true,
          onSelectSingle: (_) {},
          onSelectMulti: (list) =>
              _answer(step, 'With: ${list.join(", ")}', () {
                _data.persons = list;
              }),
        );

      // ── Split type ───────────────────────────────────────────────────────────
      case FlowStep.splitType:
        return ToggleStep(
          options: [
            ToggleOption(label: 'Equal Split', emoji: '⚖️', color: color),
            ToggleOption(label: 'Custom', emoji: '✏️', color: AppColors.lend),
          ],
          onSelect: (v) => _answer(step, v, () {
            _data.splitType = v;
          }),
        );

      // ── Single person ────────────────────────────────────────────────────────
      case FlowStep.person:
        return PersonStep(
          color: color,
          multiSelect: false,
          onSelectSingle: (p) => _answer(step, p, () {
            _data.person = p;
          }),
          onSelectMulti: (_) {},
        );

      // ── Due date ─────────────────────────────────────────────────────────────
      case FlowStep.dueDate:
        return DueDateStep(
          color: color,
          onSelect: (v) => _answer(step, '📅 $v', () {
            _data.dueDate = v;
          }),
        );

      // ── Note ─────────────────────────────────────────────────────────────────
      case FlowStep.note:
        return NoteStep(
          color: color,
          onConfirm: (note) {
            final display = note.isEmpty ? 'No note' : '📝 $note';
            _answer(step, display, () {
              _data.note = note;
            });
          },
        );

      // ── Confirm ──────────────────────────────────────────────────────────────
      case FlowStep.confirm:
        return ConfirmStep(
          data: _data,
          flowType: widget.flowType,
          onSave: _save,
          onEdit: _restart,
        );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.flowType.color;

    return Column(
      children: [
        // Progress bar
        _ProgressBar(current: _stepIdx, total: _steps.length, color: color),

        // Messages + inputs
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount:
                _messages.length + (_showTyping ? 1 : 0) + (_done ? 1 : 0),
            itemBuilder: (ctx, i) {
              // Typing indicator
              if (_showTyping && i == _messages.length) {
                return const TypingIndicator();
              }
              // Success card
              if (_done && i == _messages.length + (_showTyping ? 1 : 0)) {
                return SuccessStep(
                  data: _data,
                  flowType: widget.flowType,
                  onAddAnother: _restart,
                );
              }

              final msg = _messages[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Chat bubble
                  ChatBubble(
                    isBot: msg.role == ChatRole.bot,
                    text: msg.text,
                    accentColor: color,
                    animate: msg.animate,
                  ),
                  // Input widget (only on latest unanswered bot msg)
                  if (msg.role == ChatRole.bot &&
                      msg.inputWidget != null &&
                      !msg.widgetDone &&
                      i == _messages.length - 1 &&
                      !_showTyping)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, bottom: 6),
                      child: _buildInput(msg.inputWidget!),
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
