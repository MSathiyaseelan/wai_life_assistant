import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import '../../widgets/life_widgets.dart';

class MyDevicesScreen extends StatefulWidget {
  final String walletId;
  const MyDevicesScreen({super.key, required this.walletId});
  @override
  State<MyDevicesScreen> createState() => _MyDevicesScreenState();
}

class _MyDevicesScreenState extends State<MyDevicesScreen> {
  final List<DeviceModel> _devices = List.from(mockDevices);
  DeviceCategory? _filter;
  List<DeviceModel> get _filtered {
    final base = _devices.where((d) => d.walletId == widget.walletId).toList();
    if (_filter == null) return base;
    return base.where((d) => d.category == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    const color = Color(0xFF9C27B0);

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
            Text('📱', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'My Devices',
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
        onPressed: () => _showAddDevice(context, isDark, surfBg),
        backgroundColor: color,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Device',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: Column(
        children: [
          // Category filter
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'All',
                    emoji: '📦',
                    selected: _filter == null,
                    color: color,
                    onTap: () => setState(() => _filter = null),
                  ),
                  ...DeviceCategory.values.map(
                    (c) => _FilterChip(
                      label: c.label,
                      emoji: c.emoji,
                      selected: _filter == c,
                      color: c.color,
                      onTap: () => setState(() => _filter = c),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const LifeEmptyState(
                    emoji: '📱',
                    title: 'No devices yet',
                    subtitle: 'Track your gadgets, warranty & more',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DeviceCard(
                        device: _filtered[i],
                        isDark: isDark,
                        onTap: () => showLifeSheet(
                          context,
                          child: _DeviceDetail(
                            device: _filtered[i],
                            isDark: isDark,
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

  void _showAddDevice(BuildContext ctx, bool isDark, Color surfBg) {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final serialCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final warrantyCtrl = TextEditingController();
    var cat = DeviceCategory.phone;
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
                'Add Device',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const LifeLabel(text: 'CATEGORY'),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: DeviceCategory.values
                      .map(
                        (c) => GestureDetector(
                          onTap: () => ss(() => cat = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: cat == c
                                  ? c.color.withOpacity(0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: cat == c ? c.color : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  c.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  c.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: cat == c
                                        ? c.color
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
              LifeInput(controller: nameCtrl, hint: 'Device name *'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LifeInput(controller: brandCtrl, hint: 'Brand'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(controller: modelCtrl, hint: 'Model No.'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LifeInput(
                      controller: serialCtrl,
                      hint: 'Serial No.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(
                      controller: priceCtrl,
                      hint: 'Purchase Price',
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
                label: 'Add Device',
                color: cat.color,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(
                    () => _devices.add(
                      DeviceModel(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        walletId: widget.walletId,
                        ownerId: 'me',
                        category: cat,
                        brand: brandCtrl.text.trim().isEmpty
                            ? null
                            : brandCtrl.text.trim(),
                        modelNo: modelCtrl.text.trim().isEmpty
                            ? null
                            : modelCtrl.text.trim(),
                        serialNo: serialCtrl.text.trim().isEmpty
                            ? null
                            : serialCtrl.text.trim(),
                        purchasePrice: priceCtrl.text.trim().isEmpty
                            ? null
                            : priceCtrl.text.trim(),
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

class _FilterChip extends StatelessWidget {
  final String label, emoji;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.color,
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
          color: selected ? color.withOpacity(0.15) : surfBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : Colors.transparent),
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
                color: selected ? color : sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final bool isDark;
  final VoidCallback onTap;
  const _DeviceCard({
    required this.device,
    required this.isDark,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final color = device.category.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                device.category.emoji,
                style: const TextStyle(fontSize: 26),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                  if (device.brand != null)
                    Text(
                      '${device.brand}${device.modelNo != null ? " • ${device.modelNo}" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      LifeBadge(text: device.category.label, color: color),
                      const SizedBox(width: 6),
                      LifeBadge(
                        text: device.isUnderWarranty
                            ? '✓ Warranty'
                            : 'No warranty',
                        color: device.isUnderWarranty
                            ? AppColors.income
                            : AppColors.subLight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (device.purchasePrice != null)
              Text(
                device.purchasePrice!,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'DM Mono',
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeviceDetail extends StatelessWidget {
  final DeviceModel device;
  final bool isDark;
  const _DeviceDetail({required this.device, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final color = device.category.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  device.category.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    LifeBadge(text: device.category.label, color: color),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...[
            if (device.brand != null)
              (Icons.business_rounded, 'Brand', device.brand!),
            if (device.modelNo != null)
              (Icons.tag_rounded, 'Model', device.modelNo!),
            if (device.serialNo != null)
              (Icons.qr_code_rounded, 'Serial No.', device.serialNo!),
            if (device.imei != null)
              (Icons.phone_iphone_rounded, 'IMEI', device.imei!),
            if (device.purchaseDate != null)
              (Icons.shopping_bag_rounded, 'Purchased', device.purchaseDate!),
            if (device.purchasePrice != null)
              (Icons.currency_rupee_rounded, 'Price', device.purchasePrice!),
            if (device.warrantyExpiry != null)
              (
                Icons.verified_user_rounded,
                'Warranty Till',
                device.warrantyExpiry!,
              ),
          ].map(
            (r) => LifeInfoRow(
              icon: r.$1,
              label: '${r.$2}: ${r.$3}',
              color: r.$2 == 'Warranty Till'
                  ? (device.isUnderWarranty
                        ? AppColors.income
                        : AppColors.expense)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
