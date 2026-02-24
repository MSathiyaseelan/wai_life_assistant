import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import '../../widgets/life_widgets.dart';

const _houseColor = Color(0xFF00C897);

class AroundTheHouseScreen extends StatefulWidget {
  final String walletId;
  const AroundTheHouseScreen({super.key, required this.walletId});
  @override
  State<AroundTheHouseScreen> createState() => _AroundTheHouseScreenState();
}

class _AroundTheHouseScreenState extends State<AroundTheHouseScreen> {
  final List<Appliance> _appliances = List.from(mockAppliances);
  ApplianceRoom? _filter;

  List<Appliance> get _base =>
      _appliances.where((a) => a.walletId == widget.walletId).toList();
  List<Appliance> get _filtered =>
      _filter == null ? _base : _base.where((a) => a.room == _filter).toList();

  Map<ApplianceRoom, List<Appliance>> get _byRoom {
    final m = <ApplianceRoom, List<Appliance>>{};
    for (final a in _base) {
      m.putIfAbsent(a.room, () => []).add(a);
    }
    return m;
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
            Text('🏠', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Around the House',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAdd(context, isDark, surfBg),
        backgroundColor: _houseColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Appliance',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: Column(
        children: [
          // Room filter chips
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _RoomChip(
                    label: 'All',
                    emoji: '🏡',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  ...ApplianceRoom.values.map(
                    (r) => _RoomChip(
                      label: r.label,
                      emoji: r.emoji,
                      selected: _filter == r,
                      onTap: () => setState(() => _filter = r),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Stats bar
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                _Stat(
                  label: 'Total',
                  value: '${_base.length}',
                  color: _houseColor,
                ),
                const SizedBox(width: 10),
                _Stat(
                  label: 'Rooms',
                  value: '${_byRoom.length}',
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                _Stat(
                  label: 'In Warranty',
                  value: '${_base.where((a) => _underWarranty(a)).length}',
                  color: AppColors.income,
                ),
              ],
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const LifeEmptyState(
                    emoji: '🏠',
                    title: 'No appliances yet',
                    subtitle: 'Add your home appliances room by room',
                  )
                : _filter != null
                ? ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ApplianceCard(
                        appliance: _filtered[i],
                        isDark: isDark,
                        onTap: () => showLifeSheet(
                          context,
                          child: _ApplianceDetail(
                            appliance: _filtered[i],
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ),
                  )
                // Group by room
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                    children: _byRoom.entries.map<Widget>((e) {
                      final cards = e.value
                          .map<Widget>(
                            (a) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ApplianceCard(
                                appliance: a,
                                isDark: isDark,
                                onTap: () => showLifeSheet(
                                  context,
                                  child: _ApplianceDetail(
                                    appliance: a,
                                    isDark: isDark,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: [
                              Text(
                                e.key.emoji,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                e.key.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Nunito',
                                  color: isDark
                                      ? AppColors.textDark
                                      : AppColors.textLight,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _houseColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${e.value.length}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                    color: _houseColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...cards,
                          const SizedBox(height: 6),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  bool _underWarranty(Appliance a) {
    if (a.warrantyExpiry == null) return false;
    try {
      final parts = a.warrantyExpiry!.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  void _showAdd(BuildContext ctx, bool isDark, Color surfBg) {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final warrantyCtrl = TextEditingController();
    var room = ApplianceRoom.kitchen;
    showLifeSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Appliance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const LifeLabel(text: 'ROOM'),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ApplianceRoom.values
                      .map(
                        (r) => GestureDetector(
                          onTap: () => ss(() => room = r),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: room == r
                                  ? _houseColor.withOpacity(0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: room == r
                                    ? _houseColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  r.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  r.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: room == r
                                        ? _houseColor
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
              LifeInput(controller: nameCtrl, hint: 'Appliance name *'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LifeInput(controller: brandCtrl, hint: 'Brand'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(
                      controller: priceCtrl,
                      hint: 'Purchase Price',
                      inputType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LifeInput(
                controller: warrantyCtrl,
                hint: 'Warranty till (YYYY-MM-DD)',
              ),
              LifeSaveButton(
                label: 'Add Appliance',
                color: _houseColor,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(
                    () => _appliances.add(
                      Appliance(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        walletId: widget.walletId,
                        room: room,
                        brand: brandCtrl.text.trim().isEmpty
                            ? null
                            : brandCtrl.text.trim(),
                        purchasePrice: double.tryParse(priceCtrl.text.trim()),
                        warrantyExpiry: warrantyCtrl.text.trim().isEmpty
                            ? null
                            : warrantyCtrl.text.trim(),
                      ),
                    ),
                  );
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

class _RoomChip extends StatelessWidget {
  final String label, emoji;
  final bool selected;
  final VoidCallback onTap;
  const _RoomChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _houseColor.withOpacity(0.15) : surfBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _houseColor : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: selected ? _houseColor : sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'DM Mono',
            color: color,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: color),
        ),
      ],
    ),
  );
}

class _ApplianceCard extends StatelessWidget {
  final Appliance appliance;
  final bool isDark;
  final VoidCallback onTap;
  const _ApplianceCard({
    required this.appliance,
    required this.isDark,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    bool underWarranty = false;
    if (appliance.warrantyExpiry != null) {
      try {
        final parts = appliance.warrantyExpiry!.split('-');
        underWarranty = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ).isAfter(DateTime.now());
      } catch (_) {}
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _houseColor.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _houseColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                appliance.room.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appliance.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                  if (appliance.brand != null)
                    Text(
                      appliance.brand!,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                  if (appliance.warrantyExpiry != null)
                    LifeBadge(
                      text: underWarranty
                          ? '✓ Under warranty'
                          : 'Warranty expired',
                      color: underWarranty
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                ],
              ),
            ),
            if (appliance.purchasePrice != null)
              Text(
                '₹${(appliance.purchasePrice! / 1000).toStringAsFixed(1)}K',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'DM Mono',
                  color: _houseColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ApplianceDetail extends StatelessWidget {
  final Appliance appliance;
  final bool isDark;
  const _ApplianceDetail({required this.appliance, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(appliance.room.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appliance.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    Text(
                      appliance.room.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (appliance.brand != null)
            LifeInfoRow(
              icon: Icons.business_rounded,
              label: 'Brand: ${appliance.brand!}',
            ),
          if (appliance.modelNo != null)
            LifeInfoRow(
              icon: Icons.tag_rounded,
              label: 'Model: ${appliance.modelNo!}',
            ),
          if (appliance.purchaseDate != null)
            LifeInfoRow(
              icon: Icons.shopping_bag_rounded,
              label: 'Purchased: ${appliance.purchaseDate!}',
            ),
          if (appliance.purchasePrice != null)
            LifeInfoRow(
              icon: Icons.currency_rupee_rounded,
              label: 'Price: ₹${appliance.purchasePrice!.toStringAsFixed(0)}',
            ),
          if (appliance.warrantyExpiry != null)
            LifeInfoRow(
              icon: Icons.verified_user_rounded,
              label: 'Warranty till: ${appliance.warrantyExpiry!}',
            ),
          if (appliance.notes != null)
            LifeInfoRow(icon: Icons.notes_rounded, label: appliance.notes!),
        ],
      ),
    );
  }
}
