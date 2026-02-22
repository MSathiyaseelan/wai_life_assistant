import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// AMOUNT STEP  — full custom numpad
// ═══════════════════════════════════════════════════════════════════════════════

class AmountStep extends StatefulWidget {
  final Color color;
  final void Function(double amount) onConfirm;

  const AmountStep({super.key, required this.color, required this.onConfirm});

  @override
  State<AmountStep> createState() => _AmountStepState();
}

class _AmountStepState extends State<AmountStep> {
  String _value = '';

  static const _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '.',
    '0',
    '⌫',
  ];

  void _press(String k) {
    setState(() {
      if (k == '⌫') {
        if (_value.isNotEmpty) _value = _value.substring(0, _value.length - 1);
      } else if (k == '.' && _value.contains('.')) {
        return;
      } else if (_value.length >= 9) {
        return;
      } else {
        _value += k;
      }
    });
  }

  String get _display => _value.isEmpty ? '₹0' : '₹$_value';
  double get _parsed => double.tryParse(_value) ?? 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : AppColors.bgLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _display,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                fontFamily: 'DM Mono',
                color: _value.isEmpty ? subColor : textColor,
                letterSpacing: -2,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Numpad grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.8,
            children: _keys.map((k) {
              final isDelete = k == '⌫';
              return _NumKey(
                label: k,
                isDelete: isDelete,
                surfBg: surfBg,
                textColor: textColor,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _press(k);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Confirm button
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _parsed > 0 ? () => widget.onConfirm(_parsed) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _parsed > 0 ? widget.color : surfBg,
                foregroundColor: _parsed > 0 ? Colors.white : subColor,
                elevation: _parsed > 0 ? 4 : 0,
                shadowColor: widget.color.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                _parsed > 0 ? 'Confirm $_display →' : 'Enter amount first',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumKey extends StatefulWidget {
  final String label;
  final bool isDelete;
  final Color surfBg, textColor;
  final VoidCallback onTap;

  const _NumKey({
    required this.label,
    required this.isDelete,
    required this.surfBg,
    required this.textColor,
    required this.onTap,
  });

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        widget.onTap();
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.identity()..scale(_pressed ? 0.92 : 1.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.isDelete
              ? AppColors.expense.withOpacity(0.12)
              : widget.surfBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: widget.isDelete
            ? Icon(Icons.backspace_outlined, color: AppColors.expense, size: 22)
            : Text(
                widget.label,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'DM Mono',
                  color: widget.textColor,
                ),
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHIP STEP — scrollable chip selector (category picker)
// ═══════════════════════════════════════════════════════════════════════════════

class ChipStep extends StatelessWidget {
  final List<String> options;
  final Color color;
  final void Function(String value) onSelect;

  const ChipStep({
    super.key,
    required this.options,
    required this.color,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfBg = isDark ? AppColors.surfDark : AppColors.bgLight;
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map(
              (opt) => _ChipItem(
                label: opt,
                color: color,
                surfBg: surfBg,
                subColor: subColor,
                onTap: () => onSelect(opt),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ChipItem extends StatefulWidget {
  final String label;
  final Color color, surfBg, subColor;
  final VoidCallback onTap;

  const _ChipItem({
    required this.label,
    required this.color,
    required this.surfBg,
    required this.subColor,
    required this.onTap,
  });

  @override
  State<_ChipItem> createState() => _ChipItemState();
}

class _ChipItemState extends State<_ChipItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_pressed ? 0.94 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed ? widget.color.withOpacity(0.18) : widget.surfBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _pressed ? widget.color : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
            color: _pressed ? widget.color : widget.subColor,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOGGLE STEP — large tap cards (Personal/Family, Cash/Online, Equal/Custom)
// ═══════════════════════════════════════════════════════════════════════════════

class ToggleOption {
  final String label;
  final String emoji;
  final Color color;

  const ToggleOption({
    required this.label,
    required this.emoji,
    required this.color,
  });
}

class ToggleStep extends StatelessWidget {
  final List<ToggleOption> options;
  final void Function(String value) onSelect;

  const ToggleStep({super.key, required this.options, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: options
            .map(
              (opt) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: options.indexOf(opt) == 0 ? 0 : 6,
                    right: options.indexOf(opt) == options.length - 1 ? 0 : 6,
                  ),
                  child: _ToggleCard(
                    option: opt,
                    onTap: () => onSelect(opt.label),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ToggleCard extends StatefulWidget {
  final ToggleOption option;
  final VoidCallback onTap;
  const _ToggleCard({required this.option, required this.onTap});
  @override
  State<_ToggleCard> createState() => _ToggleCardState();
}

class _ToggleCardState extends State<_ToggleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.option.color;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_pressed ? 0.95 : 1.0),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: _pressed ? c.withOpacity(0.22) : c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: c.withOpacity(_pressed ? 0.2 : 0.08),
              blurRadius: _pressed ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.option.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 10),
            Text(
              widget.option.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATE STEP — quick date chips
// ═══════════════════════════════════════════════════════════════════════════════

class DateStep extends StatelessWidget {
  final Color color;
  final void Function(String value) onSelect;

  const DateStep({super.key, required this.color, required this.onSelect});

  static const _options = [
    ('📅', 'Today'),
    ('⏮️', 'Yesterday'),
    ('📆', '2 days ago'),
    ('🗓️', 'Pick date'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _options
            .map(
              (o) => _DateChip(
                emoji: o.$1,
                label: o.$2,
                color: color,
                onTap: () => onSelect(o.$2),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DateChip extends StatefulWidget {
  final String emoji, label;
  final Color color;
  final VoidCallback onTap;
  const _DateChip({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  State<_DateChip> createState() => _DateChipState();
}

class _DateChipState extends State<_DateChip> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_pressed ? 0.94 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_pressed ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: widget.color.withOpacity(0.35), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERSON STEP — contact chips (single or multi-select)
// ═══════════════════════════════════════════════════════════════════════════════

class PersonStep extends StatefulWidget {
  final Color color;
  final bool multiSelect;
  final void Function(String) onSelectSingle;
  final void Function(List<String>) onSelectMulti;

  const PersonStep({
    super.key,
    required this.color,
    this.multiSelect = false,
    required this.onSelectSingle,
    required this.onSelectMulti,
  });

  @override
  State<PersonStep> createState() => _PersonStepState();
}

class _PersonStepState extends State<PersonStep> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: contactNames.map((name) {
              final isSel = _selected.contains(name);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (!widget.multiSelect) {
                    widget.onSelectSingle(name);
                    return;
                  }
                  setState(() {
                    if (isSel)
                      _selected.remove(name);
                    else
                      _selected.add(name);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? widget.color.withOpacity(0.15)
                        : (isDark ? AppColors.surfDark : AppColors.bgLight),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSel ? widget.color : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSel
                              ? widget.color.withOpacity(0.25)
                              : (isDark ? AppColors.cardDark : Colors.white),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          name[0],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isSel
                                ? widget.color
                                : (isDark
                                      ? AppColors.subDark
                                      : AppColors.subLight),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: isSel
                              ? widget.color
                              : (isDark
                                    ? AppColors.textDark
                                    : AppColors.textLight),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Multi-select confirm
          if (widget.multiSelect && _selected.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onSelectMulti(_selected.toList()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.color,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: widget.color.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Split with ${_selected.join(', ')} →',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTE STEP — optional text field with skip
// ═══════════════════════════════════════════════════════════════════════════════

class NoteStep extends StatefulWidget {
  final Color color;
  final void Function(String note) onConfirm;

  const NoteStep({super.key, required this.color, required this.onConfirm});

  @override
  State<NoteStep> createState() => _NoteStepState();
}

class _NoteStepState extends State<NoteStep> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() => _hasText = _ctrl.text.isNotEmpty));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfBg = isDark ? AppColors.surfDark : AppColors.bgLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text area
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hasText
                    ? widget.color.withOpacity(0.4)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _ctrl,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Nunito',
                color: textColor,
              ),
              decoration: InputDecoration.collapsed(
                hintText: 'e.g. For last night\'s dinner...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: subColor,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Skip
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onConfirm(''),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(
                      color: isDark ? AppColors.subDark : AppColors.subLight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: subColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Add note
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => widget.onConfirm(_ctrl.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: widget.color.withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _hasText ? 'Add Note →' : 'No Note →',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      fontSize: 14,
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

// ═══════════════════════════════════════════════════════════════════════════════
// DUE DATE STEP — quick due date chips
// ═══════════════════════════════════════════════════════════════════════════════

class DueDateStep extends StatelessWidget {
  final Color color;
  final void Function(String value) onSelect;

  const DueDateStep({super.key, required this.color, required this.onSelect});

  static const _options = [
    ('📅', 'In 1 week'),
    ('📅', 'In 2 weeks'),
    ('🗓️', 'In 1 month'),
    ('⏳', 'No due date'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _options
            .map(
              (o) => _DateChip(
                emoji: o.$1,
                label: o.$2,
                color: color,
                onTap: () => onSelect(o.$2),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIRM STEP — summary card
// ═══════════════════════════════════════════════════════════════════════════════

class ConfirmStep extends StatelessWidget {
  final FlowData data;
  final FlowType flowType;
  final VoidCallback onSave;
  final VoidCallback onEdit;

  const ConfirmStep({
    super.key,
    required this.data,
    required this.flowType,
    required this.onSave,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final rows = data.summaryRows;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [flowType.color, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Text(flowType.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SUMMARY',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      flowType.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Summary rows
          ...rows.asMap().entries.map((entry) {
            final isLast = entry.key == rows.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.07)
                              : Colors.black.withOpacity(0.06),
                        ),
                      ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.value.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.subDark : AppColors.subLight,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      entry.value.value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.textDark
                            : AppColors.textLight,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text(
                      'Edit',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(
                      'Save Transaction',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: flowType.color,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: flowType.color.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUCCESS STEP — celebration card
// ═══════════════════════════════════════════════════════════════════════════════

class SuccessStep extends StatefulWidget {
  final FlowData data;
  final FlowType flowType;
  final VoidCallback onAddAnother;

  const SuccessStep({
    super.key,
    required this.data,
    required this.flowType,
    required this.onAddAnother,
  });

  @override
  State<SuccessStep> createState() => _SuccessStepState();
}

class _SuccessStepState extends State<SuccessStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amt = widget.data.amount ?? 0;
    final fmtAmt = amt >= 1000
        ? '${(amt / 1000).toStringAsFixed(1)}K'
        : amt.toStringAsFixed(0);

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.flowType.color.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 14),
              const Text(
                'Saved!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₹$fmtAmt',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'DM Mono',
                  color: widget.flowType.color,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.flowType.label} recorded successfully',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Nunito',
                  color: isDark ? AppColors.subDark : AppColors.subLight,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onAddAnother,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.flowType.color,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: widget.flowType.color.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '+ Add Another',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
