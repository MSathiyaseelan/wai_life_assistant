import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import '../../widgets/life_widgets.dart';

const _garageColor = Color(0xFF4A9EFF);

class MyGarageScreen extends StatefulWidget {
  final String walletId;
  const MyGarageScreen({super.key, required this.walletId});
  @override
  State<MyGarageScreen> createState() => _MyGarageScreenState();
}

class _MyGarageScreenState extends State<MyGarageScreen> {
  final List<VehicleModel> _vehicles = List.from(mockVehicles);
  List<VehicleModel> get _filtered =>
      _vehicles.where((v) => v.walletId == widget.walletId).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;

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
            Text('🚗', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'My Garage',
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
        onPressed: () => _showAddVehicle(context, isDark),
        backgroundColor: _garageColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Vehicle',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: _filtered.isEmpty
          ? const LifeEmptyState(
              emoji: '🚗',
              title: 'No vehicles yet',
              subtitle: 'Add your vehicles to track insurance & service',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _VehicleCard(
                  vehicle: _filtered[i],
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _VehicleDetailScreen(
                        vehicle: _filtered[i],
                        isDark: isDark,
                        onUpdate: () => setState(() {}),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _showAddVehicle(BuildContext ctx, bool isDark) {
    final isDarkLocal = isDark;
    final surfBg = isDarkLocal ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final nameCtrl = TextEditingController();
    final makeCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    final regCtrl = TextEditingController();
    var selectedType = VehicleType.car;
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
                'Add Vehicle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const LifeLabel(text: 'VEHICLE TYPE'),
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: VehicleType.values
                      .map(
                        (t) => GestureDetector(
                          onTap: () => ss(() => selectedType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selectedType == t
                                  ? _garageColor.withOpacity(0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selectedType == t
                                    ? _garageColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  t.emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  t.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: selectedType == t
                                        ? _garageColor
                                        : (isDarkLocal
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
              LifeInput(
                controller: nameCtrl,
                hint: 'Vehicle nickname (e.g. "My Activa") *',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LifeInput(
                      controller: makeCtrl,
                      hint: 'Make (e.g. Honda)',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(controller: modelCtrl, hint: 'Model'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LifeInput(
                      controller: yearCtrl,
                      hint: 'Year',
                      inputType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(controller: regCtrl, hint: 'Reg. No.'),
                  ),
                ],
              ),
              LifeSaveButton(
                label: 'Add to Garage',
                color: _garageColor,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(
                    () => _vehicles.add(
                      VehicleModel(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        walletId: widget.walletId,
                        type: selectedType,
                        make: makeCtrl.text.trim().isEmpty
                            ? null
                            : makeCtrl.text.trim(),
                        model: modelCtrl.text.trim().isEmpty
                            ? null
                            : modelCtrl.text.trim(),
                        year: yearCtrl.text.trim().isEmpty
                            ? null
                            : yearCtrl.text.trim(),
                        regNo: regCtrl.text.trim().isEmpty
                            ? null
                            : regCtrl.text.trim(),
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

// ── Vehicle card ──────────────────────────────────────────────────────────────
class _VehicleCard extends StatelessWidget {
  final VehicleModel vehicle;
  final bool isDark;
  final VoidCallback onTap;
  const _VehicleCard({
    required this.vehicle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final insNearExpiry = vehicle.policies.any((p) {
      final days = p.expiryDate.difference(DateTime.now()).inDays;
      return days >= 0 && days <= 30;
    });

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _garageColor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            // Top banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_garageColor, _garageColor.withOpacity(0.7)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    vehicle.type.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        if (vehicle.make != null || vehicle.year != null)
                          Text(
                            '${vehicle.make ?? ''} ${vehicle.model ?? ''} ${vehicle.year != null ? '(${vehicle.year})' : ''}'
                                .trim(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'Nunito',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (insNearExpiry)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '⚠️ Insurance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Bottom info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (vehicle.regNo != null) ...[
                    const Icon(
                      Icons.numbers_rounded,
                      size: 13,
                      color: _garageColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      vehicle.regNo!,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: sub,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Icon(
                    Icons.shield_rounded,
                    size: 13,
                    color: AppColors.income,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${vehicle.policies.length} polic${vehicle.policies.length == 1 ? 'y' : 'ies'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${vehicle.services.length} services  •  ${vehicle.repairs.length} repairs',
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

// ── Vehicle detail screen ─────────────────────────────────────────────────────
class _VehicleDetailScreen extends StatefulWidget {
  final VehicleModel vehicle;
  final bool isDark;
  final VoidCallback onUpdate;
  const _VehicleDetailScreen({
    required this.vehicle,
    required this.isDark,
    required this.onUpdate,
  });
  @override
  State<_VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<_VehicleDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
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
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final v = widget.vehicle;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          v.name,
          style: const TextStyle(
            fontSize: 16,
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
          indicatorColor: _garageColor,
          labelColor: _garageColor,
          unselectedLabelColor: sub,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Insurance'),
            Tab(text: 'Service'),
            Tab(text: 'Repairs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // DETAILS
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailSection(
                  emoji: v.type.emoji,
                  title: v.name,
                  isDark: isDark,
                  rows: [
                    if (v.make != null) ('Make', v.make!),
                    if (v.model != null) ('Model', v.model!),
                    if (v.year != null) ('Year', v.year!),
                    if (v.regNo != null) ('Reg. No.', v.regNo!),
                    if (v.chassisNo != null) ('Chassis', v.chassisNo!),
                    if (v.engineNo != null) ('Engine No.', v.engineNo!),
                    if (v.fuelType != null) ('Fuel', v.fuelType!),
                    if (v.color != null) ('Color', v.color!),
                  ],
                ),
              ],
            ),
          ),

          // INSURANCE
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (v.policies.isEmpty)
                const LifeEmptyState(
                  emoji: '🛡️',
                  title: 'No policies added',
                  subtitle: 'Add insurance policies to track expiry',
                )
              else
                ...v.policies.map((p) {
                  final daysLeft = p.expiryDate
                      .difference(DateTime.now())
                      .inDays;
                  final expired = daysLeft < 0;
                  final nearExpiry = !expired && daysLeft <= 30;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: expired
                            ? AppColors.expense.withOpacity(0.3)
                            : nearExpiry
                            ? AppColors.lend.withOpacity(0.4)
                            : AppColors.income.withOpacity(0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('🛡️', style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.provider,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Nunito',
                                      color: tc,
                                    ),
                                  ),
                                  Text(
                                    p.type,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            LifeBadge(
                              text: expired
                                  ? 'Expired'
                                  : nearExpiry
                                  ? 'Expires in ${daysLeft}d'
                                  : 'Active',
                              color: expired
                                  ? AppColors.expense
                                  : nearExpiry
                                  ? AppColors.lend
                                  : AppColors.income,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _PolicyStat(
                                label: 'Policy No.',
                                value: p.policyNo,
                              ),
                            ),
                            Expanded(
                              child: _PolicyStat(
                                label: 'Premium',
                                value: '₹${p.premium.toStringAsFixed(0)}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _PolicyStat(
                                label: 'Start',
                                value: _fmt(p.startDate),
                              ),
                            ),
                            Expanded(
                              child: _PolicyStat(
                                label: 'Expiry',
                                value: _fmt(p.expiryDate),
                                valueColor: expired
                                    ? AppColors.expense
                                    : nearExpiry
                                    ? AppColors.lend
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              const SizedBox(height: 80),
            ],
          ),

          // SERVICE
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (v.services.isEmpty)
                const LifeEmptyState(
                  emoji: '🔧',
                  title: 'No service records',
                  subtitle: 'Track your vehicle service history',
                )
              else
                ...v.services
                    .map(
                      (s) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _garageColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '🔧',
                                style: TextStyle(fontSize: 22),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.serviceName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Nunito',
                                      color: tc,
                                    ),
                                  ),
                                  Text(
                                    s.garage,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                                  Text(
                                    _fmt(s.serviceDate),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                                  if (s.nextDue != null)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 11,
                                          color: AppColors.lend,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Next: ${_fmt(s.nextDue!)}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontFamily: 'Nunito',
                                            color: AppColors.lend,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            if (s.cost != null)
                              Text(
                                '₹${s.cost!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'DM Mono',
                                  color: _garageColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              const SizedBox(height: 80),
            ],
          ),

          // REPAIRS
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (v.repairs.isEmpty)
                const LifeEmptyState(
                  emoji: '🔩',
                  title: 'No repair tasks',
                  subtitle: 'Plan upcoming repairs and maintenance',
                )
              else
                ...v.repairs
                    .map(
                      (r) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => r.done = !r.done),
                              child: Icon(
                                r.done
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: r.done ? AppColors.income : _garageColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Nunito',
                                      color: tc,
                                      decoration: r.done
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if (r.notes != null)
                                    Text(
                                      r.notes!,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'Nunito',
                                        color: sub,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (r.estimatedCost != null)
                              Text(
                                '~₹${r.estimatedCost!.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'DM Mono',
                                  color: sub,
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              const SizedBox(height: 80),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    const m = [
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
    return '${d.day} ${m[d.month]} ${d.year}';
  }
}

class _DetailSection extends StatelessWidget {
  final String emoji, title;
  final bool isDark;
  final List<(String, String)> rows;
  const _DetailSection({
    required this.emoji,
    required this.title,
    required this.isDark,
    required this.rows,
  });
  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_garageColor, _garageColor.withOpacity(0.7)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
          ),
          ...rows
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        r.$1,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                      Text(
                        r.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PolicyStat extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _PolicyStat({
    required this.label,
    required this.value,
    this.valueColor,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9, fontFamily: 'Nunito', color: sub),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFamily: 'DM Mono',
            color: valueColor ?? tc,
          ),
        ),
      ],
    );
  }
}
