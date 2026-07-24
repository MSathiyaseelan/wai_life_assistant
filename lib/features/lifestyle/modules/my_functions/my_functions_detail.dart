part of 'my_functions_screen.dart';

// ── Function detail ───────────────────────────────────────────────────────────

class _FunctionDetail extends StatefulWidget {
  final FunctionModel fn;
  final bool isDark;
  final VoidCallback onUpdate;
  final Map<String, String> familyWalletNames;
  final Map<String, String> allFamilyWalletNames;
  final String personalWalletId;
  final String currentWalletId;
  /// When true, loads and shows planning tabs (Participants, Clothing Gifts,
  /// Bridal Essentials, Return Gift) between Gifts and Vendors.
  final bool showPlanningTabs;
  const _FunctionDetail({
    required this.fn,
    required this.isDark,
    required this.onUpdate,
    this.familyWalletNames = const {},
    this.allFamilyWalletNames = const {},
    this.personalWalletId = '',
    this.currentWalletId = '',
    this.showPlanningTabs = false,
  });
  @override
  State<_FunctionDetail> createState() => _FunctionDetailState();
}

class _FunctionDetailState extends State<_FunctionDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Planning data — only loaded when showPlanningTabs == true
  final List<FunctionParticipant> _participants = [];
  final List<ClothingFamily> _clothingFamilies = [];
  final List<BridalEssential> _bridals = [];
  final List<FunctionReturnGift> _returnGifts = [];
  bool _planningLoading = false;

  @override
  void initState() {
    super.initState();
    final tabCount = widget.showPlanningTabs ? 10 : 6;
    _tab = TabController(length: tabCount, vsync: this);
    if (widget.showPlanningTabs) _loadPlanningData();
  }

  Future<void> _loadPlanningData() async {
    setState(() => _planningLoading = true);
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
        _participants..clear()..addAll(results[0].map(FunctionParticipant.fromJson));
        _clothingFamilies..clear()..addAll(results[1].map(ClothingFamily.fromJson));
        _bridals..clear()..addAll(results[2].map(BridalEssential.fromJson));
        _returnGifts..clear()..addAll(results[3].map(FunctionReturnGift.fromJson));
        _planningLoading = false;
      });
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'function_detail_planning_load');
      if (mounted) setState(() => _planningLoading = false);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
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
            onPressed: () => _showEditFunction(context, isDark, surfBg),
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
          indicatorColor: _funcColor,
          labelColor: _funcColor,
          unselectedLabelColor: sub,
          tabs: [
            const Tab(text: 'Info'),
            const Tab(text: 'Cash'),
            const Tab(text: 'Gold / Silver'),
            const Tab(text: 'Gifts'),
            if (widget.showPlanningTabs) ...[
              Tab(text: 'Participants (${_participants.length})'),
              const Tab(text: 'Clothing Gifts'),
              const Tab(text: 'Bridal Essentials'),
              Tab(text: 'Return Gift (${_returnGifts.length})'),
            ],
            const Tab(text: 'Vendors'),
            const Tab(text: 'Messages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // INFO
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _funcColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _funcColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    children: [
                      _InfoDetailRow(
                        label: 'Function Type',
                        value:
                            '${fn.type.emoji}  ${fn.type == FunctionType.other && fn.customType != null ? fn.customType! : fn.type.label}',
                        isDark: isDark,
                        tc: tc,
                        sub: sub,
                      ),
                      _InfoDetailRow(
                        label: 'Function Name',
                        value: fn.title,
                        isDark: isDark,
                        tc: tc,
                        sub: sub,
                      ),
                      if (fn.functionDate != null)
                        _InfoDetailRow(
                          label: 'Date',
                          value: fmtDate(fn.functionDate!),
                          isDark: isDark,
                          tc: tc,
                          sub: sub,
                        ),
                      if (fn.venue != null)
                        _InfoDetailRow(
                          label: 'Venue',
                          value: fn.venue!,
                          isDark: isDark,
                          tc: tc,
                          sub: sub,
                          isLast: fn.address == null && fn.notes == null,
                        ),
                      if (fn.address != null)
                        _InfoDetailRow(
                          label: 'Address',
                          value: fn.address!,
                          isDark: isDark,
                          tc: tc,
                          sub: sub,
                          isLast: fn.notes == null,
                        ),
                      if (fn.notes != null)
                        _InfoDetailRow(
                          label: 'Notes',
                          value: fn.notes!,
                          isDark: isDark,
                          tc: tc,
                          sub: sub,
                          isLast: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Summary stats
                Row(
                  children: [
                    _FuncStat(
                      label: 'Cash',
                      value: '${AppPrefs.cs}${fn.totalCash.toStringAsFixed(0)}',
                      emoji: '💵',
                      color: AppColors.income,
                    ),
                    const SizedBox(width: 10),
                    _FuncStat(
                      label: 'Gold',
                      value: '${fn.totalGold}g',
                      emoji: '🥇',
                      color: AppColors.lend,
                    ),
                    const SizedBox(width: 10),
                    _FuncStat(
                      label: 'Total Gifts',
                      value: '${fn.gifts.length}',
                      emoji: '🎁',
                      color: _funcColor,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // CASH (Moi)
          _MoiTab(fn: fn, isDark: isDark, onUpdate: () => setState(() {})),

          // GOLD / SILVER
          _FilteredGiftTab(
            gifts: fn.gifts
                .where(
                  (g) =>
                      g.giftType == GiftType.gold ||
                      g.giftType == GiftType.silver,
                )
                .toList(),
            isDark: isDark,
            label: 'Gold / Silver',
            emoji: '🥇',
            emptySubtitle: 'No gold or silver gifts recorded',
            summaryLabel: [
              if (fn.totalGold > 0) '${fn.totalGold}g gold',
              if (fn.totalSilver > 0) '${fn.totalSilver}g silver',
            ].join('  •  '),
            addLabel: 'Add Item',
            onAdd: () => _showAddGift(context, isDark, surfBg, fn),
            onEdit: (g) => _showEditGift(context, isDark, surfBg, g),
          ),

          // GIFTS
          _FilteredGiftTab(
            gifts: fn.gifts
                .where(
                  (g) =>
                      g.giftType != GiftType.gold &&
                      g.giftType != GiftType.silver,
                )
                .toList(),
            isDark: isDark,
            label: 'Gift Items',
            emoji: '🎁',
            emptySubtitle:
                'Tap Add Gift to record household, clothing and other items',
            summaryLabel: '',
            onAdd: () => _showAddGift(
              context,
              isDark,
              surfBg,
              fn,
              types: _giftItemTypes,
            ),
            onEdit: (g) => _showEditGift(
              context,
              isDark,
              surfBg,
              g,
              types: _giftItemTypes,
            ),
          ),

          // PLANNING TABS (only when showPlanningTabs == true)
          if (widget.showPlanningTabs) ...[
            _planningLoading
                ? const Center(child: CircularProgressIndicator(color: _funcColor))
                : _ParticipantsTab(
                    functionId: fn.id,
                    participants: _participants,
                    isDark: isDark,
                    surfBg: surfBg,
                    onChanged: () => setState(() {}),
                  ),
            _planningLoading
                ? const Center(child: CircularProgressIndicator(color: _funcColor))
                : _ClothingGiftsTab(
                    functionId: fn.id,
                    families: _clothingFamilies,
                    isDark: isDark,
                    surfBg: surfBg,
                    onChanged: () => setState(() {}),
                  ),
            _planningLoading
                ? const Center(child: CircularProgressIndicator(color: _funcColor))
                : _BridalEssentialsTab(
                    functionId: fn.id,
                    essentials: _bridals,
                    isDark: isDark,
                    surfBg: surfBg,
                    onChanged: () => setState(() {}),
                  ),
            _planningLoading
                ? const Center(child: CircularProgressIndicator(color: _funcColor))
                : _ReturnGiftsTab(
                    functionId: fn.id,
                    gifts: _returnGifts,
                    isDark: isDark,
                    surfBg: surfBg,
                    onChanged: () => setState(() {}),
                  ),
          ],

          // VENDORS
          _AllVendorsTab(
            fn: fn,
            isDark: isDark,
            onAdd: () => _showAddVendor(context, isDark, surfBg, fn),
            onEdit: (v) => _showEditVendor(context, isDark, surfBg, v),
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

  void _showAddVendor(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    FunctionModel fn,
  ) {
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
        builder: (sheetCtx, ss) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Vendor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 14),
              const SheetLabel(text: 'VENDOR NAME'),
              PlanInputField(
                controller: nameCtrl,
                hint: 'e.g. Sri Krishna Catering',
              ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? _funcColor.withValues(alpha: 0.15)
                              : surfBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? _funcColor : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          '${c.emoji} ${c.label}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: sel
                                ? _funcColor
                                : (isDark
                                      ? AppColors.subDark
                                      : AppColors.subLight),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'CONTACT'),
              PlanInputField(
                controller: phoneCtrl,
                hint: 'Phone number',
                inputType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              PlanInputField(
                controller: emailCtrl,
                hint: 'Email (optional)',
                inputType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              PlanInputField(
                controller: addressCtrl,
                hint: 'Address (optional)',
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'COST'),
              Row(
                children: [
                  Expanded(
                    child: PlanInputField(
                      controller: costCtrl,
                      hint: 'Total cost (${AppPrefs.cs})',
                      inputType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PlanInputField(
                      controller: advanceCtrl,
                      hint: 'Advance paid (${AppPrefs.cs})',
                      inputType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'EVENT LINKED'),
              PlanInputField(
                controller: eventCtrl,
                hint: 'e.g. Wedding, Housewarming',
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'NOTES'),
              PlanInputField(
                controller: notesCtrl,
                hint: 'Invoice details, notes…',
                maxLines: 3,
              ),
              SaveButton(
                label: 'Add Vendor',
                color: _funcColor,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(() {
                    fn.vendors.add(
                      FunctionVendor(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        category: category,
                        phone: phoneCtrl.text.trim().isEmpty
                            ? null
                            : phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim().isEmpty
                            ? null
                            : emailCtrl.text.trim(),
                        address: addressCtrl.text.trim().isEmpty
                            ? null
                            : addressCtrl.text.trim(),
                        totalCost: double.tryParse(costCtrl.text.trim()),
                        advancePaid: double.tryParse(advanceCtrl.text.trim()),
                        eventLinked: eventCtrl.text.trim().isEmpty
                            ? null
                            : eventCtrl.text.trim(),
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      ),
                    );
                  });
                  Navigator.pop(sheetCtx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditVendor(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    FunctionVendor v,
  ) {
    final nameCtrl = TextEditingController(text: v.name);
    final phoneCtrl = TextEditingController(text: v.phone ?? '');
    final emailCtrl = TextEditingController(text: v.email ?? '');
    final addressCtrl = TextEditingController(text: v.address ?? '');
    final costCtrl = TextEditingController(
      text: v.totalCost?.toStringAsFixed(0) ?? '',
    );
    final advanceCtrl = TextEditingController(
      text: v.advancePaid?.toStringAsFixed(0) ?? '',
    );
    final eventCtrl = TextEditingController(text: v.eventLinked ?? '');
    final notesCtrl = TextEditingController(text: v.notes ?? '');
    var category = v.category;
    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (sheetCtx, ss) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Vendor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 14),
              const SheetLabel(text: 'VENDOR NAME'),
              PlanInputField(controller: nameCtrl, hint: 'Vendor name'),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? _funcColor.withValues(alpha: 0.15)
                              : surfBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? _funcColor : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          '${c.emoji} ${c.label}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: sel
                                ? _funcColor
                                : (isDark
                                      ? AppColors.subDark
                                      : AppColors.subLight),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'CONTACT'),
              PlanInputField(
                controller: phoneCtrl,
                hint: 'Phone number',
                inputType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              PlanInputField(
                controller: emailCtrl,
                hint: 'Email (optional)',
                inputType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              PlanInputField(
                controller: addressCtrl,
                hint: 'Address (optional)',
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'COST'),
              Row(
                children: [
                  Expanded(
                    child: PlanInputField(
                      controller: costCtrl,
                      hint: 'Total cost (${AppPrefs.cs})',
                      inputType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PlanInputField(
                      controller: advanceCtrl,
                      hint: 'Advance paid (${AppPrefs.cs})',
                      inputType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'EVENT LINKED'),
              PlanInputField(
                controller: eventCtrl,
                hint: 'e.g. Wedding, Housewarming',
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'NOTES'),
              PlanInputField(
                controller: notesCtrl,
                hint: 'Invoice details, notes…',
                maxLines: 3,
              ),
              SaveButton(
                label: 'Save Changes',
                color: _funcColor,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(() {
                    v.name = nameCtrl.text.trim();
                    v.category = category;
                    v.phone = phoneCtrl.text.trim().isEmpty
                        ? null
                        : phoneCtrl.text.trim();
                    v.email = emailCtrl.text.trim().isEmpty
                        ? null
                        : emailCtrl.text.trim();
                    v.address = addressCtrl.text.trim().isEmpty
                        ? null
                        : addressCtrl.text.trim();
                    v.totalCost = double.tryParse(costCtrl.text.trim());
                    v.advancePaid = double.tryParse(advanceCtrl.text.trim());
                    v.eventLinked = eventCtrl.text.trim().isEmpty
                        ? null
                        : eventCtrl.text.trim();
                    v.notes = notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim();
                  });
                  Navigator.pop(sheetCtx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditFunction(BuildContext ctx, bool isDark, Color surfBg) {
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
                                  Icon(Icons.photo_library_rounded, size: 24, color: _funcColor),
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
                                  Icon(Icons.camera_alt_rounded, size: 24, color: _funcColor),
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
                                color: selected ? _funcColor.withValues(alpha: 0.15) : surfBg,
                                borderRadius: BorderRadius.circular(10),
                                border: selected ? Border.all(color: _funcColor, width: 1.5) : null,
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Function',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SheetLabel(text: 'GROUP ICON'),
              GestureDetector(
                onTap: pickIcon,
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: _funcColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _funcColor.withValues(alpha: 0.3)),
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
                  children: FunctionType.values
                      .map(
                        (t) => GestureDetector(
                          onTap: () => ss(() => type = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: type == t
                                  ? _funcColor.withValues(alpha: 0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: type == t
                                    ? _funcColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  t.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  t.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: type == t
                                        ? _funcColor
                                        : (isDark
                                              ? AppColors.subDark
                                              : AppColors.subLight),
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
              PlanInputField(controller: titleCtrl, hint: 'Function title *'),
              if (type == FunctionType.other) ...[
                const SizedBox(height: 8),
                PlanInputField(
                  controller: customTypeCtrl,
                  hint: 'Enter function type',
                ),
              ],
              const SizedBox(height: 8),
              PlanInputField(controller: venueCtrl, hint: 'Venue / Location'),
              const SizedBox(height: 8),
              PlanInputField(controller: notesCtrl, hint: 'Notes'),
              const SizedBox(height: 8),
              LifeDateTile(
                date: date,
                hint: 'Function date',
                color: _funcColor,
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
                          color: selectedWalletId == personalId ? _funcColor.withValues(alpha: 0.15) : surfBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selectedWalletId == personalId ? _funcColor : Colors.transparent),
                        ),
                        child: Text(
                          'Personal',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito',
                            color: selectedWalletId == personalId ? _funcColor : (isDark ? AppColors.subDark : AppColors.subLight),
                          ),
                        ),
                      ),
                    ),
                    ...allFamilyEntries.map((e) => GestureDetector(
                      onTap: () => ss(() => selectedWalletId = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selectedWalletId == e.key ? _funcColor.withValues(alpha: 0.15) : surfBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selectedWalletId == e.key ? _funcColor : Colors.transparent),
                        ),
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito',
                            color: selectedWalletId == e.key ? _funcColor : (isDark ? AppColors.subDark : AppColors.subLight),
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
              ],
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
                color: _funcColor,
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
                    fn.customType =
                        type == FunctionType.other &&
                            customTypeCtrl.text.trim().isNotEmpty
                        ? customTypeCtrl.text.trim()
                        : null;
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

  static const _goldSilverTypes = [GiftType.gold, GiftType.silver];
  static const _giftItemTypes = [
    GiftType.household,
    GiftType.clothing,
    GiftType.giftItem,
    GiftType.giftCard,
    GiftType.other,
  ];

  void _showAddGift(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    FunctionModel fn, {
    List<GiftType> types = _goldSilverTypes,
  }) {
    final nameCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var giftType = types.first;
    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Item',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SheetLabel(text: 'GIFT TYPE'),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: types
                      .map(
                        (t) => GestureDetector(
                          onTap: () => ss(() => giftType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: giftType == t
                                  ? _funcColor.withValues(alpha: 0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: giftType == t
                                    ? _funcColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  t.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  t.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: giftType == t
                                        ? _funcColor
                                        : (isDark
                                              ? AppColors.subDark
                                              : AppColors.subLight),
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
              PlanInputField(controller: nameCtrl, hint: 'Guest name *'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PlanInputField(controller: placeCtrl, hint: 'Place'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PlanInputField(
                      controller: relationCtrl,
                      hint: 'Relation',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PlanInputField(
                controller: amtCtrl,
                hint: giftType == GiftType.gold
                    ? 'Gold grams *'
                    : giftType == GiftType.silver
                    ? 'Silver grams *'
                    : giftType == GiftType.giftCard
                    ? 'Card value'
                    : 'Description',
                inputType:
                    (giftType == GiftType.gold || giftType == GiftType.silver)
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
              ),
              const SizedBox(height: 8),
              PlanInputField(controller: notesCtrl, hint: 'Notes'),
              SaveButton(
                label: 'Add Item',
                color: _funcColor,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final num = double.tryParse(amtCtrl.text.trim());
                  setState(
                    () => fn.gifts.add(
                      GiftEntry(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        guestName: nameCtrl.text.trim(),
                        giftType: giftType,
                        guestPlace: placeCtrl.text.trim().isEmpty
                            ? null
                            : placeCtrl.text.trim(),
                        relation: relationCtrl.text.trim().isEmpty
                            ? null
                            : relationCtrl.text.trim(),
                        goldGrams: giftType == GiftType.gold ? num : null,
                        silverGrams: giftType == GiftType.silver ? num : null,
                        giftCardValue: giftType == GiftType.giftCard
                            ? amtCtrl.text.trim().isEmpty
                                  ? null
                                  : amtCtrl.text.trim()
                            : null,
                        itemDescription:
                            (giftType == GiftType.other ||
                                giftType == GiftType.household ||
                                giftType == GiftType.clothing ||
                                giftType == GiftType.giftItem)
                            ? amtCtrl.text.trim().isEmpty
                                  ? null
                                  : amtCtrl.text.trim()
                            : null,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      ),
                    ),
                  );
                  widget.onUpdate();
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditGift(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    GiftEntry gift, {
    List<GiftType> types = _goldSilverTypes,
  }) {
    final nameCtrl = TextEditingController(text: gift.guestName);
    final placeCtrl = TextEditingController(text: gift.guestPlace ?? '');
    final relationCtrl = TextEditingController(text: gift.relation ?? '');
    final notesCtrl = TextEditingController(text: gift.notes ?? '');
    final amtCtrl = TextEditingController(
      text:
          gift.goldGrams?.toStringAsFixed(1) ??
          gift.silverGrams?.toStringAsFixed(1) ??
          gift.giftCardValue ??
          gift.itemDescription ??
          '',
    );
    var giftType = gift.giftType;
    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Item',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SheetLabel(text: 'GIFT TYPE'),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: types
                      .map(
                        (t) => GestureDetector(
                          onTap: () => ss(() => giftType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: giftType == t
                                  ? _funcColor.withValues(alpha: 0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: giftType == t
                                    ? _funcColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  t.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  t.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: giftType == t
                                        ? _funcColor
                                        : (isDark
                                              ? AppColors.subDark
                                              : AppColors.subLight),
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
              PlanInputField(controller: nameCtrl, hint: 'Guest name *'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PlanInputField(controller: placeCtrl, hint: 'Place'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PlanInputField(
                      controller: relationCtrl,
                      hint: 'Relation',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PlanInputField(
                controller: amtCtrl,
                hint: giftType == GiftType.gold
                    ? 'Gold grams'
                    : giftType == GiftType.silver
                    ? 'Silver grams'
                    : giftType == GiftType.giftCard
                    ? 'Card value'
                    : 'Description',
                inputType:
                    (giftType == GiftType.gold || giftType == GiftType.silver)
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
              ),
              const SizedBox(height: 8),
              PlanInputField(controller: notesCtrl, hint: 'Notes'),
              SaveButton(
                label: 'Save Changes',
                color: _funcColor,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final num = double.tryParse(amtCtrl.text.trim());
                  setState(() {
                    gift.guestName = nameCtrl.text.trim();
                    gift.giftType = giftType;
                    gift.guestPlace = placeCtrl.text.trim().isEmpty
                        ? null
                        : placeCtrl.text.trim();
                    gift.relation = relationCtrl.text.trim().isEmpty
                        ? null
                        : relationCtrl.text.trim();
                    gift.goldGrams = giftType == GiftType.gold ? num : null;
                    gift.silverGrams = giftType == GiftType.silver ? num : null;
                    gift.giftCardValue = giftType == GiftType.giftCard
                        ? amtCtrl.text.trim().isEmpty
                              ? null
                              : amtCtrl.text.trim()
                        : null;
                    gift.itemDescription =
                        (giftType == GiftType.other ||
                            giftType == GiftType.household ||
                            giftType == GiftType.clothing ||
                            giftType == GiftType.giftItem)
                        ? amtCtrl.text.trim().isEmpty
                              ? null
                              : amtCtrl.text.trim()
                        : null;
                    gift.notes = notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim();
                  });
                  widget.onUpdate();
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FuncStat extends StatelessWidget {
  final String label, value, emoji;
  final Color color;
  const _FuncStat({
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              fontFamily: 'DM Mono',
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, fontFamily: 'Nunito', color: color),
          ),
        ],
      ),
    ),
  );
}

class _GiftEntryCard extends StatelessWidget {
  final GiftEntry gift;
  final bool isDark;
  final VoidCallback? onEdit;
  const _GiftEntryCard({required this.gift, required this.isDark, this.onEdit});
  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _funcColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _funcColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                gift.giftType.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gift.guestName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                  Row(
                    children: [
                      if (gift.guestPlace != null) ...[
                        Icon(Icons.location_on_rounded, size: 11, color: sub),
                        const SizedBox(width: 3),
                        Text(
                          gift.guestPlace!,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (gift.relation != null)
                        LifeBadge(text: gift.relation!, color: _funcColor),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  gift.summary,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'DM Mono',
                    color: gift.giftType == GiftType.silver
                        ? AppColors.subDark
                        : AppColors.lend,
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

class _FilteredGiftTab extends StatelessWidget {
  final List<GiftEntry> gifts;
  final bool isDark;
  final String label;
  final String emoji;
  final String emptySubtitle;
  final String summaryLabel;
  final String addLabel;
  final VoidCallback onAdd;
  final void Function(GiftEntry) onEdit;

  const _FilteredGiftTab({
    required this.gifts,
    required this.isDark,
    required this.label,
    required this.emoji,
    required this.emptySubtitle,
    required this.summaryLabel,
    this.addLabel = 'Add Gift',
    required this.onAdd,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    return Column(
      children: [
        Container(
          color: cardBg,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                  if (summaryLabel.isNotEmpty)
                    Text(
                      summaryLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'Nunito',
                        color: AppColors.income,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _funcColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        addLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: gifts.isEmpty
              ? PlanEmptyState(
                  emoji: emoji,
                  title: 'No gifts recorded',
                  subtitle: emptySubtitle,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: gifts.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GiftEntryCard(
                      gift: gifts[i],
                      isDark: isDark,
                      onEdit: () => onEdit(gifts[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AllVendorsTab extends StatelessWidget {
  final FunctionModel fn;
  final bool isDark;
  final VoidCallback onAdd;
  final void Function(FunctionVendor) onEdit;
  final void Function(FunctionVendor) onDelete;
  const _AllVendorsTab({
    required this.fn,
    required this.isDark,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = this.isDark;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);

    if (fn.vendors.isEmpty) {
      return PlanEmptyState(
        emoji: '🤝',
        title: 'No vendors yet',
        subtitle:
            'Tap + Add Vendor to record catering, venue, decoration and more',
        buttonLabel: '+ Add Vendor',
        onButton: onAdd,
      );
    }

    // Group by category
    final grouped = <VendorCategory, List<FunctionVendor>>{};
    for (final v in fn.vendors) {
      grouped.putIfAbsent(v.category, () => []).add(v);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Summary row
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _VendorStat(
                label: 'Vendors',
                value: '${fn.vendors.length}',
                color: _funcColor,
                isDark: isDark,
              ),
              _VendorStat(
                label: 'Total Cost',
                value:
                    '${AppPrefs.cs}${fn.vendors.fold(0.0, (s, v) => s + (v.totalCost ?? 0)).toStringAsFixed(0)}',
                color: AppColors.expense,
                isDark: isDark,
              ),
              _VendorStat(
                label: 'Balance Due',
                value:
                    '${AppPrefs.cs}${fn.vendors.fold(0.0, (s, v) => s + v.balance).toStringAsFixed(0)}',
                color: AppColors.lend,
                isDark: isDark,
              ),
            ],
          ),
        ),
        // Add button
        GestureDetector(
          onTap: onAdd,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _funcColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _funcColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: _funcColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Add Vendor',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: _funcColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Category sections
        ...grouped.entries.map(
          (e) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Row(
                  children: [
                    Text(e.key.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      e.key.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: sub,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              ...e.value.map(
                (v) => SwipeTile(
                  onDelete: () => onDelete(v),
                  child: GestureDetector(
                    onTap: () => onEdit(v),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  v.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                    color: tc,
                                  ),
                                ),
                              ),
                              if (v.totalCost != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.expense.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${AppPrefs.cs}${v.totalCost!.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Nunito',
                                      color: AppColors.expense,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (v.phone != null || v.email != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (v.phone != null) ...[
                                  Icon(
                                    Icons.phone_rounded,
                                    size: 12,
                                    color: sub,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    v.phone!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (v.email != null) ...[
                                  Icon(
                                    Icons.email_rounded,
                                    size: 12,
                                    color: sub,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      v.email!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Nunito',
                                        color: sub,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          if (v.totalCost != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _CostChip(
                                  label: 'Advance',
                                  value: v.advancePaid ?? 0,
                                  color: AppColors.income,
                                ),
                                const SizedBox(width: 8),
                                _CostChip(
                                  label: 'Balance',
                                  value: v.balance,
                                  color: v.balance > 0
                                      ? AppColors.lend
                                      : AppColors.income,
                                ),
                              ],
                            ),
                          ],
                          if (v.eventLinked != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.event_rounded, size: 12, color: sub),
                                const SizedBox(width: 4),
                                Text(
                                  v.eventLinked!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Nunito',
                                    color: sub,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (v.notes != null && v.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.notes_rounded, size: 12, color: sub),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    v.notes!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}

class _VendorStat extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark;
  const _VendorStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
        ),
      ],
    );
  }
}

class _CostChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _CostChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$label: ${AppPrefs.cs}${value.toStringAsFixed(0)}',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        fontFamily: 'Nunito',
        color: color,
      ),
    ),
  );
}
