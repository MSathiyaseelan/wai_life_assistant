import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import '../../widgets/life_widgets.dart';

const _funcColor = Color(0xFF6C63FF);

class MyFunctionsScreen extends StatefulWidget {
  final String walletId;
  const MyFunctionsScreen({super.key, required this.walletId});
  @override
  State<MyFunctionsScreen> createState() => _MyFunctionsScreenState();
}

class _MyFunctionsScreenState extends State<MyFunctionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final List<FunctionModel> _functions = List.from(mockFunctions);
  final List<GiftedItem> _gifted = List.from(mockGifted);
  final List<UpcomingFunction> _upcoming = List.from(mockUpcoming);

  List<FunctionModel> get _myFuncs =>
      _functions.where((f) => f.walletId == widget.walletId).toList();
  List<GiftedItem> get _myGifted =>
      _gifted.where((g) => g.walletId == widget.walletId).toList();
  List<UpcomingFunction> get _myUpcoming =>
      _upcoming.where((u) => u.walletId == widget.walletId).toList();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('🎊', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'My Functions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          dividerColor: Colors.transparent,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            fontSize: 11,
          ),
          indicatorColor: _funcColor,
          labelColor: _funcColor,
          unselectedLabelColor: sub,
          tabs: const [
            Tab(text: 'My Functions'),
            Tab(text: 'Gifts Received'),
            Tab(text: 'Gifted'),
            Tab(text: 'Upcoming'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAdd(context, isDark, surfBg),
        backgroundColor: _funcColor,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // MY FUNCTIONS tab
          _myFuncs.isEmpty
              ? const LifeEmptyState(
                  emoji: '🎊',
                  title: 'No functions yet',
                  subtitle: 'Record your family celebrations',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _myFuncs.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _FunctionCard(
                      fn: _myFuncs[i],
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _FunctionDetail(
                            fn: _myFuncs[i],
                            isDark: isDark,
                            onUpdate: () => setState(() {}),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

          // GIFTS RECEIVED
          _GiftsReceivedTab(functions: _myFuncs, isDark: isDark),

          // GIFTED tab
          _myGifted.isEmpty
              ? const LifeEmptyState(
                  emoji: '🎁',
                  title: 'No gifted items recorded',
                  subtitle: 'Track what you\'ve given at others\' functions',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _myGifted.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GiftedCard(item: _myGifted[i], isDark: isDark),
                  ),
                ),

          // UPCOMING tab
          _myUpcoming.isEmpty
              ? const LifeEmptyState(
                  emoji: '📅',
                  title: 'No upcoming functions',
                  subtitle: 'Plan for functions you\'re attending',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _myUpcoming.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _UpcomingCard(
                      item: _myUpcoming[i],
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _UpcomingDetail(
                            item: _myUpcoming[i],
                            isDark: isDark,
                            onUpdate: () => setState(() {}),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  void _showAdd(BuildContext ctx, bool isDark, Color surfBg) {
    final titleCtrl = TextEditingController();
    final whoCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    DateTime? date;
    var type = FunctionType.wedding;
    final tabIdx = _tab.index;
    showLifeSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tabIdx == 0
                    ? 'Add Function'
                    : tabIdx == 2
                    ? 'Record Gift Given'
                    : 'Add Upcoming',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const LifeLabel(text: 'FUNCTION TYPE'),
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
                                  ? _funcColor.withOpacity(0.15)
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
              LifeInput(controller: titleCtrl, hint: 'Function title *'),
              const SizedBox(height: 8),
              LifeInput(
                controller: whoCtrl,
                hint: 'Whose function? (e.g. Arjun\'s)',
              ),
              const SizedBox(height: 8),
              LifeInput(controller: venueCtrl, hint: 'Venue / Location'),
              const SizedBox(height: 8),
              LifeDateTile(
                date: date,
                hint: 'Function date',
                color: _funcColor,
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) ss(() => date = d);
                },
              ),
              LifeSaveButton(
                label: 'Save',
                color: _funcColor,
                onTap: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  if (tabIdx == 0) {
                    setState(
                      () => _functions.add(
                        FunctionModel(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          walletId: widget.walletId,
                          type: type,
                          title: titleCtrl.text.trim(),
                          whoFunction: whoCtrl.text.trim().isEmpty
                              ? 'Family'
                              : whoCtrl.text.trim(),
                          functionDate: date,
                          venue: venueCtrl.text.trim().isEmpty
                              ? null
                              : venueCtrl.text.trim(),
                        ),
                      ),
                    );
                  } else if (tabIdx == 3) {
                    setState(
                      () => _upcoming.add(
                        UpcomingFunction(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          walletId: widget.walletId,
                          memberId: 'me',
                          type: type,
                          personName: whoCtrl.text.trim().isEmpty
                              ? 'Unknown'
                              : whoCtrl.text.trim(),
                          functionTitle: titleCtrl.text.trim(),
                          date: date,
                          venue: venueCtrl.text.trim().isEmpty
                              ? null
                              : venueCtrl.text.trim(),
                        ),
                      ),
                    );
                  }
                  Navigator.pop(ctx);
                },
              ),
              //),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Function card ─────────────────────────────────────────────────────────────
class _FunctionCard extends StatelessWidget {
  final FunctionModel fn;
  final bool isDark;
  final VoidCallback onTap;
  const _FunctionCard({
    required this.fn,
    required this.isDark,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    const _months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _funcColor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_funcColor, Color(0xFF9C27B0)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Text(fn.type.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fn.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        Text(
                          fn.whoFunction,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (fn.functionDate != null)
                    Text(
                      '${fn.functionDate!.day} ${_months[fn.functionDate!.month]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (fn.venue != null)
                    Expanded(
                      child: LifeInfoRow(
                        icon: Icons.location_on_rounded,
                        label: fn.venue!,
                      ),
                    ),
                  Text(
                    '${fn.gifts.length} gifts  •  ₹${fn.totalCash.toStringAsFixed(0)} cash',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Function detail ───────────────────────────────────────────────────────────
class _FunctionDetail extends StatefulWidget {
  final FunctionModel fn;
  final bool isDark;
  final VoidCallback onUpdate;
  const _FunctionDetail({
    required this.fn,
    required this.isDark,
    required this.onUpdate,
  });
  @override
  State<_FunctionDetail> createState() => _FunctionDetailState();
}

class _FunctionDetailState extends State<_FunctionDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
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
        bottom: TabBar(
          controller: _tab,
          dividerColor: Colors.transparent,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            fontSize: 11,
          ),
          indicatorColor: _funcColor,
          labelColor: _funcColor,
          unselectedLabelColor: sub,
          tabs: const [
            Tab(text: 'Info'),
            Tab(text: '🎁 Gifts'),
            Tab(text: '🍽️ Catering'),
            Tab(text: '🎪 Vendors'),
            Tab(text: '💬 Chat'),
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_funcColor, Color(0xFF9C27B0)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(fn.type.emoji, style: const TextStyle(fontSize: 36)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fn.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Nunito',
                              ),
                            ),
                            Text(
                              fn.type.label,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'Nunito',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (fn.whoFunction.isNotEmpty)
                  LifeInfoRow(
                    icon: Icons.person_rounded,
                    label: 'Who: ${fn.whoFunction}',
                  ),
                if (fn.functionDate != null)
                  LifeInfoRow(
                    icon: Icons.calendar_today_rounded,
                    label:
                        'Date: ${fn.functionDate!.day}/${fn.functionDate!.month}/${fn.functionDate!.year}',
                  ),
                if (fn.venue != null)
                  LifeInfoRow(
                    icon: Icons.location_on_rounded,
                    label: 'Venue: ${fn.venue!}',
                  ),
                if (fn.address != null)
                  LifeInfoRow(icon: Icons.map_rounded, label: fn.address!),
                const SizedBox(height: 16),
                // Summary stats
                Row(
                  children: [
                    _FuncStat(
                      label: 'Total Gifts',
                      value: '${fn.gifts.length}',
                      emoji: '🎁',
                      color: _funcColor,
                    ),
                    const SizedBox(width: 10),
                    _FuncStat(
                      label: 'Cash',
                      value: '₹${fn.totalCash.toStringAsFixed(0)}',
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
                  ],
                ),
              ],
            ),
          ),

          // GIFTS LIST
          Column(
            children: [
              Container(
                color: cardBg,
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${fn.gifts.length} gifts received',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    Row(
                      children: [
                        const Text('💵 ', style: TextStyle(fontSize: 12)),
                        Text(
                          '₹${fn.totalCash.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'DM Mono',
                            color: AppColors.income,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('🥇 ', style: TextStyle(fontSize: 12)),
                        Text(
                          '${fn.totalGold}g',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'DM Mono',
                            color: AppColors.lend,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: fn.gifts.isEmpty
                    ? const LifeEmptyState(
                        emoji: '🎁',
                        title: 'No gifts recorded',
                        subtitle: 'Record gifts received at this function',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: fn.gifts.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _GiftEntryCard(
                            gift: fn.gifts[i],
                            isDark: isDark,
                          ),
                        ),
                      ),
              ),
            ],
          ),

          // CATERING
          _VendorTab(
            title: '🍽️ Catering',
            quotes: fn.catering,
            isDark: isDark,
            color: AppColors.income,
            onAdd: () => _addQuote(context, fn.catering, 'Add Caterer', isDark),
            onToggle: (q) => setState(() => q.approved = !q.approved),
          ),

          // VENDORS (all)
          _AllVendorsTab(
            fn: fn,
            isDark: isDark,
            onAdd: () {},
            onToggle: (q) => setState(() => q.approved = !q.approved),
          ),

          // CHAT
          Expanded(
            child: ChatWidget(
              messages: fn.chat,
              isDark: isDark,
              textOf: (m) => (m as FunctionChatMessage).text,
              senderOf: (m) => (m as FunctionChatMessage).senderId,
              onSend: (text) => setState(
                () => fn.chat.add(
                  FunctionChatMessage(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    senderId: 'me',
                    text: text,
                    at: DateTime.now(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addQuote(
    BuildContext ctx,
    List<ServiceQuote> list,
    String title,
    bool isDark,
  ) {
    final vendorCtrl = TextEditingController();
    final serviceCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    showLifeSheet(
      ctx,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 12),
            LifeInput(controller: vendorCtrl, hint: 'Vendor name *'),
            const SizedBox(height: 8),
            LifeInput(controller: serviceCtrl, hint: 'Service description'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LifeInput(controller: phoneCtrl, hint: 'Phone'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LifeInput(
                    controller: amtCtrl,
                    hint: 'Quoted amount (₹)',
                    inputType: TextInputType.number,
                  ),
                ),
              ],
            ),
            LifeSaveButton(
              label: 'Add Quote',
              color: _funcColor,
              onTap: () {
                if (vendorCtrl.text.trim().isEmpty) return;
                setState(
                  () => list.add(
                    ServiceQuote(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      vendor: vendorCtrl.text.trim(),
                      service: serviceCtrl.text.trim().isEmpty
                          ? 'Services'
                          : serviceCtrl.text.trim(),
                      quotedAmount: double.tryParse(amtCtrl.text.trim()) ?? 0,
                      phone: phoneCtrl.text.trim().isEmpty
                          ? null
                          : phoneCtrl.text.trim(),
                    ),
                  ),
                );
                Navigator.pop(ctx);
              },
            ),
          ],
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
  const _GiftEntryCard({required this.gift, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Container(
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
          Text(
            gift.summary,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'DM Mono',
              color: gift.giftType == GiftType.cash
                  ? AppColors.income
                  : AppColors.lend,
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorTab extends StatelessWidget {
  final String title;
  final List<ServiceQuote> quotes;
  final bool isDark;
  final Color color;
  final VoidCallback onAdd;
  final void Function(ServiceQuote) onToggle;
  const _VendorTab({
    required this.title,
    required this.quotes,
    required this.isDark,
    required this.color,
    required this.onAdd,
    required this.onToggle,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: onAdd,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text(
            'Add Quote for $title',
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      Expanded(
        child: quotes.isEmpty
            ? LifeEmptyState(
                emoji: '📝',
                title: 'No quotes yet',
                subtitle: 'Add vendor quotes to compare',
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: quotes.length,
                itemBuilder: (_, i) => QuoteCard(
                  vendor: quotes[i].vendor,
                  service: quotes[i].service,
                  phone: quotes[i].phone ?? '',
                  amount: quotes[i].quotedAmount,
                  approved: quotes[i].approved,
                  color: color,
                  onToggle: () => onToggle(quotes[i]),
                ),
              ),
      ),
    ],
  );
}

class _AllVendorsTab extends StatelessWidget {
  final FunctionModel fn;
  final bool isDark;
  final VoidCallback onAdd;
  final void Function(ServiceQuote) onToggle;
  const _AllVendorsTab({
    required this.fn,
    required this.isDark,
    required this.onAdd,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = this.isDark;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sections = [
      ('🍽️ Catering', fn.catering, AppColors.income),
      ('🎪 Stage Decor', fn.decoration, AppColors.primary),
      ('🎁 Return Gifts', fn.returnGifts, AppColors.lend),
      ('🏛️ Marriage Hall', fn.hall, const Color(0xFF9C27B0)),
      ('📸 Photography', fn.photography, AppColors.expense),
      ('✨ Other Vendors', fn.otherVendors, AppColors.subLight),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: sections.map((s) {
        if (s.$2.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.$1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
            const SizedBox(height: 8),
            ...s.$2.map(
              (q) => QuoteCard(
                vendor: q.vendor,
                service: q.service,
                phone: q.phone ?? '',
                amount: q.quotedAmount,
                approved: q.approved,
                color: s.$3,
                onToggle: () => onToggle(q),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }
}

// ── Gifts Received tab ────────────────────────────────────────────────────────
class _GiftsReceivedTab extends StatelessWidget {
  final List<FunctionModel> functions;
  final bool isDark;
  const _GiftsReceivedTab({required this.functions, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final allGifts = functions
        .expand((f) => f.gifts.map((g) => (g, f.title)))
        .toList();
    if (allGifts.isEmpty) {
      return const LifeEmptyState(
        emoji: '🎁',
        title: 'No gifts yet',
        subtitle: 'Gifts from all functions appear here',
      );
    }
    final totalCash = functions.fold(0.0, (s, f) => s + f.totalCash);
    final isDark = this.isDark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    return Column(
      children: [
        Container(
          color: cardBg,
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _FuncStat(
                label: 'Total Gifts',
                value: '${allGifts.length}',
                emoji: '🎁',
                color: _funcColor,
              ),
              const SizedBox(width: 10),
              _FuncStat(
                label: 'Total Cash',
                value: '₹${totalCash.toStringAsFixed(0)}',
                emoji: '💵',
                color: AppColors.income,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            itemCount: allGifts.length,
            itemBuilder: (_, i) {
              final (g, fname) = allGifts[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (i == 0 || allGifts[i - 1].$2 != fname)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          fname,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: _funcColor,
                          ),
                        ),
                      ),
                    _GiftEntryCard(gift: g, isDark: isDark),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Gifted card ───────────────────────────────────────────────────────────────
class _GiftedCard extends StatelessWidget {
  final GiftedItem item;
  final bool isDark;
  const _GiftedCard({required this.item, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.income.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.income.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              item.giftType.emoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.toName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                Text(
                  '${item.functionTitle}  ${item.functionType.emoji}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                ),
                if (item.functionDate != null)
                  Text(
                    '${item.functionDate!.day}/${item.functionDate!.month}/${item.functionDate!.year}',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                if (item.isReturnGift)
                  LifeBadge(text: 'Return Gift', color: AppColors.lend),
              ],
            ),
          ),
          Text(
            item.giftSummary,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'DM Mono',
              color: AppColors.income,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Upcoming card ─────────────────────────────────────────────────────────────
class _UpcomingCard extends StatelessWidget {
  final UpcomingFunction item;
  final bool isDark;
  final VoidCallback onTap;
  const _UpcomingCard({
    required this.item,
    required this.isDark,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    const _months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final daysLeft = item.date != null
        ? item.date!.difference(DateTime.now()).inDays
        : null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.lend.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.lend, AppColors.lend.withOpacity(0.7)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Text(item.type.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.personName}\'s ${item.functionTitle}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        if (item.date != null)
                          Text(
                            '📅 ${item.date!.day} ${_months[item.date!.month]} ${item.date!.year}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'Nunito',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (daysLeft != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'in ${daysLeft}d',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (item.venue != null)
                    Expanded(
                      child: LifeInfoRow(
                        icon: Icons.location_on_rounded,
                        label: item.venue!,
                      ),
                    ),
                  if (item.plannedGift != null)
                    LifeBadge(
                      text: '🎁 ${item.plannedGift!}',
                      color: AppColors.income,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upcoming detail ───────────────────────────────────────────────────────────
class _UpcomingDetail extends StatefulWidget {
  final UpcomingFunction item;
  final bool isDark;
  final VoidCallback onUpdate;
  const _UpcomingDetail({
    required this.item,
    required this.isDark,
    required this.onUpdate,
  });
  @override
  State<_UpcomingDetail> createState() => _UpcomingDetailState();
}

class _UpcomingDetailState extends State<_UpcomingDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
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
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final item = widget.item;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          '${item.personName}\'s ${item.functionTitle}',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
          ),
        ),
        bottom: TabBar(
          controller: _tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            fontSize: 11,
          ),
          indicatorColor: AppColors.lend,
          labelColor: AppColors.lend,
          unselectedLabelColor: sub,
          tabs: const [
            Tab(text: 'Info & Planning'),
            Tab(text: '💬 Discuss'),
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
                LifeInfoRow(
                  icon: Icons.person_rounded,
                  label: 'Person: ${item.personName}',
                ),
                LifeInfoRow(
                  icon: Icons.celebration_rounded,
                  label: 'Event: ${item.functionTitle}',
                ),
                if (item.date != null)
                  LifeInfoRow(
                    icon: Icons.calendar_today_rounded,
                    label:
                        'Date: ${item.date!.day}/${item.date!.month}/${item.date!.year}',
                  ),
                if (item.venue != null)
                  LifeInfoRow(
                    icon: Icons.location_on_rounded,
                    label: item.venue!,
                  ),
                const SizedBox(height: 16),
                if (item.plannedGift != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.income.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.income.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('🎁', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Planned Gift',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Nunito',
                                  color: AppColors.income,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                item.plannedGift!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // CHAT
          ChatWidget(
            messages: item.chat,
            isDark: isDark,
            textOf: (m) => (m as FunctionChatMessage).text,
            senderOf: (m) => (m as FunctionChatMessage).senderId,
            onSend: (text) => setState(
              () => item.chat.add(
                FunctionChatMessage(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  senderId: 'me',
                  text: text,
                  at: DateTime.now(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
