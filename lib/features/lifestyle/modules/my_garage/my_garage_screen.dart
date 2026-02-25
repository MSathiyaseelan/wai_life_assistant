import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import '../../widgets/life_widgets.dart';

const _garageColor = Color(0xFF4A9EFF);

// ─────────────────────────────────────────────────────────────────────────────
// GARAGE LIST SCREEN
// ─────────────────────────────────────────────────────────────────────────────

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
                        onDelete: () {
                          setState(() => _vehicles.remove(_filtered[i]));
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _showAddVehicle(BuildContext ctx, bool isDark) {
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final nameCtrl = TextEditingController();
    final makeCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    final regCtrl = TextEditingController();
    final chassisCtrl = TextEditingController();
    final engineCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    var selectedType = VehicleType.car;
    var selectedFuel = 'Petrol';
    var selectedOwner = 'me';
    final fuels = ['Petrol', 'Diesel', 'Electric', 'CNG', 'LPG', 'Hybrid'];

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
              const SizedBox(height: 16),

              // Vehicle type
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LifeInput(
                      controller: chassisCtrl,
                      hint: 'Chassis No.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(
                      controller: engineCtrl,
                      hint: 'Engine No.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LifeInput(controller: colorCtrl, hint: 'Color'),

              // Fuel type
              const LifeLabel(text: 'FUEL TYPE'),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: fuels
                      .map(
                        (f) => GestureDetector(
                          onTap: () => ss(() => selectedFuel = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: selectedFuel == f
                                  ? _garageColor.withOpacity(0.12)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selectedFuel == f
                                    ? _garageColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: selectedFuel == f
                                    ? _garageColor
                                    : (isDark
                                          ? AppColors.subDark
                                          : AppColors.subLight),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              // Owner
              const LifeLabel(text: 'OWNER'),
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: mockLifeMembers
                      .map(
                        (m) => GestureDetector(
                          onTap: () => ss(() => selectedOwner = m.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selectedOwner == m.id
                                  ? _garageColor.withOpacity(0.12)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selectedOwner == m.id
                                    ? _garageColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  m.emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  m.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: selectedOwner == m.id
                                        ? _garageColor
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
                        chassisNo: chassisCtrl.text.trim().isEmpty
                            ? null
                            : chassisCtrl.text.trim(),
                        engineNo: engineCtrl.text.trim().isEmpty
                            ? null
                            : engineCtrl.text.trim(),
                        color: colorCtrl.text.trim().isEmpty
                            ? null
                            : colorCtrl.text.trim(),
                        fuelType: selectedFuel,
                        ownerId: selectedOwner,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// VEHICLE CARD
// ─────────────────────────────────────────────────────────────────────────────

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
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final owner = mockLifeMembers.firstWhere(
      (m) => m.id == (vehicle.ownerId ?? 'me'),
      orElse: () => const LifeMember(id: '?', name: '?', emoji: '👤'),
    );
    final insNearExpiry = vehicle.policies.any((p) {
      final days = p.expiryDate.difference(DateTime.now()).inDays;
      return days >= 0 && days <= 30;
    });
    final insExpired = vehicle.policies.any(
      (p) => p.expiryDate.difference(DateTime.now()).inDays < 0,
    );

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
            // Banner
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
                    style: const TextStyle(fontSize: 34),
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
                        Text(
                          [
                            vehicle.make,
                            vehicle.model,
                            vehicle.year != null ? '(${vehicle.year})' : null,
                          ].where((e) => e != null && e.isNotEmpty).join(' '),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text(
                            owner.emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            owner.name,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      ),
                      if (insExpired)
                        _AlertChip('⚠️ Ins. Expired', Colors.red.shade300)
                      else if (insNearExpiry)
                        _AlertChip('⚠️ Ins. Expiring', Colors.amber.shade300),
                    ],
                  ),
                ],
              ),
            ),
            // Footer stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (vehicle.regNo != null) ...[
                    const Icon(
                      Icons.numbers_rounded,
                      size: 13,
                      color: _garageColor,
                    ),
                    const SizedBox(width: 4),
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
                  if (vehicle.fuelType != null) ...[
                    const Icon(
                      Icons.local_gas_station_rounded,
                      size: 13,
                      color: _garageColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vehicle.fuelType!,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Spacer(),
                  _StatPill('🛡️', '${vehicle.policies.length}', sub),
                  const SizedBox(width: 8),
                  _StatPill('🔧', '${vehicle.services.length}', sub),
                  const SizedBox(width: 8),
                  _StatPill('🔩', '${vehicle.repairs.length}', sub),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final String text;
  final Color color;
  const _AlertChip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        fontFamily: 'Nunito',
      ),
    ),
  );
}

class _StatPill extends StatelessWidget {
  final String emoji, value;
  final Color color;
  const _StatPill(this.emoji, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 11)),
      const SizedBox(width: 3),
      Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'Nunito',
          color: color,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// VEHICLE DETAIL SCREEN  (4 tabs + per-tab FABs)
// ─────────────────────────────────────────────────────────────────────────────

class _VehicleDetailScreen extends StatefulWidget {
  final VehicleModel vehicle;
  final bool isDark;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;
  const _VehicleDetailScreen({
    required this.vehicle,
    required this.isDark,
    required this.onUpdate,
    required this.onDelete,
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
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final v = widget.vehicle;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Row(
          children: [
            Text(v.type.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                v.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            onPressed: () => _showEditVehicle(context, isDark),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.expense,
              size: 20,
            ),
            onPressed: () => _confirmDelete(context),
          ),
        ],
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
      // Per-tab FABs
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (_, __) {
          switch (_tab.index) {
            case 1:
              return _Fab(
                'Add Policy',
                Icons.shield_rounded,
                AppColors.income,
                () => _showAddInsurance(context, isDark),
              );
            case 2:
              return _Fab(
                'Add Service',
                Icons.build_rounded,
                _garageColor,
                () => _showAddService(context, isDark),
              );
            case 3:
              return _Fab(
                'Add Repair',
                Icons.construction_rounded,
                AppColors.lend,
                () => _showAddRepair(context, isDark),
              );
            default:
              return const SizedBox.shrink();
          }
        },
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _DetailsTab(vehicle: v, isDark: isDark),
          _InsuranceTab(
            vehicle: v,
            isDark: isDark,
            onUpdate: () => setState(() {}),
          ),
          _ServiceTab(
            vehicle: v,
            isDark: isDark,
            onUpdate: () => setState(() {}),
          ),
          _RepairTab(
            vehicle: v,
            isDark: isDark,
            onUpdate: () => setState(() {}),
          ),
        ],
      ),
    );
  }

  // ── Edit basic details ────────────────────────────────────────────────────
  void _showEditVehicle(BuildContext ctx, bool isDark) {
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final v = widget.vehicle;
    final nameCtrl = TextEditingController(text: v.name);
    final makeCtrl = TextEditingController(text: v.make ?? '');
    final modelCtrl = TextEditingController(text: v.model ?? '');
    final yearCtrl = TextEditingController(text: v.year ?? '');
    final regCtrl = TextEditingController(text: v.regNo ?? '');
    final chassisCtrl = TextEditingController(text: v.chassisNo ?? '');
    final engineCtrl = TextEditingController(text: v.engineNo ?? '');
    final colorCtrl = TextEditingController(text: v.color ?? '');
    var selType = v.type;
    var selFuel = v.fuelType ?? 'Petrol';
    var selOwner = v.ownerId ?? 'me';
    final fuels = ['Petrol', 'Diesel', 'Electric', 'CNG', 'LPG', 'Hybrid'];

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
                'Edit Vehicle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 16),

              const LifeLabel(text: 'VEHICLE TYPE'),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: VehicleType.values
                      .map(
                        (t) => GestureDetector(
                          onTap: () => ss(() => selType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: selType == t
                                  ? _garageColor.withOpacity(0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selType == t
                                    ? _garageColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  t.emoji,
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  t.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: selType == t
                                        ? _garageColor
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

              LifeInput(controller: nameCtrl, hint: 'Vehicle nickname *'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LifeInput(controller: makeCtrl, hint: 'Make'),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LifeInput(
                      controller: chassisCtrl,
                      hint: 'Chassis No.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(
                      controller: engineCtrl,
                      hint: 'Engine No.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LifeInput(controller: colorCtrl, hint: 'Color'),

              const LifeLabel(text: 'FUEL TYPE'),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: fuels
                      .map(
                        (f) => GestureDetector(
                          onTap: () => ss(() => selFuel = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selFuel == f
                                  ? _garageColor.withOpacity(0.12)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selFuel == f
                                    ? _garageColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: selFuel == f
                                    ? _garageColor
                                    : (isDark
                                          ? AppColors.subDark
                                          : AppColors.subLight),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              const LifeLabel(text: 'OWNER'),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: mockLifeMembers
                      .map(
                        (m) => GestureDetector(
                          onTap: () => ss(() => selOwner = m.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: selOwner == m.id
                                  ? _garageColor.withOpacity(0.12)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selOwner == m.id
                                    ? _garageColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  m.emoji,
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  m.name,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: selOwner == m.id
                                        ? _garageColor
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

              LifeSaveButton(
                label: 'Save Changes',
                color: _garageColor,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(() {
                    v.name = nameCtrl.text.trim();
                    v.type = selType;
                    v.make = makeCtrl.text.trim().isEmpty
                        ? null
                        : makeCtrl.text.trim();
                    v.model = modelCtrl.text.trim().isEmpty
                        ? null
                        : modelCtrl.text.trim();
                    v.year = yearCtrl.text.trim().isEmpty
                        ? null
                        : yearCtrl.text.trim();
                    v.regNo = regCtrl.text.trim().isEmpty
                        ? null
                        : regCtrl.text.trim();
                    v.chassisNo = chassisCtrl.text.trim().isEmpty
                        ? null
                        : chassisCtrl.text.trim();
                    v.engineNo = engineCtrl.text.trim().isEmpty
                        ? null
                        : engineCtrl.text.trim();
                    v.color = colorCtrl.text.trim().isEmpty
                        ? null
                        : colorCtrl.text.trim();
                    v.fuelType = selFuel;
                    v.ownerId = selOwner;
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

  // ── Add insurance policy ──────────────────────────────────────────────────
  void _showAddInsurance(BuildContext ctx, bool isDark) {
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final provCtrl = TextEditingController();
    final policyCtrl = TextEditingController();
    final premCtrl = TextEditingController();
    var policyType = 'Comprehensive';
    DateTime startDate = DateTime.now();
    DateTime expiryDate = DateTime.now().add(const Duration(days: 365));
    final types = ['Comprehensive', 'Third Party', 'Zero Dep', 'OD Only'];

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
                'Add Insurance Policy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 16),

              const LifeLabel(text: 'POLICY TYPE'),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: types
                      .map(
                        (t) => GestureDetector(
                          onTap: () => ss(() => policyType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: policyType == t
                                  ? AppColors.income.withOpacity(0.12)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: policyType == t
                                    ? AppColors.income
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: policyType == t
                                    ? AppColors.income
                                    : (isDark
                                          ? AppColors.subDark
                                          : AppColors.subLight),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),

              LifeInput(controller: provCtrl, hint: 'Insurance provider *'),
              const SizedBox(height: 8),
              LifeInput(controller: policyCtrl, hint: 'Policy number'),
              const SizedBox(height: 8),
              LifeInput(
                controller: premCtrl,
                hint: 'Annual premium (₹)',
                inputType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: LifeDateTile(
                      date: startDate,
                      hint: 'Start date',
                      color: AppColors.income,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) ss(() => startDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeDateTile(
                      date: expiryDate,
                      hint: 'Expiry date',
                      color: AppColors.expense,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: expiryDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) ss(() => expiryDate = d);
                      },
                    ),
                  ),
                ],
              ),

              LifeSaveButton(
                label: 'Add Policy',
                color: AppColors.income,
                onTap: () {
                  if (provCtrl.text.trim().isEmpty) return;
                  setState(
                    () => widget.vehicle.policies.add(
                      VehicleInsurance(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        provider: provCtrl.text.trim(),
                        policyNo: policyCtrl.text.trim().isEmpty
                            ? '-'
                            : policyCtrl.text.trim(),
                        type: policyType,
                        startDate: startDate,
                        expiryDate: expiryDate,
                        premium: double.tryParse(premCtrl.text.trim()) ?? 0,
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

  // ── Add service record ────────────────────────────────────────────────────
  void _showAddService(BuildContext ctx, bool isDark) {
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final svcCtrl = TextEditingController();
    final garageCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime serviceDate = DateTime.now();
    DateTime? nextDue;

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
                'Add Service Record',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 16),

              LifeInput(
                controller: svcCtrl,
                hint: 'Service name (e.g. 6-Month Service) *',
              ),
              const SizedBox(height: 8),
              LifeInput(
                controller: garageCtrl,
                hint: 'Garage / Service center',
              ),
              const SizedBox(height: 8),
              LifeInput(
                controller: costCtrl,
                hint: 'Cost (₹)',
                inputType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              LifeInput(
                controller: notesCtrl,
                hint: 'Notes / work done',
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: LifeDateTile(
                      date: serviceDate,
                      hint: 'Service date',
                      color: _garageColor,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: serviceDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) ss(() => serviceDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeDateTile(
                      date: nextDue,
                      hint: 'Next due (optional)',
                      color: AppColors.lend,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(
                            const Duration(days: 180),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) ss(() => nextDue = d);
                      },
                    ),
                  ),
                ],
              ),

              LifeSaveButton(
                label: 'Save Service',
                color: _garageColor,
                onTap: () {
                  if (svcCtrl.text.trim().isEmpty) return;
                  setState(
                    () => widget.vehicle.services.add(
                      VehicleService(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        serviceName: svcCtrl.text.trim(),
                        garage: garageCtrl.text.trim().isEmpty
                            ? 'Unspecified'
                            : garageCtrl.text.trim(),
                        serviceDate: serviceDate,
                        cost: double.tryParse(costCtrl.text.trim()),
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                        nextDue: nextDue,
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

  // ── Add repair task ───────────────────────────────────────────────────────
  void _showAddRepair(BuildContext ctx, bool isDark) {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    DateTime? plannedDate;

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
                'Add Repair / Planned Work',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 16),

              LifeInput(
                controller: titleCtrl,
                hint: 'What needs to be done? *',
              ),
              const SizedBox(height: 8),
              LifeInput(
                controller: notesCtrl,
                hint: 'Notes / description',
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              LifeInput(
                controller: costCtrl,
                hint: 'Estimated cost (₹)',
                inputType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              LifeDateTile(
                date: plannedDate,
                hint: 'Planned date (optional)',
                color: AppColors.lend,
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) ss(() => plannedDate = d);
                },
              ),

              LifeSaveButton(
                label: 'Add Repair Task',
                color: AppColors.lend,
                onTap: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  setState(
                    () => widget.vehicle.repairs.add(
                      RepairTask(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleCtrl.text.trim(),
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                        estimatedCost: double.tryParse(costCtrl.text.trim()),
                        plannedDate: plannedDate,
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

  void _confirmDelete(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text(
          'Remove Vehicle?',
          style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Nunito'),
        ),
        content: Text(
          'This will permanently remove ${widget.vehicle.name} from your garage.',
          style: const TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete();
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.expense),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB: DETAILS
// ─────────────────────────────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  final VehicleModel vehicle;
  final bool isDark;
  const _DetailsTab({required this.vehicle, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final owner = mockLifeMembers.firstWhere(
      (m) => m.id == (vehicle.ownerId ?? 'me'),
      orElse: () => const LifeMember(id: '?', name: '?', emoji: '👤'),
    );

    final rows = <(String, String)>[
      if (vehicle.make != null) ('Make', vehicle.make!),
      if (vehicle.model != null) ('Model', vehicle.model!),
      if (vehicle.year != null) ('Year', vehicle.year!),
      if (vehicle.color != null) ('Color', vehicle.color!),
      if (vehicle.fuelType != null) ('Fuel Type', vehicle.fuelType!),
      ('Owner', '${owner.emoji}  ${owner.name}'),
      if (vehicle.regNo != null) ('Reg. Number', vehicle.regNo!),
      if (vehicle.chassisNo != null) ('Chassis No.', vehicle.chassisNo!),
      if (vehicle.engineNo != null) ('Engine No.', vehicle.engineNo!),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero banner
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_garageColor, _garageColor.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(vehicle.type.emoji, style: const TextStyle(fontSize: 48)),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      Text(
                        vehicle.type.label,
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
          const SizedBox(height: 16),

          // Identity details card
          if (rows.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _garageColor.withOpacity(0.12)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _garageColor.withOpacity(0.08),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: _garageColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Vehicle Details',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            color: _garageColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...rows
                      .map(
                        (r) => Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                            if (r != rows.last)
                              Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: _garageColor.withOpacity(0.08),
                              ),
                          ],
                        ),
                      )
                      .toList(),
                  const SizedBox(height: 4),
                ],
              ),
            ),

          // Quick stats
          const SizedBox(height: 16),
          Row(
            children: [
              _QuickStat(
                emoji: '🛡️',
                label: 'Policies',
                value: '${vehicle.policies.length}',
                color: AppColors.income,
              ),
              const SizedBox(width: 10),
              _QuickStat(
                emoji: '🔧',
                label: 'Services',
                value: '${vehicle.services.length}',
                color: _garageColor,
              ),
              const SizedBox(width: 10),
              _QuickStat(
                emoji: '🔩',
                label: 'Repairs',
                value:
                    '${vehicle.repairs.where((r) => !r.done).length} pending',
                color: AppColors.lend,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const _QuickStat({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
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

// ─────────────────────────────────────────────────────────────────────────────
// TAB: INSURANCE
// ─────────────────────────────────────────────────────────────────────────────

class _InsuranceTab extends StatefulWidget {
  final VehicleModel vehicle;
  final bool isDark;
  final VoidCallback onUpdate;
  const _InsuranceTab({
    required this.vehicle,
    required this.isDark,
    required this.onUpdate,
  });
  @override
  State<_InsuranceTab> createState() => _InsuranceTabState();
}

class _InsuranceTabState extends State<_InsuranceTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final v = widget.vehicle;

    if (v.policies.isEmpty) {
      return const LifeEmptyState(
        emoji: '🛡️',
        title: 'No policies yet',
        subtitle: 'Tap the + button to add an insurance policy',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: v.policies.map((p) {
        final daysLeft = p.expiryDate.difference(DateTime.now()).inDays;
        final expired = daysLeft < 0;
        final nearExpiry = !expired && daysLeft <= 30;
        final statusColor = expired
            ? AppColors.expense
            : nearExpiry
            ? AppColors.lend
            : AppColors.income;
        final statusText = expired
            ? 'Expired'
            : nearExpiry
            ? 'Expires in ${daysLeft}d'
            : 'Active';

        return Dismissible(
          key: ValueKey(p.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.expense.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.expense,
              size: 24,
            ),
          ),
          onDismissed: (_) => setState(() {
            v.policies.remove(p);
            widget.onUpdate();
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '🛡️',
                          style: TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                      LifeBadge(text: statusText, color: statusColor),
                    ],
                  ),
                ),
                // Details grid
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _InsCell(
                              label: 'Policy No.',
                              value: p.policyNo,
                              color: sub,
                              tc: tc,
                            ),
                          ),
                          Expanded(
                            child: _InsCell(
                              label: 'Premium',
                              value: '₹${p.premium.toStringAsFixed(0)}/yr',
                              color: sub,
                              tc: tc,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _InsCell(
                              label: 'Start Date',
                              value: _fmtDate(p.startDate),
                              color: sub,
                              tc: tc,
                            ),
                          ),
                          Expanded(
                            child: _InsCell(
                              label: 'Expiry Date',
                              value: _fmtDate(p.expiryDate),
                              color: sub,
                              tc: expired
                                  ? AppColors.expense
                                  : nearExpiry
                                  ? AppColors.lend
                                  : tc,
                            ),
                          ),
                        ],
                      ),
                      // Expiry progress bar
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: expired
                              ? 1.0
                              : (1 - daysLeft / 365).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: statusColor.withOpacity(0.12),
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fmtDate(p.startDate),
                            style: TextStyle(
                              fontSize: 9,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                          Text(
                            expired
                                ? 'Expired ${-daysLeft}d ago'
                                : '$daysLeft days left',
                            style: TextStyle(
                              fontSize: 9,
                              fontFamily: 'Nunito',
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _fmtDate(p.expiryDate),
                            style: TextStyle(
                              fontSize: 9,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _fmtDate(DateTime d) {
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

class _InsCell extends StatelessWidget {
  final String label, value;
  final Color color, tc;
  const _InsCell({
    required this.label,
    required this.value,
    required this.color,
    required this.tc,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: color),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          fontFamily: 'DM Mono',
          color: tc,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB: SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class _ServiceTab extends StatefulWidget {
  final VehicleModel vehicle;
  final bool isDark;
  final VoidCallback onUpdate;
  const _ServiceTab({
    required this.vehicle,
    required this.isDark,
    required this.onUpdate,
  });
  @override
  State<_ServiceTab> createState() => _ServiceTabState();
}

class _ServiceTabState extends State<_ServiceTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final v = widget.vehicle;

    if (v.services.isEmpty) {
      return const LifeEmptyState(
        emoji: '🔧',
        title: 'No service records',
        subtitle: 'Tap + to log a service or maintenance visit',
      );
    }

    // Sort newest first
    final sorted = [...v.services]
      ..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: sorted.map((s) {
        final nextDueSoon =
            s.nextDue != null &&
            s.nextDue!.difference(DateTime.now()).inDays <= 30;

        return Dismissible(
          key: ValueKey(s.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.expense.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.expense,
              size: 24,
            ),
          ),
          onDismissed: (_) => setState(() {
            v.services.remove(s);
            widget.onUpdate();
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _garageColor.withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _garageColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🔧', style: TextStyle(fontSize: 24)),
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: AppColors.subLight,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            s.garage,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 11,
                            color: AppColors.subLight,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _fmtDate(s.serviceDate),
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                      if (s.notes != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          s.notes!,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: sub,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (s.nextDue != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: nextDueSoon
                                ? AppColors.lend.withOpacity(0.12)
                                : AppColors.income.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_available_rounded,
                                size: 12,
                                color: nextDueSoon
                                    ? AppColors.lend
                                    : AppColors.income,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Next due: ${_fmtDate(s.nextDue!)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: nextDueSoon
                                      ? AppColors.lend
                                      : AppColors.income,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
        );
      }).toList(),
    );
  }

  String _fmtDate(DateTime d) {
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

// ─────────────────────────────────────────────────────────────────────────────
// TAB: REPAIRS
// ─────────────────────────────────────────────────────────────────────────────

class _RepairTab extends StatefulWidget {
  final VehicleModel vehicle;
  final bool isDark;
  final VoidCallback onUpdate;
  const _RepairTab({
    required this.vehicle,
    required this.isDark,
    required this.onUpdate,
  });
  @override
  State<_RepairTab> createState() => _RepairTabState();
}

class _RepairTabState extends State<_RepairTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final v = widget.vehicle;

    if (v.repairs.isEmpty) {
      return const LifeEmptyState(
        emoji: '🔩',
        title: 'No repair tasks',
        subtitle: 'Tap + to log a repair or planned work',
      );
    }

    final pending = v.repairs.where((r) => !r.done).toList();
    final completed = v.repairs.where((r) => r.done).toList();

    Widget repairCard(RepairTask r) {
      final overdue =
          r.plannedDate != null &&
          r.plannedDate!.isBefore(DateTime.now()) &&
          !r.done;

      return Dismissible(
        key: ValueKey(r.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.expense.withOpacity(0.15),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.expense,
            size: 24,
          ),
        ),
        onDismissed: (_) => setState(() {
          v.repairs.remove(r);
          widget.onUpdate();
        }),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: r.done
                  ? AppColors.income.withOpacity(0.2)
                  : overdue
                  ? AppColors.expense.withOpacity(0.25)
                  : AppColors.lend.withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  r.done = !r.done;
                  widget.onUpdate();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: r.done
                        ? AppColors.income.withOpacity(0.15)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: r.done ? AppColors.income : AppColors.lend,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: r.done
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: AppColors.income,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
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
                        decoration: r.done ? TextDecoration.lineThrough : null,
                        decorationColor: tc,
                      ),
                    ),
                    if (r.notes != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        r.notes!,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ],
                    if (r.plannedDate != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.event_rounded,
                            size: 11,
                            color: overdue ? AppColors.expense : sub,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _fmtDate(r.plannedDate!),
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Nunito',
                              color: overdue ? AppColors.expense : sub,
                              fontWeight: overdue
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          if (overdue) ...[
                            const SizedBox(width: 6),
                            LifeBadge(
                              text: 'Overdue',
                              color: AppColors.expense,
                            ),
                          ],
                        ],
                      ),
                    ],
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
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (pending.isNotEmpty) ...[
          Row(
            children: [
              const Text('🔩', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(
                'Pending  (${pending.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                  color: AppColors.lend,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...pending.map(repairCard),
        ],
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('✅', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(
                'Completed  (${completed.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                  color: AppColors.income,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...completed.map(repairCard),
        ],
      ],
    );
  }

  String _fmtDate(DateTime d) {
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

// ─────────────────────────────────────────────────────────────────────────────
// SHARED
// ─────────────────────────────────────────────────────────────────────────────

class _Fab extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Fab(this.label, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
    onPressed: onTap,
    backgroundColor: color,
    icon: Icon(icon, color: Colors.white, size: 18),
    label: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontFamily: 'Nunito',
      ),
    ),
  );
}
