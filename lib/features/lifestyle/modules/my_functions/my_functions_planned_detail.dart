part of 'my_functions_screen.dart';

// ── Planned function detail ───────────────────────────────────────────────────

class _PlannedFunctionDetail extends StatefulWidget {
  final FunctionModel fn;
  final bool isDark;
  final VoidCallback onUpdate;
  final Map<String, String> familyWalletNames;
  final Map<String, String> allFamilyWalletNames;
  final String personalWalletId;
  final String currentWalletId;
  const _PlannedFunctionDetail({
    required this.fn,
    required this.isDark,
    required this.onUpdate,
    this.familyWalletNames = const {},
    this.allFamilyWalletNames = const {},
    this.personalWalletId = '',
    this.currentWalletId = '',
  });
  @override
  State<_PlannedFunctionDetail> createState() => _PlannedFunctionDetailState();
}

class _PlannedFunctionDetailState extends State<_PlannedFunctionDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Participants
  final List<FunctionParticipant> _participants = [];
  // Clothing families
  final List<ClothingFamily> _clothingFamilies = [];
  // Bridal essentials
  final List<BridalEssential> _bridals = [];
  // Return gifts
  final List<FunctionReturnGift> _returnGifts = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 7, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final svc = FunctionsService.instance;
    final id = widget.fn.id;
    try {
      final results = await Future.wait([
        svc.fetchParticipants(id),
        svc.fetchClothingFamilies(id),
        svc.fetchBridalEssentials(id),
        svc.fetchReturnGifts(id),
      ]);
      if (!mounted) return;
      setState(() {
        _participants
          ..clear()
          ..addAll(results[0].map((r) => FunctionParticipant.fromJson(r)));
        _clothingFamilies
          ..clear()
          ..addAll(results[1].map((r) => ClothingFamily.fromJson(r)));
        _bridals
          ..clear()
          ..addAll(results[2].map((r) => BridalEssential.fromJson(r)));
        _returnGifts
          ..clear()
          ..addAll(results[3].map((r) => FunctionReturnGift.fromJson(r)));
        _loading = false;
      });
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'planned_detail_load');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final fn = widget.fn;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          fn.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _showEditPlanned(context, isDark, surfBg),
            tooltip: 'Edit Function',
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          dividerColor: Colors.transparent,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            fontSize: 12,
          ),
          indicatorColor: AppColors.income,
          labelColor: AppColors.income,
          unselectedLabelColor: sub,
          tabs: const [
            Tab(text: 'Info'),
            Tab(text: 'Participants'),
            Tab(text: 'Clothing Gifts'),
            Tab(text: 'Bridal Essentials'),
            Tab(text: 'Return Gift'),
            Tab(text: 'Vendors'),
            Tab(text: 'Messages'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.income))
          : TabBarView(
              controller: _tab,
              children: [
                // INFO
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.income.withValues(alpha: 0.18)),
                        ),
                        child: Column(
                          children: [
                            _InfoDetailRow(
                              label: 'Function Type',
                              value: '${fn.type.emoji}  ${fn.type == FunctionType.other && fn.customType != null ? fn.customType! : fn.type.label}',
                              isDark: isDark,
                              tc: isDark ? AppColors.textDark : AppColors.textLight,
                              sub: isDark ? AppColors.subDark : AppColors.subLight,
                            ),
                            _InfoDetailRow(
                              label: 'Function Name',
                              value: fn.title,
                              isDark: isDark,
                              tc: isDark ? AppColors.textDark : AppColors.textLight,
                              sub: isDark ? AppColors.subDark : AppColors.subLight,
                            ),
                            if (fn.functionDate != null)
                              _InfoDetailRow(
                                label: 'Planned Date',
                                value: fmtDate(fn.functionDate!),
                                isDark: isDark,
                                tc: isDark ? AppColors.textDark : AppColors.textLight,
                                sub: isDark ? AppColors.subDark : AppColors.subLight,
                              ),
                            if (fn.venue != null)
                              _InfoDetailRow(
                                label: 'Venue',
                                value: fn.venue!,
                                isDark: isDark,
                                tc: isDark ? AppColors.textDark : AppColors.textLight,
                                sub: isDark ? AppColors.subDark : AppColors.subLight,
                                isLast: fn.address == null && fn.notes == null,
                              ),
                            if (fn.address != null)
                              _InfoDetailRow(
                                label: 'Address',
                                value: fn.address!,
                                isDark: isDark,
                                tc: isDark ? AppColors.textDark : AppColors.textLight,
                                sub: isDark ? AppColors.subDark : AppColors.subLight,
                                isLast: fn.notes == null,
                              ),
                            if (fn.notes != null)
                              _InfoDetailRow(
                                label: 'Notes',
                                value: fn.notes!,
                                isDark: isDark,
                                tc: isDark ? AppColors.textDark : AppColors.textLight,
                                sub: isDark ? AppColors.subDark : AppColors.subLight,
                                isLast: true,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _FuncStat(
                            label: 'Participants',
                            value: '${_participants.fold(0, (s, p) => s + p.totalCount)}',
                            emoji: '👥',
                            color: AppColors.income,
                          ),
                          const SizedBox(width: 10),
                          _FuncStat(
                            label: 'Clothing',
                            value: '${_clothingFamilies.fold(0, (s, f) => s + f.members.length)}',
                            emoji: '👗',
                            color: _funcColor,
                          ),
                          const SizedBox(width: 10),
                          _FuncStat(
                            label: 'Return Gifts',
                            value: '${_returnGifts.length}',
                            emoji: '🎁',
                            color: AppColors.lend,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                _ParticipantsTab(
                  functionId: fn.id,
                  participants: _participants,
                  isDark: isDark,
                  surfBg: surfBg,
                  onChanged: () => setState(() {}),
                ),
                _ClothingGiftsTab(
                  functionId: fn.id,
                  families: _clothingFamilies,
                  isDark: isDark,
                  surfBg: surfBg,
                  onChanged: () => setState(() {}),
                ),
                _BridalEssentialsTab(
                  functionId: fn.id,
                  essentials: _bridals,
                  isDark: isDark,
                  surfBg: surfBg,
                  onChanged: () => setState(() {}),
                ),
                _ReturnGiftsTab(
                  functionId: fn.id,
                  gifts: _returnGifts,
                  isDark: isDark,
                  surfBg: surfBg,
                  onChanged: () => setState(() {}),
                ),

                // VENDORS
                _AllVendorsTab(
                  fn: fn,
                  isDark: isDark,
                  onAdd: () => _showAddVendorPlanned(context, isDark, surfBg, fn),
                  onEdit: (v) => _showEditVendorPlanned(context, isDark, surfBg, v),
                  onDelete: (v) => setState(() => fn.vendors.remove(v)),
                ),

                // MESSAGES
                Expanded(
                  child: ChatWidget(
                    messages: fn.chat,
                    isDark: isDark,
                    textOf: (m) => (m as FunctionChatMessage).text,
                    senderOf: (m) => (m as FunctionChatMessage).senderId,
                    onSend: (text) async {
                      setState(
                        () => fn.chat.add(
                          FunctionChatMessage(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            senderId: 'me',
                            text: text,
                            at: DateTime.now(),
                          ),
                        ),
                      );
                      try {
                        await FunctionsService.instance.updateMyFunction(fn.id, fn.toJson());
                      } catch (e, stack) {
                        ErrorLogger.log(e, stackTrace: stack, action: 'function_chat_send');
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _showAddVendorPlanned(BuildContext ctx, bool isDark, Color surfBg, FunctionModel fn) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final advanceCtrl = TextEditingController();
    final eventCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var category = VendorCategory.catering;
    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (sheetCtx, ss) {
          final sub = isDark ? AppColors.subDark : AppColors.subLight;
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 8,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Add Vendor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
                const SizedBox(height: 14),
                const SheetLabel(text: 'VENDOR NAME'),
                PlanInputField(controller: nameCtrl, hint: 'e.g. Sri Krishna Catering'),
                const SizedBox(height: 12),
                const SheetLabel(text: 'CATEGORY'),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: VendorCategory.values.map((c) {
                      final sel = category == c;
                      return GestureDetector(
                        onTap: () => ss(() => category = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? _funcColor.withValues(alpha: 0.15) : surfBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? _funcColor : Colors.transparent),
                          ),
                          child: Text('${c.emoji} ${c.label}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: sel ? _funcColor : sub)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                const SheetLabel(text: 'CONTACT'),
                PlanInputField(controller: phoneCtrl, hint: 'Phone number', inputType: TextInputType.phone),
                const SizedBox(height: 8),
                PlanInputField(controller: emailCtrl, hint: 'Email (optional)', inputType: TextInputType.emailAddress),
                const SizedBox(height: 8),
                PlanInputField(controller: addressCtrl, hint: 'Address (optional)'),
                const SizedBox(height: 12),
                const SheetLabel(text: 'COST'),
                Row(children: [
                  Expanded(child: PlanInputField(controller: costCtrl, hint: 'Total cost (${AppPrefs.cs})', inputType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: PlanInputField(controller: advanceCtrl, hint: 'Advance paid (${AppPrefs.cs})', inputType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                const SheetLabel(text: 'EVENT LINKED'),
                PlanInputField(controller: eventCtrl, hint: 'e.g. Wedding, Housewarming'),
                const SizedBox(height: 12),
                const SheetLabel(text: 'NOTES'),
                PlanInputField(controller: notesCtrl, hint: 'Invoice details, notes…', maxLines: 3),
                SaveButton(
                  label: 'Add Vendor',
                  color: _funcColor,
                  onTap: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    setState(() => fn.vendors.add(FunctionVendor(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text.trim(),
                      category: category,
                      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                      address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                      totalCost: double.tryParse(costCtrl.text.trim()),
                      advancePaid: double.tryParse(advanceCtrl.text.trim()),
                      eventLinked: eventCtrl.text.trim().isEmpty ? null : eventCtrl.text.trim(),
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    )));
                    Navigator.pop(sheetCtx);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditVendorPlanned(BuildContext ctx, bool isDark, Color surfBg, FunctionVendor v) {
    final nameCtrl = TextEditingController(text: v.name);
    final phoneCtrl = TextEditingController(text: v.phone ?? '');
    final emailCtrl = TextEditingController(text: v.email ?? '');
    final addressCtrl = TextEditingController(text: v.address ?? '');
    final costCtrl = TextEditingController(text: v.totalCost?.toStringAsFixed(0) ?? '');
    final advanceCtrl = TextEditingController(text: v.advancePaid?.toStringAsFixed(0) ?? '');
    final eventCtrl = TextEditingController(text: v.eventLinked ?? '');
    final notesCtrl = TextEditingController(text: v.notes ?? '');
    var category = v.category;
    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (sheetCtx, ss) {
          final sub = isDark ? AppColors.subDark : AppColors.subLight;
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 8,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Vendor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
                const SizedBox(height: 14),
                const SheetLabel(text: 'VENDOR NAME'),
                PlanInputField(controller: nameCtrl, hint: 'e.g. Sri Krishna Catering'),
                const SizedBox(height: 12),
                const SheetLabel(text: 'CATEGORY'),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: VendorCategory.values.map((c) {
                      final sel = category == c;
                      return GestureDetector(
                        onTap: () => ss(() => category = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? _funcColor.withValues(alpha: 0.15) : surfBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? _funcColor : Colors.transparent),
                          ),
                          child: Text('${c.emoji} ${c.label}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: sel ? _funcColor : sub)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                const SheetLabel(text: 'CONTACT'),
                PlanInputField(controller: phoneCtrl, hint: 'Phone number', inputType: TextInputType.phone),
                const SizedBox(height: 8),
                PlanInputField(controller: emailCtrl, hint: 'Email (optional)', inputType: TextInputType.emailAddress),
                const SizedBox(height: 8),
                PlanInputField(controller: addressCtrl, hint: 'Address (optional)'),
                const SizedBox(height: 12),
                const SheetLabel(text: 'COST'),
                Row(children: [
                  Expanded(child: PlanInputField(controller: costCtrl, hint: 'Total cost (${AppPrefs.cs})', inputType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: PlanInputField(controller: advanceCtrl, hint: 'Advance paid (${AppPrefs.cs})', inputType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                const SheetLabel(text: 'EVENT LINKED'),
                PlanInputField(controller: eventCtrl, hint: 'e.g. Wedding, Housewarming'),
                const SizedBox(height: 12),
                const SheetLabel(text: 'NOTES'),
                PlanInputField(controller: notesCtrl, hint: 'Invoice details, notes…', maxLines: 3),
                SaveButton(
                  label: 'Save Changes',
                  color: _funcColor,
                  onTap: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    setState(() {
                      v.name = nameCtrl.text.trim();
                      v.category = category;
                      v.phone = phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim();
                      v.email = emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim();
                      v.address = addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim();
                      v.totalCost = double.tryParse(costCtrl.text.trim());
                      v.advancePaid = double.tryParse(advanceCtrl.text.trim());
                      v.eventLinked = eventCtrl.text.trim().isEmpty ? null : eventCtrl.text.trim();
                      v.notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
                    });
                    Navigator.pop(sheetCtx);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditPlanned(BuildContext ctx, bool isDark, Color surfBg) {
    final fn = widget.fn;
    final titleCtrl = TextEditingController(text: fn.title);
    final customTypeCtrl = TextEditingController(text: fn.customType ?? '');
    final venueCtrl = TextEditingController(text: fn.venue ?? '');
    final notesCtrl = TextEditingController(text: fn.notes ?? '');
    DateTime? date = fn.functionDate;
    var type = fn.type;
    var isPlanned = fn.isPlanned;
    String selectedWalletId = fn.walletId;
    String icon = fn.icon;
    String? photoPath;

    final personalId = widget.personalWalletId.isNotEmpty ? widget.personalWalletId : widget.currentWalletId;
    final allFamilyEntries = widget.allFamilyWalletNames.entries.toList();
    final hasWalletChoice = allFamilyEntries.isNotEmpty;

    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) {
          final sub = isDark ? AppColors.subDark : AppColors.subLight;

          void pickIcon() {
            showModalBottomSheet(
              context: ctx2,
              backgroundColor: Colors.transparent,
              builder: (_) => StatefulBuilder(
                builder: (ctx3, setS3) => Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Choose Icon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Nunito')),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                Navigator.pop(ctx3);
                                final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                                if (picked != null) ss(() => photoPath = picked.path);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(12)),
                                child: const Column(children: [
                                  Icon(Icons.photo_library_rounded, size: 24, color: AppColors.income),
                                  SizedBox(height: 4),
                                  Text('Gallery', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                Navigator.pop(ctx3);
                                final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
                                if (picked != null) ss(() => photoPath = picked.path);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(12)),
                                child: const Column(children: [
                                  Icon(Icons.camera_alt_rounded, size: 24, color: AppColors.income),
                                  SizedBox(height: 4),
                                  Text('Camera', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                                ]),
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
                          final selected = photoPath == null && icon == e;
                          return GestureDetector(
                            onTap: () {
                              ss(() { icon = e; photoPath = null; });
                              Navigator.pop(ctx3);
                            },
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: selected ? AppColors.income.withValues(alpha: 0.15) : surfBg,
                                borderRadius: BorderRadius.circular(10),
                                border: selected ? Border.all(color: AppColors.income, width: 1.5) : null,
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

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 8,
              bottom: MediaQuery.of(ctx2).viewInsets.bottom + 36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Function', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
                const SizedBox(height: 12),
                const SheetLabel(text: 'GROUP ICON'),
                GestureDetector(
                  onTap: pickIcon,
                  child: Row(
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.income.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: EmojiOrImage(value: photoPath ?? icon, size: 30),
                      ),
                      const SizedBox(width: 12),
                      Text('Tap to change icon', style: TextStyle(fontSize: 13, fontFamily: 'Nunito', fontWeight: FontWeight.w600, color: sub)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const SheetLabel(text: 'FUNCTION TYPE'),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: FunctionType.values.map((t) => GestureDetector(
                      onTap: () => ss(() => type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: type == t ? AppColors.income.withValues(alpha: 0.15) : surfBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: type == t ? AppColors.income : Colors.transparent),
                        ),
                        child: Row(children: [
                          Text(t.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 5),
                          Text(t.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: type == t ? AppColors.income : sub)),
                        ]),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                PlanInputField(controller: titleCtrl, hint: 'Function title *'),
                if (type == FunctionType.other) ...[
                  const SizedBox(height: 8),
                  PlanInputField(controller: customTypeCtrl, hint: 'Enter function type'),
                ],
                const SizedBox(height: 8),
                PlanInputField(controller: venueCtrl, hint: 'Venue / Location'),
                const SizedBox(height: 8),
                PlanInputField(controller: notesCtrl, hint: 'Notes'),
                const SizedBox(height: 8),
                LifeDateTile(
                  date: date,
                  hint: 'Function date',
                  color: AppColors.income,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) ss(() => date = d);
                  },
                ),
                if (allFamilyEntries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const SheetLabel(text: 'MOVE TO GROUP'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      GestureDetector(
                        onTap: () => ss(() => selectedWalletId = personalId),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedWalletId == personalId ? AppColors.income.withValues(alpha: 0.15) : surfBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selectedWalletId == personalId ? AppColors.income : Colors.transparent),
                          ),
                          child: Text('Personal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: selectedWalletId == personalId ? AppColors.income : sub)),
                        ),
                      ),
                      ...allFamilyEntries.map((e) => GestureDetector(
                        onTap: () => ss(() => selectedWalletId = e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedWalletId == e.key ? AppColors.income.withValues(alpha: 0.15) : surfBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selectedWalletId == e.key ? AppColors.income : Colors.transparent),
                          ),
                          child: Text(e.value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: selectedWalletId == e.key ? AppColors.income : sub)),
                        ),
                      )),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                const SheetLabel(text: 'STATUS'),
                Row(
                  children: [
                    _QuickOptionChip(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Completed',
                      active: !isPlanned,
                      color: _funcColor,
                      onTap: () => ss(() => isPlanned = false),
                    ),
                    const SizedBox(width: 8),
                    _QuickOptionChip(
                      icon: Icons.event_rounded,
                      label: 'Plan for Function',
                      active: isPlanned,
                      color: AppColors.income,
                      onTap: () => ss(() => isPlanned = true),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SaveButton(
                  label: 'Save Changes',
                  color: AppColors.income,
                  onTap: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    String finalIcon = icon;
                    if (photoPath != null) {
                      try {
                        finalIcon = await ProfileService.instance.uploadPhoto(
                          localPath: photoPath!,
                          folder: 'functions',
                          name: 'fn_${fn.id}',
                        );
                      } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_icon_upload_error');
                        debugPrint('[Functions] icon upload error: $e');
                      }
                    }
                    final originalWalletId = fn.walletId;
                    final moved = selectedWalletId != originalWalletId;
                    setState(() {
                      fn.type = type;
                      fn.title = titleCtrl.text.trim();
                      fn.customType = type == FunctionType.other && customTypeCtrl.text.trim().isNotEmpty ? customTypeCtrl.text.trim() : null;
                      fn.functionDate = date;
                      fn.venue = venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim();
                      fn.notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
                      fn.icon = finalIcon;
                      fn.walletId = selectedWalletId;
                      fn.isPlanned = isPlanned;
                    });
                    try {
                      await FunctionsService.instance.updateMyFunction(fn.id, fn.toJson());
                      widget.onUpdate();
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        if (moved && ctx.mounted) Navigator.pop(ctx);
                      }
                    } catch (e, stack) {
                      ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_save');
                      setState(() => fn.walletId = originalWalletId);
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Participants tab ──────────────────────────────────────────────────────────

class _ParticipantsTab extends StatelessWidget {
  final String functionId;
  final List<FunctionParticipant> participants;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onChanged;

  const _ParticipantsTab({
    required this.functionId,
    required this.participants,
    required this.isDark,
    required this.surfBg,
    required this.onChanged,
  });

  void _showAddEdit(BuildContext ctx, {FunctionParticipant? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final placeCtrl = TextEditingController(text: existing?.place ?? '');
    final relationCtrl = TextEditingController(text: existing?.relation ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final List<ParticipantFamilyMember> familyMembers =
        existing?.familyMembers.map((m) => ParticipantFamilyMember(name: m.name, relation: m.relation)).toList() ?? [];

    final svc = FunctionsService.instance;

    showPlanSheet(
      ctx,
      child: StatefulBuilder(builder: (sheetCtx, ss) {
        final sub = isDark ? AppColors.subDark : AppColors.subLight;
        final tc = isDark ? AppColors.textDark : AppColors.textLight;
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 8,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                existing == null ? 'Add Participant' : 'Edit Participant',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito'),
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'NAME *'),
              PlanInputField(controller: nameCtrl, hint: 'Participant name'),
              const SizedBox(height: 8),
              const SheetLabel(text: 'RELATION'),
              PlanInputField(controller: relationCtrl, hint: 'e.g. Uncle, Friend, Colleague'),
              const SizedBox(height: 8),
              const SheetLabel(text: 'PLACE'),
              PlanInputField(controller: placeCtrl, hint: 'City / Town'),
              const SizedBox(height: 8),
              const SheetLabel(text: 'PHONE'),
              PlanInputField(controller: phoneCtrl, hint: 'Phone number', inputType: TextInputType.phone),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('FAMILY MEMBERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: sub, letterSpacing: 0.5)),
                  GestureDetector(
                    onTap: () => ss(() => familyMembers.add(ParticipantFamilyMember(name: '', relation: ''))),
                    child: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.income),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (familyMembers.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('No family members added', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub)),
                ),
              ...familyMembers.asMap().entries.map((entry) {
                final i = entry.key;
                final m = entry.value;
                final mNameCtrl = TextEditingController(text: m.name);
                final mRelCtrl = TextEditingController(text: m.relation);
                mNameCtrl.addListener(() => m.name = mNameCtrl.text);
                mRelCtrl.addListener(() => m.relation = mRelCtrl.text);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: [
                              TextField(
                                controller: mNameCtrl,
                                style: TextStyle(fontSize: 13, color: tc, fontFamily: 'Nunito'),
                                decoration: InputDecoration.collapsed(hintText: 'Name', hintStyle: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito')),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: mRelCtrl,
                                style: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito'),
                                decoration: InputDecoration.collapsed(hintText: 'Relation (e.g. Wife, Son)', hintStyle: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito')),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.expense),
                        onPressed: () => ss(() => familyMembers.removeAt(i)),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              SaveButton(
                label: existing == null ? 'Add Participant' : 'Save Changes',
                color: AppColors.income,
                onTap: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final data = FunctionParticipant(
                    id: existing?.id ?? '',
                    functionId: functionId,
                    name: name,
                    place: placeCtrl.text.trim().isEmpty ? null : placeCtrl.text.trim(),
                    relation: relationCtrl.text.trim().isEmpty ? null : relationCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    familyMembers: familyMembers.where((m) => m.name.isNotEmpty).toList(),
                  );
                  try {
                    if (existing == null) {
                      final row = await svc.addParticipant(data.toJson());
                      participants.insert(0, FunctionParticipant.fromJson(row));
                    } else {
                      await svc.updateParticipant(existing.id, {
                        ...data.toJson(),
                        'family_members': data.familyMembers.map((m) => m.toJson()).toList(),
                      });
                      final idx = participants.indexOf(existing);
                      if (idx >= 0) participants[idx] = FunctionParticipant.fromJson({...data.toJson(), 'id': existing.id, 'function_id': functionId});
                    }
                    onChanged();
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  } catch (e, stack) {
                    ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_save_participant');
                    if (sheetCtx.mounted) ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                },
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = this.isDark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final totalPeople = participants.fold(0, (s, p) => s + p.totalCount);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEdit(context),
        backgroundColor: AppColors.income,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
      ),
      body: participants.isEmpty
          ? const PlanEmptyState(emoji: '👥', title: 'No participants yet', subtitle: 'Add people you plan to invite')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.income.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text('👥', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$totalPeople total people', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: tc)),
                          Text('${participants.length} families / groups', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                        ],
                      ),
                    ],
                  ),
                ),
                ...participants.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SwipeTile(
                    onDelete: () async {
                      await FunctionsService.instance.deleteParticipant(p.id);
                      participants.remove(p);
                      onChanged();
                    },
                    child: GestureDetector(
                      onTap: () => _showAddEdit(context, existing: p),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('👤', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
                                      if (p.relation != null || p.place != null)
                                        Text(
                                          [if (p.relation != null) p.relation!, if (p.place != null) p.place!].join(' • '),
                                          style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
                                        ),
                                    ],
                                  ),
                                ),
                                if (p.phone != null)
                                  Icon(Icons.phone_rounded, size: 14, color: sub),
                                if (p.familyMembers.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.income.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('+${p.familyMembers.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: AppColors.income)),
                                  ),
                              ],
                            ),
                            if (p.familyMembers.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: p.familyMembers.map((m) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(8)),
                                  child: Text('${m.name} (${m.relation})', style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: sub)),
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
              ],
            ),
    );
  }
}

// ── Clothing gifts tab ────────────────────────────────────────────────────────

class _ClothingGiftsTab extends StatelessWidget {
  final String functionId;
  final List<ClothingFamily> families;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onChanged;

  const _ClothingGiftsTab({
    required this.functionId,
    required this.families,
    required this.isDark,
    required this.surfBg,
    required this.onChanged,
  });

  void _showAddFamily(BuildContext ctx, {ClothingFamily? existing}) {
    final nameCtrl = TextEditingController(text: existing?.familyName ?? '');
    final List<ClothingMember> members = existing?.members
        .map((m) => ClothingMember(name: m.name, gender: m.gender, dressType: m.dressType, size: m.size, brand: m.brand, budget: m.budget, purchased: m.purchased))
        .toList() ?? [];
    final svc = FunctionsService.instance;

    showPlanSheet(ctx, child: StatefulBuilder(builder: (sheetCtx, ss) {
      final sub = isDark ? AppColors.subDark : AppColors.subLight;
      final tc = isDark ? AppColors.textDark : AppColors.textLight;
      return Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              existing == null ? 'Add Family' : 'Edit Family',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito'),
            ),
            const SizedBox(height: 12),
            const SheetLabel(text: 'FAMILY NAME *'),
            PlanInputField(controller: nameCtrl, hint: 'e.g. Sharma Family, Uncle\'s Family'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('MEMBERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: sub, letterSpacing: 0.5)),
                GestureDetector(
                  onTap: () => ss(() => members.add(ClothingMember(name: '', gender: FunctionClothingGender.men))),
                  child: const Icon(Icons.add_circle_outline_rounded, size: 20, color: _funcColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (members.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Add members to assign clothing', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub)),
              ),
            ...members.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              final mNameCtrl = TextEditingController(text: m.name);
              final mDressCtrl = TextEditingController(text: m.dressType ?? '');
              final mSizeCtrl = TextEditingController(text: m.size ?? '');
              final mBrandCtrl = TextEditingController(text: m.brand ?? '');
              final mBudgetCtrl = TextEditingController(text: m.budget?.toString() ?? '');
              mNameCtrl.addListener(() => m.name = mNameCtrl.text);
              mDressCtrl.addListener(() => m.dressType = mDressCtrl.text.isEmpty ? null : mDressCtrl.text);
              mSizeCtrl.addListener(() => m.size = mSizeCtrl.text.isEmpty ? null : mSizeCtrl.text);
              mBrandCtrl.addListener(() => m.brand = mBrandCtrl.text.isEmpty ? null : mBrandCtrl.text);
              mBudgetCtrl.addListener(() => m.budget = double.tryParse(mBudgetCtrl.text));
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: mNameCtrl,
                            style: TextStyle(fontSize: 13, color: tc, fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                            decoration: InputDecoration.collapsed(hintText: 'Member name *', hintStyle: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito')),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.expense),
                          onPressed: () => ss(() => members.removeAt(i)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: FunctionClothingGender.values.map((g) => GestureDetector(
                          onTap: () => ss(() => m.gender = g),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: m.gender == g ? _funcColor.withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: m.gender == g ? _funcColor : sub.withValues(alpha: 0.3)),
                            ),
                            child: Text('${g.emoji} ${g.label}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: m.gender == g ? _funcColor : sub)),
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextField(controller: mDressCtrl, style: TextStyle(fontSize: 12, color: tc, fontFamily: 'Nunito'), decoration: InputDecoration.collapsed(hintText: 'Dress type (Saree, Shirt…)', hintStyle: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito')))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: mSizeCtrl, style: TextStyle(fontSize: 12, color: tc, fontFamily: 'Nunito'), decoration: InputDecoration.collapsed(hintText: 'Size (M, L, 38…)', hintStyle: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito')))),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: TextField(controller: mBrandCtrl, style: TextStyle(fontSize: 12, color: tc, fontFamily: 'Nunito'), decoration: InputDecoration.collapsed(hintText: 'Brand preference', hintStyle: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito')))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: mBudgetCtrl, keyboardType: TextInputType.number, style: TextStyle(fontSize: 12, color: tc, fontFamily: 'Nunito'), decoration: InputDecoration.collapsed(hintText: '${AppPrefs.cs} Budget', hintStyle: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito')))),
                    ]),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => ss(() => m.purchased = !m.purchased),
                      child: Row(children: [
                        Icon(m.purchased ? Icons.check_circle_rounded : Icons.circle_outlined, size: 16, color: m.purchased ? AppColors.income : sub),
                        const SizedBox(width: 6),
                        Text('Purchased', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: m.purchased ? AppColors.income : sub)),
                      ]),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            SaveButton(
              label: existing == null ? 'Add Family' : 'Save Changes',
              color: _funcColor,
              onTap: () async {
                final familyName = nameCtrl.text.trim();
                if (familyName.isEmpty) return;
                final cf = ClothingFamily(
                  id: existing?.id ?? '',
                  functionId: functionId,
                  familyName: familyName,
                  members: members.where((m) => m.name.isNotEmpty).toList(),
                );
                try {
                  if (existing == null) {
                    final row = await svc.addClothingFamily(cf.toJson());
                    families.insert(0, ClothingFamily.fromJson(row));
                  } else {
                    await svc.updateClothingFamily(existing.id, cf.toJson());
                    final idx = families.indexOf(existing);
                    if (idx >= 0) {
                      families[idx] = ClothingFamily(id: existing.id, functionId: functionId, familyName: familyName, members: cf.members);
                    }
                  }
                  onChanged();
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                } catch (e, stack) {
                  ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_save_planning_item');
                  if (sheetCtx.mounted) ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
            ),
          ],
        ),
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final totalBudget = families.fold(0.0, (s, f) => s + f.totalBudget);
    final totalMembers = families.fold(0, (s, f) => s + f.members.length);
    final totalPurchased = families.fold(0, (s, f) => s + f.purchasedCount);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFamily(context),
        backgroundColor: _funcColor,
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        label: const Text('Add Family', style: TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
      ),
      body: families.isEmpty
          ? const PlanEmptyState(emoji: '👗', title: 'No clothing planned', subtitle: 'Add families and assign clothing gifts')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: _funcColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _funcColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text('👗', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$totalMembers members across ${families.length} families', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
                            Text('$totalPurchased purchased • ${AppPrefs.cs}${totalBudget.toStringAsFixed(0)} total budget', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ...families.map((family) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: SwipeTile(
                    onDelete: () async {
                      await FunctionsService.instance.deleteClothingFamily(family.id);
                      families.remove(family);
                      onChanged();
                    },
                    child: GestureDetector(
                      onTap: () => _showAddFamily(context, existing: family),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(family.familyName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc))),
                                if (family.totalBudget > 0)
                                  Text('${AppPrefs.cs}${family.totalBudget.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: AppColors.income)),
                              ],
                            ),
                            if (family.members.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...family.members.map((m) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Text(m.gender.emoji, style: const TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(m.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: tc)),
                                          Text(
                                            [
                                              m.gender.label,
                                              if (m.dressType != null) m.dressType!,
                                              if (m.size != null) 'Size: ${m.size}',
                                              if (m.brand != null) m.brand!,
                                            ].join(' • '),
                                            style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: sub),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (m.budget != null)
                                      Text('${AppPrefs.cs}${m.budget!.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                                    const SizedBox(width: 6),
                                    Icon(
                                      m.purchased ? Icons.check_circle_rounded : Icons.circle_outlined,
                                      size: 16,
                                      color: m.purchased ? AppColors.income : sub,
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
              ],
            ),
    );
  }
}

// ── Bridal essentials tab ─────────────────────────────────────────────────────

class _BridalEssentialsTab extends StatelessWidget {
  final String functionId;
  final List<BridalEssential> essentials;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onChanged;

  const _BridalEssentialsTab({
    required this.functionId,
    required this.essentials,
    required this.isDark,
    required this.surfBg,
    required this.onChanged,
  });

  static const _categories = ['Dress', 'Makeup', 'Jewellery', 'Footwear', 'Hair', 'Mehendi', 'Photography', 'Other'];

  void _showAddEdit(BuildContext ctx, {BridalEssential? existing}) {
    final itemCtrl = TextEditingController(text: existing?.item ?? '');
    final detailsCtrl = TextEditingController(text: existing?.details ?? '');
    final vendorCtrl = TextEditingController(text: existing?.vendor ?? '');
    final costCtrl = TextEditingController(text: existing?.cost?.toString() ?? '');
    String? category = existing?.category ?? _categories[0];
    BridalStatus status = existing?.status ?? BridalStatus.pending;
    final svc = FunctionsService.instance;

    showPlanSheet(ctx, child: StatefulBuilder(builder: (sheetCtx, ss) {
      final sub = isDark ? AppColors.subDark : AppColors.subLight;
      return Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(existing == null ? 'Add Bridal Essential' : 'Edit Essential',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
            const SizedBox(height: 12),
            const SheetLabel(text: 'CATEGORY'),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _categories.map((c) => GestureDetector(
                  onTap: () => ss(() => category = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: category == c ? AppColors.lend.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: category == c ? AppColors.lend : sub.withValues(alpha: 0.3)),
                    ),
                    child: Text(c, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: category == c ? AppColors.lend : sub)),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 8),
            const SheetLabel(text: 'ITEM *'),
            PlanInputField(controller: itemCtrl, hint: 'e.g. Bridal lehenga, Foundation kit'),
            const SizedBox(height: 8),
            const SheetLabel(text: 'DETAILS'),
            PlanInputField(controller: detailsCtrl, hint: 'Color, style, notes…', maxLines: 2),
            const SizedBox(height: 8),
            const SheetLabel(text: 'VENDOR / SHOP'),
            PlanInputField(controller: vendorCtrl, hint: 'Vendor or shop name'),
            const SizedBox(height: 8),
            SheetLabel(text: 'COST (${AppPrefs.cs})'),
            PlanInputField(controller: costCtrl, hint: 'Estimated cost', inputType: TextInputType.number),
            const SizedBox(height: 12),
            const SheetLabel(text: 'STATUS'),
            Row(children: BridalStatus.values.map((s) => GestureDetector(
              onTap: () => ss(() => status = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: status == s ? AppColors.income.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: status == s ? AppColors.income : sub.withValues(alpha: 0.3)),
                ),
                child: Text('${s.emoji} ${s.label}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: status == s ? AppColors.income : sub)),
              ),
            )).toList()),
            const SizedBox(height: 8),
            SaveButton(
              label: existing == null ? 'Add Item' : 'Save Changes',
              color: AppColors.lend,
              onTap: () async {
                final item = itemCtrl.text.trim();
                if (item.isEmpty) return;
                final data = BridalEssential(
                  id: existing?.id ?? '',
                  functionId: functionId,
                  item: item,
                  category: category,
                  details: detailsCtrl.text.trim().isEmpty ? null : detailsCtrl.text.trim(),
                  vendor: vendorCtrl.text.trim().isEmpty ? null : vendorCtrl.text.trim(),
                  status: status,
                  cost: double.tryParse(costCtrl.text),
                );
                try {
                  if (existing == null) {
                    final row = await svc.addBridalEssential(data.toJson());
                    essentials.add(BridalEssential.fromJson(row));
                  } else {
                    await svc.updateBridalEssential(existing.id, data.toJson());
                    final idx = essentials.indexOf(existing);
                    if (idx >= 0) essentials[idx] = BridalEssential.fromJson({...data.toJson(), 'id': existing.id, 'function_id': functionId});
                  }
                  onChanged();
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                } catch (e, stack) {
                  ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_save_planning_item');
                  if (sheetCtx.mounted) ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
            ),
          ],
        ),
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final totalCost = essentials.fold(0.0, (s, e) => s + (e.cost ?? 0));
    final done = essentials.where((e) => e.status == BridalStatus.done).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEdit(context),
        backgroundColor: AppColors.lend,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Item', style: TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
      ),
      body: essentials.isEmpty
          ? const PlanEmptyState(emoji: '💍', title: 'No bridal essentials', subtitle: 'Track dresses, makeup, jewellery and more')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.lend.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.lend.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Text('💍', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${essentials.length} items • $done done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
                      Text('${AppPrefs.cs}${totalCost.toStringAsFixed(0)} estimated', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                    ])),
                  ]),
                ),
                ...essentials.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SwipeTile(
                    onDelete: () async {
                      await FunctionsService.instance.deleteBridalEssential(e.id);
                      essentials.remove(e);
                      onChanged();
                    },
                    child: GestureDetector(
                      onTap: () => _showAddEdit(context, existing: e),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.lend.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(e.status.emoji, style: const TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  if (e.category != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.lend.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                      child: Text(e.category!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: AppColors.lend)),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(child: Text(e.item, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc), overflow: TextOverflow.ellipsis)),
                                ]),
                                if (e.details != null)
                                  Text(e.details!, style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub), maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (e.vendor != null)
                                  Text('🏪 ${e.vendor}', style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: sub)),
                              ]),
                            ),
                            if (e.cost != null)
                              Text('${AppPrefs.cs}${e.cost!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: AppColors.income)),
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
              ],
            ),
    );
  }
}

// ── Return gifts tab ──────────────────────────────────────────────────────────

class _ReturnGiftsTab extends StatelessWidget {
  final String functionId;
  final List<FunctionReturnGift> gifts;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onChanged;

  const _ReturnGiftsTab({
    required this.functionId,
    required this.gifts,
    required this.isDark,
    required this.surfBg,
    required this.onChanged,
  });

  void _showAddEdit(BuildContext ctx, {FunctionReturnGift? existing}) {
    final nameCtrl = TextEditingController(text: existing?.giftName ?? '');
    final priceCtrl = TextEditingController(text: existing?.approxPrice?.toString() ?? '');
    final whereCtrl = TextEditingController(text: existing?.whereToBuy ?? '');
    final vendorCtrl = TextEditingController(text: existing?.vendor ?? '');
    final qtyCtrl = TextEditingController(text: existing?.quantity.toString() ?? '1');
    final svc = FunctionsService.instance;

    showPlanSheet(ctx, child: StatefulBuilder(builder: (sheetCtx, ss) {
      return Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(existing == null ? 'Add Return Gift' : 'Edit Return Gift',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
            const SizedBox(height: 12),
            const SheetLabel(text: 'GIFT NAME *'),
            PlanInputField(controller: nameCtrl, hint: 'e.g. Silk saree, Sweet box, Steel plate'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SheetLabel(text: 'APPROX PRICE (${AppPrefs.cs})'),
                PlanInputField(controller: priceCtrl, hint: '${AppPrefs.cs} per item', inputType: TextInputType.number),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SheetLabel(text: 'QUANTITY'),
                PlanInputField(controller: qtyCtrl, hint: 'How many', inputType: TextInputType.number),
              ])),
            ]),
            const SizedBox(height: 8),
            const SheetLabel(text: 'WHERE TO BUY'),
            PlanInputField(controller: whereCtrl, hint: 'Shop / Market / Online'),
            const SizedBox(height: 8),
            const SheetLabel(text: 'VENDOR'),
            PlanInputField(controller: vendorCtrl, hint: 'Vendor name / contact'),
            const SizedBox(height: 8),
            SaveButton(
              label: existing == null ? 'Add Gift' : 'Save Changes',
              color: _funcColor,
              onTap: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final data = FunctionReturnGift(
                  id: existing?.id ?? '',
                  functionId: functionId,
                  giftName: name,
                  approxPrice: double.tryParse(priceCtrl.text),
                  whereToBuy: whereCtrl.text.trim().isEmpty ? null : whereCtrl.text.trim(),
                  vendor: vendorCtrl.text.trim().isEmpty ? null : vendorCtrl.text.trim(),
                  quantity: int.tryParse(qtyCtrl.text) ?? 1,
                );
                try {
                  if (existing == null) {
                    final row = await svc.addReturnGift(data.toJson());
                    gifts.add(FunctionReturnGift.fromJson(row));
                  } else {
                    await svc.updateReturnGift(existing.id, data.toJson());
                    final idx = gifts.indexOf(existing);
                    if (idx >= 0) gifts[idx] = FunctionReturnGift.fromJson({...data.toJson(), 'id': existing.id, 'function_id': functionId});
                  }
                  onChanged();
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                } catch (e, stack) {
                  ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_save_planning_item');
                  if (sheetCtx.mounted) ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
            ),
          ],
        ),
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final totalCost = gifts.fold(0.0, (s, g) => s + g.totalCost);
    final totalQty = gifts.fold(0, (s, g) => s + g.quantity);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEdit(context),
        backgroundColor: _funcColor,
        icon: const Icon(Icons.card_giftcard_rounded, color: Colors.white),
        label: const Text('Add Gift', style: TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
      ),
      body: gifts.isEmpty
          ? const PlanEmptyState(emoji: '🎁', title: 'No return gifts planned', subtitle: 'Plan what gifts to give back to guests')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: _funcColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _funcColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Text('🎁', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${gifts.length} gift types • $totalQty total items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
                      Text('${AppPrefs.cs}${totalCost.toStringAsFixed(0)} estimated total', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                    ])),
                  ]),
                ),
                ...gifts.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SwipeTile(
                    onDelete: () async {
                      await FunctionsService.instance.deleteReturnGift(g.id);
                      gifts.remove(g);
                      onChanged();
                    },
                    child: GestureDetector(
                      onTap: () => _showAddEdit(context, existing: g),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                        child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: _funcColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            alignment: Alignment.center,
                            child: const Text('🎁', style: TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(g.giftName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
                            Text(
                              [
                                'Qty: ${g.quantity}',
                                if (g.whereToBuy != null) g.whereToBuy!,
                                if (g.vendor != null) g.vendor!,
                              ].join(' • '),
                              style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: sub),
                            ),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            if (g.approxPrice != null)
                              Text('${AppPrefs.cs}${g.approxPrice!.toStringAsFixed(0)}/item', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                            if (g.totalCost > 0)
                              Text('${AppPrefs.cs}${g.totalCost.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: AppColors.income)),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                )),
              ],
            ),
    );
  }
}
