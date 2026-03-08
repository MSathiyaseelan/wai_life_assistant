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
                        onTap: () {
                          final device = _filtered[i];
                          showLifeSheet(
                            context,
                            child: _DeviceDetail(
                              device: device,
                              isDark: isDark,
                              onEdit: () {
                                Navigator.pop(context);
                                _showEditDevice(
                                  context,
                                  isDark,
                                  surfBg,
                                  device,
                                );
                              },
                              onDelete: () => setState(
                                () => _devices.removeWhere(
                                  (d) => d.id == device.id,
                                ),
                              ),
                            ),
                          );
                        },
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
    final purchaseDateCtrl = TextEditingController();
    final imeiCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
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
              Row(
                children: [
                  Expanded(
                    child: LifeInput(
                      controller: warrantyCtrl,
                      hint: 'Warranty till (YYYY-MM-DD)',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(
                      controller: purchaseDateCtrl,
                      hint: 'Purchase date (YYYY-MM-DD)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (cat == DeviceCategory.phone)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LifeInput(controller: imeiCtrl, hint: 'IMEI'),
                ),
              LifeInput(controller: notesCtrl, hint: 'Notes'),
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
                        purchaseDate: purchaseDateCtrl.text.trim().isEmpty
                            ? null
                            : purchaseDateCtrl.text.trim(),
                        imei: imeiCtrl.text.trim().isEmpty
                            ? null
                            : imeiCtrl.text.trim(),
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      ),
                    ),
                  );
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDevice(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    DeviceModel device,
  ) {
    final nameCtrl = TextEditingController(text: device.name);
    final brandCtrl = TextEditingController(text: device.brand ?? '');
    final modelCtrl = TextEditingController(text: device.modelNo ?? '');
    final serialCtrl = TextEditingController(text: device.serialNo ?? '');
    final priceCtrl = TextEditingController(text: device.purchasePrice ?? '');
    final warrantyCtrl = TextEditingController(
      text: device.warrantyExpiry ?? '',
    );
    final purchaseDateCtrl = TextEditingController(
      text: device.purchaseDate ?? '',
    );
    final imeiCtrl = TextEditingController(text: device.imei ?? '');
    final notesCtrl = TextEditingController(text: device.notes ?? '');
    var cat = device.category;
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
                'Edit Device',
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
                                  ? c.color.withValues(alpha: 0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: cat == c
                                    ? c.color
                                    : Colors.transparent,
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
              Row(
                children: [
                  Expanded(
                    child: LifeInput(
                      controller: warrantyCtrl,
                      hint: 'Warranty till (YYYY-MM-DD)',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(
                      controller: purchaseDateCtrl,
                      hint: 'Purchase date (YYYY-MM-DD)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (cat == DeviceCategory.phone)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LifeInput(controller: imeiCtrl, hint: 'IMEI'),
                ),
              LifeInput(controller: notesCtrl, hint: 'Notes'),
              LifeSaveButton(
                label: 'Save Changes',
                color: cat.color,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(() {
                    device.name = nameCtrl.text.trim();
                    device.category = cat;
                    device.brand = brandCtrl.text.trim().isEmpty
                        ? null
                        : brandCtrl.text.trim();
                    device.modelNo = modelCtrl.text.trim().isEmpty
                        ? null
                        : modelCtrl.text.trim();
                    device.serialNo = serialCtrl.text.trim().isEmpty
                        ? null
                        : serialCtrl.text.trim();
                    device.purchasePrice = priceCtrl.text.trim().isEmpty
                        ? null
                        : priceCtrl.text.trim();
                    device.warrantyExpiry = warrantyCtrl.text.trim().isEmpty
                        ? null
                        : warrantyCtrl.text.trim();
                    device.purchaseDate = purchaseDateCtrl.text.trim().isEmpty
                        ? null
                        : purchaseDateCtrl.text.trim();
                    device.imei = imeiCtrl.text.trim().isEmpty
                        ? null
                        : imeiCtrl.text.trim();
                    device.notes = notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim();
                  });
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
                        text: _warrantyExpiringSoon(device.warrantyExpiry)
                            ? '⚠ Expiring Soon'
                            : (device.isUnderWarranty
                                  ? '✓ Warranty'
                                  : 'No warranty'),
                        color: _warrantyExpiringSoon(device.warrantyExpiry)
                            ? AppColors.expense
                            : (device.isUnderWarranty
                                  ? AppColors.income
                                  : AppColors.subLight),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _DeviceDetail({
    required this.device,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final color = device.category.color;
    final expiringSoon = _warrantyExpiringSoon(device.warrantyExpiry);
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
              IconButton(
                icon: Icon(Icons.edit_rounded, color: color, size: 20),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.expense,
                  size: 20,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text(
                        'Delete Device?',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      content: Text(
                        'Remove "${device.name}" from your devices?',
                        style: const TextStyle(fontFamily: 'Nunito'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontFamily: 'Nunito'),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onDelete();
                          },
                          child: Text(
                            'Delete',
                            style: TextStyle(
                              color: AppColors.expense,
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                tooltip: 'Delete',
              ),
            ],
          ),
          if (expiringSoon)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.expense.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.expense,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Warranty expiring soon — ${device.warrantyExpiry}',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ),
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
            if (device.notes != null)
              (Icons.notes_rounded, 'Notes', device.notes!),
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

bool _warrantyExpiringSoon(String? exp) {
  if (exp == null) return false;
  final parts = exp.split('-');
  if (parts.length != 3) return false;
  try {
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final diff = date.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 30;
  } catch (_) {
    return false;
  }
}
