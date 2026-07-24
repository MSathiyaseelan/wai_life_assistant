part of 'my_functions_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel({required this.text});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          fontFamily: 'Nunito',
          color: isDark ? AppColors.subDark : AppColors.subLight,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO TAB LABELED ROW
// ─────────────────────────────────────────────────────────────────────────────
class _InfoDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color tc;
  final Color sub;
  final bool isLast;
  const _InfoDetailRow({
    required this.label,
    required this.value,
    required this.isDark,
    required this.tc,
    required this.sub,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: sub,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    color: tc,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: _funcColor.withValues(alpha: 0.12)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION ADD SHEET  —  AI Parse tab  +  Manual tab
// ─────────────────────────────────────────────────────────────────────────────

class _FunctionAddSheet extends StatefulWidget {
  final int tabIdx;
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final List<UpcomingFunction> upcomingList;
  final Future<void> Function(
    String,
    FunctionType,
    String?,
    String?,
    DateTime?,
    String?,
    String?,
    bool,
    String,
    List<PlannedGiftItem>,
  )
  onSave;
  // (title, type, customType, venue, date, personName, familyName, isPlanned, icon, gifts)

  final bool isPlannedDefault;

  const _FunctionAddSheet({
    required this.tabIdx,
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    required this.upcomingList,
    required this.onSave,
    this.isPlannedDefault = true,
  });

  @override
  State<_FunctionAddSheet> createState() => _FunctionAddSheetState();
}

class _FunctionAddSheetState extends State<_FunctionAddSheet>
    with SingleTickerProviderStateMixin {
  late TabController _mode;

  final _aiCtrl = TextEditingController();
  bool _aiParsing = false;
  _ParsedFunction? _aiPreview;
  String? _aiError;

  final _titleCtrl = TextEditingController();
  final _customTypeCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _personCtrl = TextEditingController();
  final _familyNameCtrl = TextEditingController();
  var _type = FunctionType.wedding;
  DateTime? _date;

  late bool _isFunctionPlanned;
  String _icon = '🎊';
  String? _photoPath;

  // Attended-only: gift(s) given at the function, entered manually regardless
  // of whether title/venue/date came from the AI parser or manual fields.
  final List<PlannedGiftItem> _gifts = [];

  @override
  void initState() {
    super.initState();
    _isFunctionPlanned = widget.isPlannedDefault;
    _mode = TabController(length: 2, vsync: this);
    _mode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _mode.dispose();
    _aiCtrl.dispose();
    _titleCtrl.dispose();
    _customTypeCtrl.dispose();
    _venueCtrl.dispose();
    _personCtrl.dispose();
    _familyNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _parseAI(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _aiParsing = true;
      _aiError = null;
      _aiPreview = null;
    });
    _ParsedFunction? result;
    try {
      result = await _FunctionAIParser.parse(text.trim(), widget.tabIdx);
    } catch (e) {
      ErrorLogger.warning(e, action: 'function_ai_parse_fallback');
      if (mounted) {
        maybeShowAiLimitSnackbar(context, e.toString().replaceFirst('Exception: ', ''));
      }
      result = _FunctionNlpParser.parse(text.trim(), widget.tabIdx);
    }
    if (!mounted) return;
    setState(() {
      _aiPreview = result;
      _aiParsing = false;
      _titleCtrl.text = result!.title;
      _venueCtrl.text = result.venue ?? '';
      _personCtrl.text = result.personName ?? '';
      _familyNameCtrl.text = result.familyName ?? '';
      _type = result.type;
      _date = result.date;
      // Pre-fill the gift editor from the AI's extracted gift (if any) —
      // only when the user hasn't already entered one manually.
      if (result.gift != null && _gifts.isEmpty) {
        _gifts.add(result.gift!);
      }
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      if (_mode.index == 0) _mode.animateTo(1);
      return;
    }
    String icon = _icon;
    if (_photoPath != null) {
      try {
        icon = await ProfileService.instance.uploadPhoto(
          localPath: _photoPath!,
          folder: 'functions',
          name: 'fn_${DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_icon_upload_error');
        debugPrint('[Functions] icon upload error: $e');
      }
    }
    final needsPersonFields = widget.tabIdx != 2;
    await widget.onSave(
      title,
      _type,
      _type == FunctionType.other && _customTypeCtrl.text.trim().isNotEmpty
          ? _customTypeCtrl.text.trim()
          : null,
      _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
      _date,
      needsPersonFields
          ? (_personCtrl.text.trim().isEmpty ? null : _personCtrl.text.trim())
          : null,
      needsPersonFields
          ? (_familyNameCtrl.text.trim().isEmpty
                ? null
                : _familyNameCtrl.text.trim())
          : null,
      _isFunctionPlanned,
      icon,
      _gifts,
    );
  }

  void _pickIcon(BuildContext ctx) {
    final isDark = widget.isDark;
    final surfBg = widget.surfBg;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Icon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx2);
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (picked != null && mounted) {
                          setState(() => _photoPath = picked.path);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: surfBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.photo_library_rounded, size: 24, color: _funcColor),
                            SizedBox(height: 4),
                            Text('Gallery', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx2);
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.camera,
                          imageQuality: 80,
                        );
                        if (picked != null && mounted) {
                          setState(() => _photoPath = picked.path);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: surfBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.camera_alt_rounded, size: 24, color: _funcColor),
                            SizedBox(height: 4),
                            Text('Camera', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _fnIconEmojis.map((e) {
                  final selected = _photoPath == null && _icon == e;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _icon = e;
                        _photoPath = null;
                      });
                      Navigator.pop(ctx2);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? _funcColor.withValues(alpha: 0.15)
                            : surfBg,
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(color: _funcColor, width: 1.5)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surfBg = widget.surfBg;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final sheetTitle = widget.tabIdx == 0
        ? 'Add Upcoming'
        : widget.tabIdx == 1
        ? 'Record Attended'
        : 'Add Function';

    // A plain Column (not ListView) — this sheet's own scrolling is already
    // provided by showPlanSheet's outer SingleChildScrollView; nesting a
    // second scrollable here caused the inner ListView's gesture recognizer
    // to swallow drags, freezing the sheet once content (e.g. the gift
    // editor) grew taller than the visible area, hiding the Save button.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
        Text(
          sheetTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
          ),
        ),
        const SizedBox(height: 14),
        // Mode switcher
        Container(
          decoration: BoxDecoration(
            color: surfBg,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _mode,
            indicator: BoxDecoration(
              color: _funcColor,
              borderRadius: BorderRadius.circular(11),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: sub,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              fontFamily: 'Nunito',
            ),
            padding: EdgeInsets.zero,
            tabs: const [
              Tab(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('✨', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('AI Parse'),
                  ],
                ),
              ),
              Tab(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_outlined, size: 14),
                    SizedBox(width: 6),
                    Text('Manual'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── AI TAB ─────────────────────────────────────────────────────────
        if (_mode.index == 0) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _funcColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _funcColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✨', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.tabIdx == 0
                        ? 'Describe the upcoming function — e.g. "Raj\'s wedding at ABC Hall on June 20"'
                        : widget.tabIdx == 1
                        ? 'Describe what you attended — e.g. "Priya\'s birthday at Grand Hall on 5th March"'
                        : 'Describe the function — e.g. "Son\'s wedding at ABC Mahal on June 20"',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: tc,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _funcColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: TextField(
                    controller: _aiCtrl,
                    maxLines: 3,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 14,
                      color: tc,
                      fontFamily: 'Nunito',
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: widget.tabIdx == 0
                          ? '"Priya\'s wedding at Palace Hall on May 20"'
                          : '"Family wedding at ABC Mahal on June 15"',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: sub,
                        fontFamily: 'Nunito',
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 14,
                  endIndent: 14,
                  color: _funcColor.withValues(alpha: 0.15),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Plain text → AI fills all fields',
                          style: TextStyle(
                            fontSize: 11,
                            color: sub,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _aiParsing ? null : () => _parseAI(_aiCtrl.text),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: _aiParsing
                                ? _funcColor.withValues(alpha: 0.3)
                                : _funcColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: _aiParsing
                              ? const SizedBox(
                                  width: 64,
                                  height: 16,
                                  child: LinearProgressIndicator(
                                    backgroundColor: Colors.transparent,
                                    color: Colors.white,
                                    minHeight: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('✨', style: TextStyle(fontSize: 13)),
                                    SizedBox(width: 5),
                                    Text(
                                      'Parse',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        fontFamily: 'Nunito',
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _aiError!,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Nunito',
                  color: AppColors.expense,
                ),
              ),
            ),
          ],
          if (_aiPreview != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: isDark ? 0.1 : 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.income.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _funcColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _aiPreview!.type.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _aiPreview!.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Nunito',
                                color: tc,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.income.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '✨ AI Parsed',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.income,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _mode.animateTo(1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: surfBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.income.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 12,
                                color: AppColors.income,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.income,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _FuncPreviewChip(
                        icon: Icons.celebration_rounded,
                        label: _aiPreview!.type.label,
                        color: _funcColor,
                      ),
                      if (_aiPreview!.date != null)
                        _FuncPreviewChip(
                          icon: Icons.calendar_today_rounded,
                          label:
                              '${_aiPreview!.date!.day}/${_aiPreview!.date!.month}/${_aiPreview!.date!.year}',
                          color: AppColors.income,
                        ),
                      if (_aiPreview!.venue != null)
                        _FuncPreviewChip(
                          icon: Icons.location_on_rounded,
                          label: _aiPreview!.venue!,
                          color: AppColors.lend,
                        ),
                      if (_aiPreview!.personName != null)
                        _FuncPreviewChip(
                          icon: Icons.person_rounded,
                          label: _aiPreview!.personName!,
                          color: AppColors.split,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.tabIdx == 1) ...[
              const SizedBox(height: 12),
              _GiftEntryEditor(
                gifts: _gifts,
                funcColor: _funcColor,
                onChanged: () => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),
            SaveButton(label: 'Save →', color: _funcColor, onTap: _save),
          ],
        ],

        // ── MANUAL TAB ─────────────────────────────────────────────────────
        if (_mode.index == 1) ...[
          if (widget.tabIdx == 2) ...[
            const SheetLabel(text: 'QUICK OPTIONS'),
            Row(
              children: [
                _QuickOptionChip(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Completed Function',
                  active: !_isFunctionPlanned,
                  color: _funcColor,
                  onTap: () => setState(() => _isFunctionPlanned = false),
                ),
                const SizedBox(width: 8),
                _QuickOptionChip(
                  icon: Icons.event_rounded,
                  label: 'Plan for Function',
                  active: _isFunctionPlanned,
                  color: AppColors.income,
                  onTap: () => setState(() => _isFunctionPlanned = true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isFunctionPlanned) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.income.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.income.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 14,
                      color: AppColors.income,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'This will be saved as a planned function',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: AppColors.income,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (widget.tabIdx == 2) ...[
            const SheetLabel(text: 'GROUP ICON'),
            GestureDetector(
              onTap: () => _pickIcon(context),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _funcColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _funcColor.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: EmojiOrImage(
                      value: _photoPath ?? _icon,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tap to change icon',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.subDark : AppColors.subLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SheetLabel(text: 'FUNCTION TYPE'),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: FunctionType.values
                  .map(
                    (t) => GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _type == t
                              ? _funcColor.withValues(alpha: 0.15)
                              : surfBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _type == t ? _funcColor : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(t.emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 5),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: _type == t ? _funcColor : sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.tabIdx != 2) ...[
            PlanInputField(
              controller: _personCtrl,
              hint: 'Person name (e.g. Priya)',
            ),
            const SizedBox(height: 8),
            PlanInputField(
              controller: _familyNameCtrl,
              hint: 'Family name (e.g. Sharma family)',
            ),
            const SizedBox(height: 8),
          ],
          PlanInputField(controller: _titleCtrl, hint: 'Function title *'),
          if (_type == FunctionType.other) ...[
            const SizedBox(height: 8),
            PlanInputField(
              controller: _customTypeCtrl,
              hint: 'Enter function type',
            ),
          ],
          const SizedBox(height: 8),
          PlanInputField(controller: _venueCtrl, hint: 'Venue / Location'),
          const SizedBox(height: 8),
          LifeDateTile(
            date: _date,
            hint: 'Function date',
            color: _funcColor,
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          if (widget.tabIdx == 1) ...[
            const SizedBox(height: 8),
            _GiftEntryEditor(
              gifts: _gifts,
              funcColor: _funcColor,
              onChanged: () => setState(() {}),
            ),
          ],
          SaveButton(label: 'Save', color: _funcColor, onTap: _save),
        ],
      ],
      ),
    );
  }
}

// ── Quick option chip ──────────────────────────────────────────────────────────
class _QuickOptionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _QuickOptionChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.15)
              : (isDark ? AppColors.surfDark : const Color(0xFFEDEEF5)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? color : sub),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: active ? color : sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preview chip ───────────────────────────────────────────────────────────────
class _FuncPreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FuncPreviewChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
            color: color,
          ),
        ),
      ],
    ),
  );
}

