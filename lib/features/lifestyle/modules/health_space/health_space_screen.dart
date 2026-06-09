import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/health/health_models.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import 'package:wai_life_assistant/data/services/health_service.dart';
import '../../widgets/life_widgets.dart';

const _healthColor = Color(0xFF00BFA5);

// ── Date helpers ──────────────────────────────────────────────────────────────
final _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _fmtDate(DateTime d) => '${d.day} ${_months[d.month]} ${d.year}';
String _fmtDateShort(DateTime d) => '${d.day} ${_months[d.month]}';

Future<DateTime?> _pickDate(BuildContext ctx, {DateTime? initial}) => showDatePicker(
      context: ctx,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

Future<String?> _pickPhoto(BuildContext ctx) async {
  ImageSource? src;
  await showModalBottomSheet<void>(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (c) {
      final isDark = Theme.of(c).brightness == Brightness.dark;
      return Material(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            ListTile(leading: const Icon(Icons.camera_alt_rounded, color: _healthColor), title: const Text('Take Photo', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)), onTap: () { src = ImageSource.camera; Navigator.pop(c); }),
            ListTile(leading: const Icon(Icons.photo_library_rounded, color: _healthColor), title: const Text('Choose from Gallery', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)), onTap: () { src = ImageSource.gallery; Navigator.pop(c); }),
            const SizedBox(height: 8),
          ]),
        ),
      );
    },
  );
  if (src == null) return null;
  final img = await ImagePicker().pickImage(source: src!, imageQuality: 75);
  return img?.path;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class HealthSpaceScreen extends StatefulWidget {
  final String walletId;
  final List<LifeMember> members;
  const HealthSpaceScreen({super.key, required this.walletId, required this.members});
  @override
  State<HealthSpaceScreen> createState() => _HealthSpaceScreenState();
}

class _HealthSpaceScreenState extends State<HealthSpaceScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  late String _selectedMember;
  bool _loading = true;

  HealthProfile? _profile;
  List<Medication> _medications = [];
  List<DoctorRecord> _doctors = [];
  List<MedicalDocument> _documents = [];
  List<Appointment> _appointments = [];
  List<HealthVital> _vitals = [];
  List<Vaccination> _vaccinations = [];
  List<InsurancePolicy> _insurance = [];

  static const _tabs = ['👤', '💊', '🩺', '📋', '📅', '🔬', '💉', '🏥', '🚨'];
  static const _tabLabels = ['Profile', 'Meds', 'Doctors', 'Docs', 'Appts', 'Vitals', 'Vaccines', 'Insurance', 'Emergency'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _selectedMember = widget.members.first.id;
    _loadData();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final svc = HealthService.instance;
      final wid = widget.walletId;
      final results = await Future.wait([
        svc.fetchProfile(wid, _selectedMember),
        svc.fetchMedications(wid),
        svc.fetchDoctors(wid),
        svc.fetchDocuments(wid),
        svc.fetchAppointments(wid),
        svc.fetchVitals(wid),
        svc.fetchVaccinations(wid),
        svc.fetchInsurance(wid),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as HealthProfile?;
        _medications = (results[1] as List).map((r) => Medication.fromJson(r as Map<String, dynamic>)).toList();
        _doctors = (results[2] as List).map((r) => DoctorRecord.fromJson(r as Map<String, dynamic>)).toList();
        _documents = (results[3] as List).map((r) => MedicalDocument.fromJson(r as Map<String, dynamic>)).toList();
        _appointments = (results[4] as List).map((r) => Appointment.fromJson(r as Map<String, dynamic>)).toList();
        _vitals = (results[5] as List).map((r) => HealthVital.fromJson(r as Map<String, dynamic>)).toList();
        _vaccinations = (results[6] as List).map((r) => Vaccination.fromJson(r as Map<String, dynamic>)).toList();
        _insurance = (results[7] as List).map((r) => InsurancePolicy.fromJson(r as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('[HealthSpace] loadData error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadProfile() async {
    final p = await HealthService.instance.fetchProfile(widget.walletId, _selectedMember);
    if (mounted) setState(() => _profile = p);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
        title: Text('Health Space', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: textColor)),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: _healthColor,
          labelColor: _healthColor,
          unselectedLabelColor: isDark ? AppColors.subDark : AppColors.subLight,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Nunito'),
          tabs: List.generate(_tabs.length, (i) => Tab(text: '${_tabs[i]} ${_tabLabels[i]}')),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _healthColor))
          : RefreshIndicator(
              color: _healthColor,
              onRefresh: _loadData,
              child: Column(children: [
                // ── Member chips ───────────────────────────────────────────
                if (widget.members.length > 1)
                  _MemberChips(
                    members: widget.members,
                    selected: _selectedMember,
                    onSelect: (id) { setState(() => _selectedMember = id); _loadData(); },
                    isDark: isDark,
                  ),
                Expanded(
                  child: TabBarView(controller: _tab, children: [
                    _ProfileTab(walletId: widget.walletId, memberId: _selectedMember, profile: _profile, isDark: isDark, surfBg: surfBg, onSaved: _reloadProfile),
                    _MedicationsTab(walletId: widget.walletId, memberId: _selectedMember, meds: _medications.where((m) => m.memberId == _selectedMember).toList(), isDark: isDark, surfBg: surfBg,
                      onAdd: (m) => setState(() => _medications.insert(0, m)),
                      onDelete: (id) => setState(() => _medications.removeWhere((m) => m.id == id)),
                      onToggle: (m) => setState(() { final i = _medications.indexWhere((x) => x.id == m.id); if (i >= 0) _medications[i] = m; }),
                    ),
                    _DoctorsTab(walletId: widget.walletId, memberId: _selectedMember, doctors: _doctors.where((d) => d.memberId == _selectedMember).toList(), isDark: isDark, surfBg: surfBg,
                      onAdd: (d) => setState(() => _doctors.add(d)),
                      onDelete: (id) => setState(() => _doctors.removeWhere((d) => d.id == id)),
                    ),
                    _DocumentsTab(walletId: widget.walletId, memberId: _selectedMember, docs: _documents.where((d) => d.memberId == _selectedMember).toList(), isDark: isDark, surfBg: surfBg,
                      onAdd: (d) => setState(() => _documents.insert(0, d)),
                      onDelete: (id) => setState(() => _documents.removeWhere((d) => d.id == id)),
                    ),
                    _AppointmentsTab(walletId: widget.walletId, memberId: _selectedMember, appointments: _appointments.where((a) => a.memberId == _selectedMember).toList(), isDark: isDark, surfBg: surfBg,
                      onAdd: (a) => setState(() => _appointments.insert(0, a)),
                      onDelete: (id) => setState(() => _appointments.removeWhere((a) => a.id == id)),
                    ),
                    _VitalsTab(walletId: widget.walletId, memberId: _selectedMember, vitals: _vitals.where((v) => v.memberId == _selectedMember).toList(), isDark: isDark, surfBg: surfBg,
                      onAdd: (v) => setState(() => _vitals.insert(0, v)),
                      onDelete: (id) => setState(() => _vitals.removeWhere((v) => v.id == id)),
                    ),
                    _VaccinesTab(walletId: widget.walletId, memberId: _selectedMember, vaccinations: _vaccinations.where((v) => v.memberId == _selectedMember).toList(), isDark: isDark, surfBg: surfBg,
                      onAdd: (v) => setState(() => _vaccinations.insert(0, v)),
                      onDelete: (id) => setState(() => _vaccinations.removeWhere((v) => v.id == id)),
                    ),
                    _InsuranceTab(walletId: widget.walletId, memberId: _selectedMember, policies: _insurance.where((p) => p.memberId == _selectedMember).toList(), isDark: isDark, surfBg: surfBg,
                      onAdd: (p) => setState(() => _insurance.insert(0, p)),
                      onDelete: (id) => setState(() => _insurance.removeWhere((p) => p.id == id)),
                    ),
                    _EmergencyTab(profile: _profile, memberId: _selectedMember, members: widget.members, meds: _medications.where((m) => m.memberId == _selectedMember && m.isActive).toList(), isDark: isDark),
                  ]),
                ),
              ]),
            ),
    );
  }
}

// ── Member chips ──────────────────────────────────────────────────────────────
class _MemberChips extends StatelessWidget {
  final List<LifeMember> members;
  final String selected;
  final void Function(String) onSelect;
  final bool isDark;
  const _MemberChips({required this.members, required this.selected, required this.onSelect, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
        for (final m in members)
          GestureDetector(
            onTap: () => onSelect(m.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected == m.id ? _healthColor.withValues(alpha: 0.15) : (isDark ? AppColors.surfDark : const Color(0xFFEDEEF5)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected == m.id ? _healthColor : Colors.transparent),
              ),
              child: Text('${m.emoji} ${m.name}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: selected == m.id ? _healthColor : (isDark ? AppColors.subDark : AppColors.subLight))),
            ),
          ),
      ]),
      ),
    );
  }
}

// ── Info row helper ───────────────────────────────────────────────────────────
Widget _infoRow(BuildContext context, IconData icon, String label, String value, {Color? color}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final tc  = isDark ? AppColors.textDark  : AppColors.textLight;
  final sub = isDark ? AppColors.subDark   : AppColors.subLight;
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color ?? _healthColor),
      const SizedBox(width: 8),
      Expanded(child: RichText(text: TextSpan(children: [
        TextSpan(text: '$label  ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: sub)),
        TextSpan(text: value, style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: color ?? tc)),
      ]))),
    ]),
  );
}

Widget _chip(String text, Color color) => Container(
  margin: const EdgeInsets.only(right: 6, bottom: 6),
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.4))),
  child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: color)),
);

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  final String walletId, memberId;
  final HealthProfile? profile;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onSaved;
  const _ProfileTab({required this.walletId, required this.memberId, required this.profile, required this.isDark, required this.surfBg, required this.onSaved});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _healthColor.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: const Text('🩺', style: TextStyle(fontSize: 24))),
            const SizedBox(width: 12),
            Expanded(child: Text('Health Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: isDark ? AppColors.textDark : AppColors.textLight))),
            IconButton(icon: Icon(Icons.edit_rounded, color: _healthColor, size: 20), onPressed: () => _showEditProfile(context, p)),
          ]),
          const Divider(height: 20),
          if (p == null)
            Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(children: [
              const Text('🏥', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('No profile yet', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: isDark ? AppColors.subDark : AppColors.subLight)),
              const SizedBox(height: 4),
              TextButton(onPressed: () => _showEditProfile(context, null), child: const Text('Add Profile', style: TextStyle(color: _healthColor, fontFamily: 'Nunito', fontWeight: FontWeight.w800))),
            ])))
          else ...[
            if (p.bloodGroup != null) _infoRow(context, Icons.water_drop_rounded, 'Blood Group', p.bloodGroup!),
            if (p.height != null) _infoRow(context, Icons.height_rounded, 'Height', p.height!),
            if (p.weight != null) _infoRow(context, Icons.monitor_weight_rounded, 'Weight', p.weight!),
            if (p.bloodGroup != null && p.height != null && p.weight != null) ...[
              () {
                final h = double.tryParse(p.height!.replaceAll(RegExp(r'[^0-9.]'), ''));
                final w = double.tryParse(p.weight!.replaceAll(RegExp(r'[^0-9.]'), ''));
                if (h != null && w != null && h > 0) {
                  final hm = h > 10 ? h / 100 : h;
                  final bmi = w / (hm * hm);
                  final label = bmi < 18.5 ? 'Underweight' : bmi < 25 ? 'Normal' : bmi < 30 ? 'Overweight' : 'Obese';
                  final col = bmi < 18.5 ? Colors.blue : bmi < 25 ? Colors.green : bmi < 30 ? Colors.orange : Colors.red;
                  return _infoRow(context, Icons.calculate_rounded, 'BMI', '${bmi.toStringAsFixed(1)} ($label)', color: col);
                }
                return const SizedBox.shrink();
              }(),
            ],
            if (p.allergies.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('⚠️ Allergies', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: Colors.orange)),
              const SizedBox(height: 4),
              Wrap(children: p.allergies.map((a) => _chip(a, Colors.orange)).toList()),
            ],
            if (p.conditions.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('🩺 Conditions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: Colors.red)),
              const SizedBox(height: 4),
              Wrap(children: p.conditions.map((c) => _chip(c, Colors.red)).toList()),
            ],
            if (p.disabilities.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('♿ Special Needs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: _healthColor)),
              const SizedBox(height: 4),
              Wrap(children: p.disabilities.map((d) => _chip(d, _healthColor)).toList()),
            ],
            if (p.emergencyContact != null) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 4),
              _infoRow(context, Icons.emergency_rounded, 'Emergency Contact', p.emergencyContact!, color: Colors.red),
              if (p.emergencyPhone != null) _infoRow(context, Icons.phone_rounded, 'Phone', p.emergencyPhone!, color: Colors.red),
            ],
          ],
        ]),
      ),
    ]);
  }

  void _showEditProfile(BuildContext ctx, HealthProfile? existing) {
    final bgCtrl = TextEditingController(text: existing?.bloodGroup);
    final htCtrl = TextEditingController(text: existing?.height);
    final wtCtrl = TextEditingController(text: existing?.weight);
    final ecCtrl = TextEditingController(text: existing?.emergencyContact);
    final epCtrl = TextEditingController(text: existing?.emergencyPhone);
    final allergiesRef = <List<String>>[List.from(existing?.allergies ?? [])];
    final conditionsRef = <List<String>>[List.from(existing?.conditions ?? [])];
    final disabilitiesRef = <List<String>>[List.from(existing?.disabilities ?? [])];
    final allergyCtrl = TextEditingController();
    final condCtrl = TextEditingController();
    final disCtrl = TextEditingController();

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) {
      void addItem(List<String> list, TextEditingController ctrl) {
        final v = ctrl.text.trim();
        if (v.isEmpty) return;
        ss(() { list.add(v); ctrl.clear(); });
      }

      Widget chipList(List<String> list, Color col) => Wrap(children: [
        for (int i = 0; i < list.length; i++)
          GestureDetector(
            onTap: () => ss(() => list.removeAt(i)),
            child: Container(
              margin: const EdgeInsets.only(right: 6, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: col.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: col.withValues(alpha: 0.4))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(list[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: col)),
                const SizedBox(width: 4),
                Icon(Icons.close, size: 12, color: col),
              ]),
            ),
          ),
      ]);

      return Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 36), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Edit Health Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: LifeInput(controller: bgCtrl, hint: 'Blood Group (e.g. O+)')),
          const SizedBox(width: 8),
          Expanded(child: LifeInput(controller: htCtrl, hint: 'Height (cm)')),
          const SizedBox(width: 8),
          Expanded(child: LifeInput(controller: wtCtrl, hint: 'Weight (kg)')),
        ]),
        const SizedBox(height: 8),
        const LifeLabel(text: 'ALLERGIES'),
        chipList(allergiesRef[0], Colors.orange),
        Row(children: [Expanded(child: LifeInput(controller: allergyCtrl, hint: 'Add allergy...')), const SizedBox(width: 8), GestureDetector(onTap: () => addItem(allergiesRef[0], allergyCtrl), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add, color: Colors.orange, size: 20)))]),
        const SizedBox(height: 8),
        const LifeLabel(text: 'CONDITIONS'),
        chipList(conditionsRef[0], Colors.red),
        Row(children: [Expanded(child: LifeInput(controller: condCtrl, hint: 'Add condition...')), const SizedBox(width: 8), GestureDetector(onTap: () => addItem(conditionsRef[0], condCtrl), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add, color: Colors.red, size: 20)))]),
        const SizedBox(height: 8),
        const LifeLabel(text: 'SPECIAL NEEDS / DISABILITIES'),
        chipList(disabilitiesRef[0], _healthColor),
        Row(children: [Expanded(child: LifeInput(controller: disCtrl, hint: 'Add...')), const SizedBox(width: 8), GestureDetector(onTap: () => addItem(disabilitiesRef[0], disCtrl), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add, color: _healthColor, size: 20)))]),
        const SizedBox(height: 8),
        const LifeLabel(text: 'EMERGENCY CONTACT'),
        LifeInput(controller: ecCtrl, hint: 'Contact name'),
        const SizedBox(height: 8),
        LifeInput(controller: epCtrl, hint: 'Phone number', inputType: TextInputType.phone),
        LifeSaveButton(label: 'Save Profile', color: _healthColor, onTap: () {
          Navigator.pop(ctx2);
          () async {
            try {
              final p = HealthProfile(
                id: existing?.id ?? '',
                walletId: walletId,
                memberId: memberId,
                bloodGroup: bgCtrl.text.trim().isEmpty ? null : bgCtrl.text.trim(),
                height: htCtrl.text.trim().isEmpty ? null : htCtrl.text.trim(),
                weight: wtCtrl.text.trim().isEmpty ? null : wtCtrl.text.trim(),
                emergencyContact: ecCtrl.text.trim().isEmpty ? null : ecCtrl.text.trim(),
                emergencyPhone: epCtrl.text.trim().isEmpty ? null : epCtrl.text.trim(),
                allergies: allergiesRef[0],
                conditions: conditionsRef[0],
                disabilities: disabilitiesRef[0],
              );
              await HealthService.instance.upsertProfile(p);
              onSaved();
            } catch (e) {
              debugPrint('[Health] upsertProfile: $e');
            }
          }();
        }),
      ]));
    }));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDICATIONS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _MedicationsTab extends StatelessWidget {
  final String walletId, memberId;
  final List<Medication> meds;
  final bool isDark;
  final Color surfBg;
  final void Function(Medication) onAdd;
  final void Function(String) onDelete;
  final void Function(Medication) onToggle;
  const _MedicationsTab({required this.walletId, required this.memberId, required this.meds, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final active = meds.where((m) => m.isActive).toList();
    final past = meds.where((m) => !m.isActive).toList();
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _healthColor,
        onPressed: () => _showAddMed(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Medicine', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: meds.isEmpty
          ? const LifeEmptyState(emoji: '💊', title: 'No medications yet', subtitle: 'Track current and past medications')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              if (active.isNotEmpty) ...[
                const LifeLabel(text: 'ACTIVE MEDICATIONS'),
                ...active.map((m) => _MedCard(m: m, cardBg: cardBg, isDark: isDark, onDelete: () => onDelete(m.id), onToggle: () async {
                  try {
                    await HealthService.instance.updateMedication(m.id, {'is_active': false});
                    onToggle(Medication(id: m.id, walletId: m.walletId, memberId: m.memberId, name: m.name, dosage: m.dosage, frequency: m.frequency, timing: m.timing, notes: m.notes, isActive: false, startDate: m.startDate, endDate: m.endDate, refillDate: m.refillDate));
                  } catch (e) { debugPrint('[Health] toggleMed: $e'); }
                })),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 8),
                const LifeLabel(text: 'PAST MEDICATIONS'),
                ...past.map((m) => _MedCard(m: m, cardBg: cardBg, isDark: isDark, onDelete: () => onDelete(m.id), onToggle: () async {
                  try {
                    await HealthService.instance.updateMedication(m.id, {'is_active': true});
                    onToggle(Medication(id: m.id, walletId: m.walletId, memberId: m.memberId, name: m.name, dosage: m.dosage, frequency: m.frequency, timing: m.timing, notes: m.notes, isActive: true, startDate: m.startDate, endDate: m.endDate, refillDate: m.refillDate));
                  } catch (e) { debugPrint('[Health] toggleMed: $e'); }
                })),
              ],
            ]),
    );
  }

  void _showAddMed(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final freqCtrl = TextEditingController();
    final timingCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final startRef = <DateTime>[DateTime.now()];
    final refillRef = <DateTime?>[ null];

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Add Medication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
        const SizedBox(height: 12),
        LifeInput(controller: nameCtrl, hint: 'Medicine name *'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: LifeInput(controller: dosageCtrl, hint: 'Dosage (e.g. 500mg)')),
          const SizedBox(width: 8),
          Expanded(child: LifeInput(controller: freqCtrl, hint: 'Frequency (e.g. Twice daily)')),
        ]),
        const SizedBox(height: 8),
        LifeInput(controller: timingCtrl, hint: 'Timing (e.g. After meals)'),
        const SizedBox(height: 8),
        LifeInput(controller: notesCtrl, hint: 'Notes (optional)', maxLines: 2),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: LifeDateTile(date: startRef[0], hint: 'Start Date', color: _healthColor, onTap: () async { final d = await _pickDate(ctx2, initial: startRef[0]); if (d != null) ss(() => startRef[0] = d); })),
          const SizedBox(width: 8),
          Expanded(child: LifeDateTile(date: refillRef[0], hint: 'Refill Date', color: Colors.orange, onTap: () async { final d = await _pickDate(ctx2); if (d != null) ss(() => refillRef[0] = d); })),
        ]),
        LifeSaveButton(label: 'Save', color: _healthColor, onTap: () {
          if (nameCtrl.text.trim().isEmpty || dosageCtrl.text.trim().isEmpty || freqCtrl.text.trim().isEmpty) return;
          final name = nameCtrl.text.trim();
          final dosage = dosageCtrl.text.trim();
          final freq = freqCtrl.text.trim();
          final timing = timingCtrl.text.trim().isEmpty ? null : timingCtrl.text.trim();
          final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
          final start = startRef[0];
          final refill = refillRef[0];
          Navigator.pop(ctx2);
          () async {
            try {
              final data = Medication(id: '', walletId: walletId, memberId: memberId, name: name, dosage: dosage, frequency: freq, timing: timing, notes: notes, startDate: start, refillDate: refill);
              final row = await HealthService.instance.addMedication(data.toJson());
              onAdd(Medication.fromJson(row));
            } catch (e) { debugPrint('[Health] addMed: $e'); }
          }();
        }),
      ]),
    )));
  }
}

class _MedCard extends StatelessWidget {
  final Medication m;
  final Color cardBg;
  final bool isDark;
  final VoidCallback onDelete, onToggle;
  const _MedCard({required this.m, required this.cardBg, required this.isDark, required this.onDelete, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Dismissible(
      key: ValueKey(m.id),
      direction: DismissDirection.endToStart,
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.delete_rounded, color: Colors.red)),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: m.isActive ? _healthColor.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2))),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: (m.isActive ? _healthColor : Colors.grey).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: const Text('💊', style: TextStyle(fontSize: 20))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: isDark ? AppColors.textDark : AppColors.textLight)),
            Text('${m.dosage}  ·  ${m.frequency}', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub)),
            if (m.timing != null) Text(m.timing!, style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
            if (m.refillDate != null) Row(children: [const Icon(Icons.refresh_rounded, size: 12, color: Colors.orange), const SizedBox(width: 4), Text('Refill: ${_fmtDate(m.refillDate!)}', style: const TextStyle(fontSize: 11, fontFamily: 'Nunito', color: Colors.orange))]),
          ])),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: (m.isActive ? _healthColor : Colors.grey).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Text(m.isActive ? 'Active' : 'Past', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: m.isActive ? _healthColor : Colors.grey)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCTORS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _DoctorsTab extends StatelessWidget {
  final String walletId, memberId;
  final List<DoctorRecord> doctors;
  final bool isDark;
  final Color surfBg;
  final void Function(DoctorRecord) onAdd;
  final void Function(String) onDelete;
  const _DoctorsTab({required this.walletId, required this.memberId, required this.doctors, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _healthColor,
        onPressed: () => _showAdd(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Doctor', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: doctors.isEmpty
          ? const LifeEmptyState(emoji: '🩺', title: 'No doctors added', subtitle: 'Save your doctors and specialists here')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              for (final d in doctors)
                Dismissible(
                  key: ValueKey(d.id),
                  direction: DismissDirection.endToStart,
                  background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.delete_rounded, color: Colors.red)),
                  onDismissed: (_) async {
                    try { await HealthService.instance.deleteDoctor(d.id); onDelete(d.id); } catch (e) { debugPrint('[Health] deleteDoctor: $e'); }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _healthColor.withValues(alpha: 0.2))),
                    child: Row(children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: const Text('👨‍⚕️', style: TextStyle(fontSize: 24))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Dr. ${d.name}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: isDark ? AppColors.textDark : AppColors.textLight)),
                        if (d.specialty != null) Text(d.specialty!, style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: _healthColor)),
                        if (d.hospital != null) Text(d.hospital!, style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: isDark ? AppColors.subDark : AppColors.subLight)),
                        if (d.phone != null) Row(children: [const Icon(Icons.phone_rounded, size: 12, color: _healthColor), const SizedBox(width: 4), Text(d.phone!, style: const TextStyle(fontSize: 11, fontFamily: 'Nunito', color: _healthColor))]),
                      ])),
                    ]),
                  ),
                ),
            ]),
    );
  }

  void _showAdd(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final hospCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    showLifeSheet(ctx, child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 36), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Text('Add Doctor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
      const SizedBox(height: 12),
      LifeInput(controller: nameCtrl, hint: 'Doctor name *'),
      const SizedBox(height: 8),
      LifeInput(controller: specCtrl, hint: 'Specialty (e.g. Cardiologist)'),
      const SizedBox(height: 8),
      LifeInput(controller: hospCtrl, hint: 'Hospital / Clinic'),
      const SizedBox(height: 8),
      LifeInput(controller: phoneCtrl, hint: 'Phone number', inputType: TextInputType.phone),
      const SizedBox(height: 8),
      LifeInput(controller: notesCtrl, hint: 'Notes', maxLines: 2),
      LifeSaveButton(label: 'Save', color: _healthColor, onTap: () {
        if (nameCtrl.text.trim().isEmpty) return;
        final data = DoctorRecord(id: '', walletId: walletId, memberId: memberId, name: nameCtrl.text.trim(), specialty: specCtrl.text.trim().isEmpty ? null : specCtrl.text.trim(), hospital: hospCtrl.text.trim().isEmpty ? null : hospCtrl.text.trim(), phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(), notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
        Navigator.pop(ctx);
        () async { try { final row = await HealthService.instance.addDoctor(data.toJson()); onAdd(DoctorRecord.fromJson(row)); } catch (e) { debugPrint('[Health] addDoctor: $e'); } }();
      }),
    ])));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCUMENTS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _DocumentsTab extends StatelessWidget {
  final String walletId, memberId;
  final List<MedicalDocument> docs;
  final bool isDark;
  final Color surfBg;
  final void Function(MedicalDocument) onAdd;
  final void Function(String) onDelete;
  const _DocumentsTab({required this.walletId, required this.memberId, required this.docs, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _healthColor,
        onPressed: () => _showAdd(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Document', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: docs.isEmpty
          ? const LifeEmptyState(emoji: '📋', title: 'No documents yet', subtitle: 'Upload prescriptions, lab reports and more')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              for (final d in docs)
                Dismissible(
                  key: ValueKey(d.id),
                  direction: DismissDirection.endToStart,
                  background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.delete_rounded, color: Colors.red)),
                  onDismissed: (_) async {
                    try { await HealthService.instance.deleteDocument(d.id, d.fileUrl); onDelete(d.id); } catch (e) { debugPrint('[Health] deleteDoc: $e'); }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _healthColor.withValues(alpha: 0.2))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (d.fileUrl != null)
                        ClipRRect(borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
                          child: d.fileUrl!.endsWith('.pdf')
                              ? Container(width: 72, height: 72, color: Colors.red.withValues(alpha: 0.1), alignment: Alignment.center, child: const Text('📄', style: TextStyle(fontSize: 30)))
                              : Image.network(d.fileUrl!, width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, a, e) => Container(width: 72, height: 72, color: _healthColor.withValues(alpha: 0.1), alignment: Alignment.center, child: Text(d.docType.emoji, style: const TextStyle(fontSize: 30))))),
                      Expanded(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Text('${d.docType.emoji} ${d.docType.label}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: _healthColor))),
                        ]),
                        const SizedBox(height: 4),
                        Text(d.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: isDark ? AppColors.textDark : AppColors.textLight)),
                        Text(_fmtDate(d.docDate), style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: isDark ? AppColors.subDark : AppColors.subLight)),
                        if (d.notes != null) Text(d.notes!, style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: isDark ? AppColors.subDark : AppColors.subLight)),
                      ]))),
                    ]),
                  ),
                ),
            ]),
    );
  }

  void _showAdd(BuildContext ctx) {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final typeRef = <MedDocType>[MedDocType.prescription];
    final dateRef = <DateTime>[DateTime.now()];
    final pathRef = <String?>[null];

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Add Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
        const SizedBox(height: 12),
        const LifeLabel(text: 'TYPE'),
        SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final t in MedDocType.values)
            GestureDetector(
              onTap: () { typeRef[0] = t; ss(() {}); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: typeRef[0] == t ? _healthColor.withValues(alpha: 0.15) : (ctx2.isDark ? AppColors.surfDark : const Color(0xFFEDEEF5)), borderRadius: BorderRadius.circular(20), border: Border.all(color: typeRef[0] == t ? _healthColor : Colors.transparent)),
                child: Text('${t.emoji} ${t.label}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: typeRef[0] == t ? _healthColor : (ctx2.isDark ? AppColors.subDark : AppColors.subLight))),
              ),
            ),
        ])),
        const SizedBox(height: 8),
        LifeInput(controller: titleCtrl, hint: 'Title *'),
        const SizedBox(height: 8),
        LifeDateTile(date: dateRef[0], hint: 'Document Date', color: _healthColor, onTap: () async { final d = await _pickDate(ctx2, initial: dateRef[0]); if (d != null) ss(() => dateRef[0] = d); }),
        const SizedBox(height: 8),
        LifeInput(controller: notesCtrl, hint: 'Notes', maxLines: 2),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async { final p = await _pickPhoto(ctx2); if (p != null) ss(() => pathRef[0] = p); },
          child: Container(
            height: 80, decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: _healthColor.withValues(alpha: 0.3), style: BorderStyle.solid)),
            child: pathRef[0] != null
                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(pathRef[0]!), fit: BoxFit.cover, width: double.infinity))
                : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_rounded, color: _healthColor.withValues(alpha: 0.6), size: 28), const SizedBox(height: 4), Text('Tap to attach photo', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: _healthColor.withValues(alpha: 0.7)))])),
          ),
        ),
        LifeSaveButton(label: 'Save', color: _healthColor, onTap: () {
          if (titleCtrl.text.trim().isEmpty) return;
          final title = titleCtrl.text.trim();
          final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
          final type = typeRef[0];
          final date = dateRef[0];
          final localPath = pathRef[0];
          Navigator.pop(ctx2);
          () async {
            try {
              String? fileUrl;
              if (localPath != null) fileUrl = await HealthService.instance.uploadDoc(localPath, memberId: memberId);
              final data = MedicalDocument(id: '', walletId: walletId, memberId: memberId, title: title, docType: type, fileUrl: fileUrl, notes: notes, docDate: date);
              final row = await HealthService.instance.addDocument(data.toJson());
              onAdd(MedicalDocument.fromJson(row));
            } catch (e) { debugPrint('[Health] addDoc: $e'); }
          }();
        }),
      ]),
    )));
  }
}

extension _CtxDark on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ─────────────────────────────────────────────────────────────────────────────
// APPOINTMENTS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _AppointmentsTab extends StatelessWidget {
  final String walletId, memberId;
  final List<Appointment> appointments;
  final bool isDark;
  final Color surfBg;
  final void Function(Appointment) onAdd;
  final void Function(String) onDelete;
  const _AppointmentsTab({required this.walletId, required this.memberId, required this.appointments, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final upcoming = appointments.where((a) => a.isUpcoming).toList()..sort((a, b) => a.apptDate.compareTo(b.apptDate));
    final past = appointments.where((a) => !a.isUpcoming).toList();
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _healthColor,
        onPressed: () => _showAdd(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Book Appointment', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: appointments.isEmpty
          ? const LifeEmptyState(emoji: '📅', title: 'No appointments', subtitle: 'Track upcoming and past doctor visits')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              if (upcoming.isNotEmpty) ...[
                const LifeLabel(text: 'UPCOMING'),
                ...upcoming.map((a) => _ApptCard(a: a, cardBg: cardBg, isDark: isDark, onDelete: () async { try { await HealthService.instance.deleteAppointment(a.id); onDelete(a.id); } catch (e) { debugPrint('[Health] deleteAppt: $e'); } })),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 8),
                const LifeLabel(text: 'PAST'),
                ...past.map((a) => _ApptCard(a: a, cardBg: cardBg, isDark: isDark, onDelete: () async { try { await HealthService.instance.deleteAppointment(a.id); onDelete(a.id); } catch (e) { debugPrint('[Health] deleteAppt: $e'); } })),
              ],
            ]),
    );
  }

  void _showAdd(BuildContext ctx) {
    final doctorCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final dateRef = <DateTime>[DateTime.now().add(const Duration(days: 1))];

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Book Appointment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
        const SizedBox(height: 12),
        LifeInput(controller: doctorCtrl, hint: 'Doctor / Hospital *'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: LifeDateTile(date: dateRef[0], hint: 'Date', color: _healthColor, onTap: () async { final d = await _pickDate(ctx2, initial: dateRef[0]); if (d != null) ss(() => dateRef[0] = d); })),
          const SizedBox(width: 8),
          Expanded(child: LifeInput(controller: timeCtrl, hint: 'Time (e.g. 10:30 AM)')),
        ]),
        const SizedBox(height: 8),
        LifeInput(controller: locationCtrl, hint: 'Location / Clinic'),
        const SizedBox(height: 8),
        LifeInput(controller: notesCtrl, hint: 'Notes', maxLines: 2),
        LifeSaveButton(label: 'Save', color: _healthColor, onTap: () {
          if (doctorCtrl.text.trim().isEmpty) return;
          final doctor = doctorCtrl.text.trim();
          final time = timeCtrl.text.trim().isEmpty ? null : timeCtrl.text.trim();
          final location = locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim();
          final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
          final date = dateRef[0];
          Navigator.pop(ctx2);
          () async {
            try {
              final data = Appointment(id: '', walletId: walletId, memberId: memberId, doctorName: doctor, apptDate: date, apptTime: time, location: location, notes: notes);
              final row = await HealthService.instance.addAppointment(data.toJson());
              onAdd(Appointment.fromJson(row));
            } catch (e) { debugPrint('[Health] addAppt: $e'); }
          }();
        }),
      ]),
    )));
  }
}

class _ApptCard extends StatelessWidget {
  final Appointment a;
  final Color cardBg;
  final bool isDark;
  final VoidCallback onDelete;
  const _ApptCard({required this.a, required this.cardBg, required this.isDark, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final daysUntil = a.apptDate.difference(DateTime.now()).inDays;
    final isToday = daysUntil == 0;
    final isTomorrow = daysUntil == 1;
    String badge = _fmtDateShort(a.apptDate);
    if (isToday) { badge = 'Today'; }
    else if (isTomorrow) { badge = 'Tomorrow'; }
    final badgeColor = isToday ? Colors.red : isTomorrow ? Colors.orange : _healthColor;
    return Dismissible(
      key: ValueKey(a.id),
      direction: DismissDirection.endToStart,
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.delete_rounded, color: Colors.red)),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: a.isUpcoming ? _healthColor.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2))),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_fmtDateShort(a.apptDate).split(' ')[0], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: badgeColor)), Text(_fmtDateShort(a.apptDate).split(' ').length > 1 ? _fmtDateShort(a.apptDate).split(' ')[1] : '', style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: badgeColor))])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.doctorName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: isDark ? AppColors.textDark : AppColors.textLight)),
            if (a.apptTime != null) Text(a.apptTime!, style: const TextStyle(fontSize: 12, fontFamily: 'Nunito', color: _healthColor)),
            if (a.location != null) Row(children: [Icon(Icons.location_on_rounded, size: 12, color: isDark ? AppColors.subDark : AppColors.subLight), const SizedBox(width: 4), Expanded(child: Text(a.location!, style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: isDark ? AppColors.subDark : AppColors.subLight), overflow: TextOverflow.ellipsis))]),
          ])),
          if (a.isUpcoming) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: badgeColor))),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VITALS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _VitalsTab extends StatefulWidget {
  final String walletId, memberId;
  final List<HealthVital> vitals;
  final bool isDark;
  final Color surfBg;
  final void Function(HealthVital) onAdd;
  final void Function(String) onDelete;
  const _VitalsTab({required this.walletId, required this.memberId, required this.vitals, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete});
  @override
  State<_VitalsTab> createState() => _VitalsTabState();
}

class _VitalsTabState extends State<_VitalsTab> {
  VitalType _selected = VitalType.bloodPressure;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.vitals.where((v) => v.type == _selected).toList();
    final cardBg = widget.isDark ? AppColors.cardDark : AppColors.cardLight;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _healthColor,
        onPressed: () => _showAdd(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Log Vital', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: Column(children: [
        Container(
          color: widget.isDark ? AppColors.cardDark : AppColors.cardLight,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final t in VitalType.values)
              GestureDetector(
                onTap: () => setState(() => _selected = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _selected == t ? _healthColor.withValues(alpha: 0.15) : (widget.isDark ? AppColors.surfDark : const Color(0xFFEDEEF5)), borderRadius: BorderRadius.circular(20), border: Border.all(color: _selected == t ? _healthColor : Colors.transparent)),
                  child: Text('${t.emoji} ${t.label}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: _selected == t ? _healthColor : (widget.isDark ? AppColors.subDark : AppColors.subLight))),
                ),
              ),
          ])),
        ),
        Expanded(
          child: filtered.isEmpty
              ? LifeEmptyState(emoji: _selected.emoji, title: 'No ${_selected.label} logs', subtitle: 'Start tracking ${_selected.label.toLowerCase()}')
              : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
                  for (final v in filtered)
                    Dismissible(
                      key: ValueKey(v.id),
                      direction: DismissDirection.endToStart,
                      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.delete_rounded, color: Colors.red)),
                      onDismissed: (_) async { try { await HealthService.instance.deleteVital(v.id); widget.onDelete(v.id); } catch (e) { debugPrint('[Health] deleteVital: $e'); } },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _healthColor.withValues(alpha: 0.2))),
                        child: Row(children: [
                          Text(v.type.emoji, style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(v.displayValue, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: widget.isDark ? AppColors.textDark : AppColors.textLight)),
                            if (v.subType != null) Text(v.subType!, style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: _healthColor)),
                            if (v.notes != null) Text(v.notes!, style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: widget.isDark ? AppColors.subDark : AppColors.subLight)),
                          ])),
                          Text('${_fmtDateShort(v.recordedAt)}\n${v.recordedAt.hour.toString().padLeft(2, '0')}:${v.recordedAt.minute.toString().padLeft(2, '0')}', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: widget.isDark ? AppColors.subDark : AppColors.subLight)),
                        ]),
                      ),
                    ),
                ]),
        ),
      ]),
    );
  }

  void _showAdd(BuildContext ctx) {
    final v1Ctrl = TextEditingController();
    final v2Ctrl = TextEditingController();
    final subCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final typeRef = <VitalType>[_selected];

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Log Vital', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
        const SizedBox(height: 12),
        const LifeLabel(text: 'TYPE'),
        SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final t in VitalType.values)
            GestureDetector(
              onTap: () { typeRef[0] = t; ss(() {}); },
              child: AnimatedContainer(duration: const Duration(milliseconds: 120), margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: typeRef[0] == t ? _healthColor.withValues(alpha: 0.15) : (widget.isDark ? AppColors.surfDark : const Color(0xFFEDEEF5)), borderRadius: BorderRadius.circular(20), border: Border.all(color: typeRef[0] == t ? _healthColor : Colors.transparent)),
                child: Text('${t.emoji} ${t.label}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: typeRef[0] == t ? _healthColor : (widget.isDark ? AppColors.subDark : AppColors.subLight))),
              ),
            ),
        ])),
        const SizedBox(height: 8),
        if (typeRef[0] == VitalType.bloodPressure)
          Row(children: [
            Expanded(child: LifeInput(controller: v1Ctrl, hint: 'Systolic (e.g. 120)', inputType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
            const SizedBox(width: 8),
            Expanded(child: LifeInput(controller: v2Ctrl, hint: 'Diastolic (e.g. 80)', inputType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
          ])
        else
          Row(children: [
            Expanded(child: LifeInput(controller: v1Ctrl, hint: 'Value (${typeRef[0].unit})', inputType: const TextInputType.numberWithOptions(decimal: true))),
            if (typeRef[0] == VitalType.bloodSugar) ...[const SizedBox(width: 8), Expanded(child: LifeInput(controller: subCtrl, hint: 'Type (Fasting/Post-meal)'))],
          ]),
        const SizedBox(height: 8),
        LifeInput(controller: notesCtrl, hint: 'Notes', maxLines: 2),
        LifeSaveButton(label: 'Log', color: _healthColor, onTap: () {
          final v1 = double.tryParse(v1Ctrl.text.trim());
          if (v1 == null) return;
          final type = typeRef[0];
          final v2 = double.tryParse(v2Ctrl.text.trim());
          final sub = subCtrl.text.trim().isEmpty ? null : subCtrl.text.trim();
          final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
          Navigator.pop(ctx2);
          () async {
            try {
              final data = HealthVital(id: '', walletId: widget.walletId, memberId: widget.memberId, type: type, value: v1, value2: v2, subType: sub, notes: notes);
              final row = await HealthService.instance.addVital(data.toJson());
              widget.onAdd(HealthVital.fromJson(row));
            } catch (e) { debugPrint('[Health] addVital: $e'); }
          }();
        }),
      ]),
    )));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VACCINES TAB
// ─────────────────────────────────────────────────────────────────────────────

class _VaccinesTab extends StatelessWidget {
  final String walletId, memberId;
  final List<Vaccination> vaccinations;
  final bool isDark;
  final Color surfBg;
  final void Function(Vaccination) onAdd;
  final void Function(String) onDelete;
  const _VaccinesTab({required this.walletId, required this.memberId, required this.vaccinations, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final overdue = vaccinations.where((v) => v.isOverdue).toList();
    final dueSoon = vaccinations.where((v) => v.isDueSoon && !v.isOverdue).toList();
    final rest = vaccinations.where((v) => !v.isOverdue && !v.isDueSoon).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _healthColor,
        onPressed: () => _showAdd(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Vaccine', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: vaccinations.isEmpty
          ? const LifeEmptyState(emoji: '💉', title: 'No vaccinations', subtitle: 'Track vaccines and due dates')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              if (overdue.isNotEmpty) ...[const LifeLabel(text: '⚠️ OVERDUE'), ...overdue.map((v) => _VaccineCard(v: v, cardBg: cardBg, isDark: isDark, statusColor: Colors.red, onDelete: () async { try { await HealthService.instance.deleteVaccination(v.id); onDelete(v.id); } catch (err) { debugPrint('[Health] deleteVaccination: $err'); } }))],
              if (dueSoon.isNotEmpty) ...[if (overdue.isNotEmpty) const SizedBox(height: 8), const LifeLabel(text: '🔔 DUE SOON'), ...dueSoon.map((v) => _VaccineCard(v: v, cardBg: cardBg, isDark: isDark, statusColor: Colors.orange, onDelete: () async { try { await HealthService.instance.deleteVaccination(v.id); onDelete(v.id); } catch (err) { debugPrint('[Health] deleteVaccination: $err'); } }))],
              if (rest.isNotEmpty) ...[if (overdue.isNotEmpty || dueSoon.isNotEmpty) const SizedBox(height: 8), const LifeLabel(text: 'COMPLETED'), ...rest.map((v) => _VaccineCard(v: v, cardBg: cardBg, isDark: isDark, statusColor: _healthColor, onDelete: () async { try { await HealthService.instance.deleteVaccination(v.id); onDelete(v.id); } catch (err) { debugPrint('[Health] deleteVaccination: $err'); } }))],
            ]),
    );
  }

  void _showAdd(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final givenRef = <DateTime>[DateTime.now()];
    final dueRef = <DateTime?>[null];

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Add Vaccination', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
        const SizedBox(height: 12),
        LifeInput(controller: nameCtrl, hint: 'Vaccine name *'),
        const SizedBox(height: 8),
        LifeInput(controller: doseCtrl, hint: 'Dose number (optional)', inputType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: LifeDateTile(date: givenRef[0], hint: 'Date Given', color: _healthColor, onTap: () async { final d = await _pickDate(ctx2, initial: givenRef[0]); if (d != null) ss(() => givenRef[0] = d); })),
          const SizedBox(width: 8),
          Expanded(child: LifeDateTile(date: dueRef[0], hint: 'Next Due Date', color: Colors.orange, onTap: () async { final d = await _pickDate(ctx2); if (d != null) ss(() => dueRef[0] = d); })),
        ]),
        const SizedBox(height: 8),
        LifeInput(controller: notesCtrl, hint: 'Notes', maxLines: 2),
        LifeSaveButton(label: 'Save', color: _healthColor, onTap: () {
          if (nameCtrl.text.trim().isEmpty) return;
          final name = nameCtrl.text.trim();
          final dose = int.tryParse(doseCtrl.text.trim());
          final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
          final given = givenRef[0];
          final due = dueRef[0];
          Navigator.pop(ctx2);
          () async {
            try {
              final data = Vaccination(id: '', walletId: walletId, memberId: memberId, vaccineName: name, dateGiven: given, nextDue: due, doseNumber: dose, notes: notes);
              final row = await HealthService.instance.addVaccination(data.toJson());
              onAdd(Vaccination.fromJson(row));
            } catch (e) { debugPrint('[Health] addVaccine: $e'); }
          }();
        }),
      ]),
    )));
  }
}

class _VaccineCard extends StatelessWidget {
  final Vaccination v;
  final Color cardBg, statusColor;
  final bool isDark;
  final VoidCallback onDelete;
  const _VaccineCard({required this.v, required this.cardBg, required this.isDark, required this.statusColor, required this.onDelete});
  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey(v.id),
    direction: DismissDirection.endToStart,
    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.delete_rounded, color: Colors.red)),
    onDismissed: (_) => onDelete(),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: const Text('💉', style: TextStyle(fontSize: 20))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v.vaccineName + (v.doseNumber != null ? ' — Dose ${v.doseNumber}' : ''), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: isDark ? AppColors.textDark : AppColors.textLight)),
          Text('Given: ${_fmtDate(v.dateGiven)}', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: isDark ? AppColors.subDark : AppColors.subLight)),
          if (v.nextDue != null) Text('Next dose: ${_fmtDate(v.nextDue!)}', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: statusColor)),
        ])),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// INSURANCE TAB
// ─────────────────────────────────────────────────────────────────────────────

class _InsuranceTab extends StatelessWidget {
  final String walletId, memberId;
  final List<InsurancePolicy> policies;
  final bool isDark;
  final Color surfBg;
  final void Function(InsurancePolicy) onAdd;
  final void Function(String) onDelete;
  const _InsuranceTab({required this.walletId, required this.memberId, required this.policies, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _healthColor,
        onPressed: () => _showAdd(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Policy', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: policies.isEmpty
          ? const LifeEmptyState(emoji: '🏥', title: 'No insurance policies', subtitle: 'Keep track of your health insurance')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              for (final p in policies)
                Dismissible(
                  key: ValueKey(p.id),
                  direction: DismissDirection.endToStart,
                  background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.delete_rounded, color: Colors.red)),
                  onDismissed: (_) async { try { await HealthService.instance.deleteInsurance(p.id); onDelete(p.id); } catch (e) { debugPrint('[Health] deleteInsurance: $e'); } },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.isExpired ? Colors.red.withValues(alpha: 0.4) : p.expiresSoon ? Colors.orange.withValues(alpha: 0.4) : _healthColor.withValues(alpha: 0.2))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Text('🛡️', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.policyName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: isDark ? AppColors.textDark : AppColors.textLight)),
                          if (p.provider != null) Text(p.provider!, style: const TextStyle(fontSize: 12, fontFamily: 'Nunito', color: _healthColor)),
                        ])),
                        if (p.isExpired) _chip('Expired', Colors.red)
                        else if (p.expiresSoon) _chip('Expiring Soon', Colors.orange),
                      ]),
                      if (p.policyNumber != null || p.coverageAmount != null || p.expiryDate != null) ...[
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        if (p.policyNumber != null) _infoRow(context, Icons.badge_rounded, 'Policy No.', p.policyNumber!),
                        if (p.coverageAmount != null) _infoRow(context, Icons.currency_rupee_rounded, 'Coverage', '₹${p.coverageAmount!.toStringAsFixed(0)}'),
                        if (p.expiryDate != null) _infoRow(context, Icons.calendar_today_rounded, 'Expires', _fmtDate(p.expiryDate!), color: p.isExpired ? Colors.red : p.expiresSoon ? Colors.orange : _healthColor),
                      ],
                    ]),
                  ),
                ),
            ]),
    );
  }

  void _showAdd(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    final provCtrl = TextEditingController();
    final covCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final expiryRef = <DateTime?>[null];

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Add Insurance Policy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
        const SizedBox(height: 12),
        LifeInput(controller: nameCtrl, hint: 'Policy name *'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: LifeInput(controller: numCtrl, hint: 'Policy number')),
          const SizedBox(width: 8),
          Expanded(child: LifeInput(controller: provCtrl, hint: 'Provider')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: LifeInput(controller: covCtrl, hint: 'Coverage amount (₹)', inputType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
          const SizedBox(width: 8),
          Expanded(child: LifeDateTile(date: expiryRef[0], hint: 'Expiry Date', color: Colors.orange, onTap: () async { final d = await _pickDate(ctx2); if (d != null) ss(() => expiryRef[0] = d); })),
        ]),
        const SizedBox(height: 8),
        LifeInput(controller: notesCtrl, hint: 'Notes', maxLines: 2),
        LifeSaveButton(label: 'Save', color: _healthColor, onTap: () {
          if (nameCtrl.text.trim().isEmpty) return;
          final policy = InsurancePolicy(
            id: '', walletId: walletId, memberId: memberId,
            policyName: nameCtrl.text.trim(),
            policyNumber: numCtrl.text.trim().isEmpty ? null : numCtrl.text.trim(),
            provider: provCtrl.text.trim().isEmpty ? null : provCtrl.text.trim(),
            coverageAmount: double.tryParse(covCtrl.text.trim()),
            expiryDate: expiryRef[0],
            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          );
          Navigator.pop(ctx2);
          () async {
            try {
              final row = await HealthService.instance.addInsurance(policy.toJson());
              onAdd(InsurancePolicy.fromJson(row));
            } catch (e) { debugPrint('[Health] addInsurance: $e'); }
          }();
        }),
      ]),
    )));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMERGENCY CARD TAB
// ─────────────────────────────────────────────────────────────────────────────

class _EmergencyTab extends StatelessWidget {
  final HealthProfile? profile;
  final String memberId;
  final List<LifeMember> members;
  final List<Medication> meds;
  final bool isDark;
  const _EmergencyTab({required this.profile, required this.memberId, required this.members, required this.meds, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final member = members.firstWhere((m) => m.id == memberId, orElse: () => members.first);
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.emergency_rounded, color: Colors.red, size: 24)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Emergency Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: Colors.red)),
              Text('${member.emoji} ${member.name}', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: isDark ? AppColors.subDark : AppColors.subLight)),
            ])),
          ]),
          const Divider(height: 20),
          if (p == null)
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Complete the Profile tab to generate\nan emergency card.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.subDark))))
          else ...[
            if (p.bloodGroup != null) Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: Text(p.bloodGroup!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: Colors.white))),
              const SizedBox(width: 10),
              const Text('Blood Group', style: TextStyle(fontSize: 13, fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
            ]),
            if (p.bloodGroup != null) const SizedBox(height: 12),
            if (p.allergies.isNotEmpty) ...[
              const Text('⚠️  ALLERGIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: Colors.orange)),
              const SizedBox(height: 4),
              Wrap(children: p.allergies.map((a) => _chip(a, Colors.orange)).toList()),
              const SizedBox(height: 8),
            ],
            if (p.conditions.isNotEmpty) ...[
              const Text('🩺  CONDITIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: Colors.red)),
              const SizedBox(height: 4),
              Wrap(children: p.conditions.map((c) => _chip(c, Colors.red)).toList()),
              const SizedBox(height: 8),
            ],
            if (meds.isNotEmpty) ...[
              const Text('💊  ACTIVE MEDICATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: _healthColor)),
              const SizedBox(height: 4),
              Wrap(children: meds.map((m) => _chip('${m.name} ${m.dosage}', _healthColor)).toList()),
              const SizedBox(height: 8),
            ],
            if (p.emergencyContact != null) ...[
              const Divider(),
              const SizedBox(height: 8),
              const Text('🚨  EMERGENCY CONTACT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: Colors.red)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.person_rounded, size: 16, color: Colors.red),
                const SizedBox(width: 6),
                Text(p.emergencyContact!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Nunito')),
              ]),
              if (p.emergencyPhone != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: p.emergencyPhone!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number copied'), duration: Duration(seconds: 1)));
                  },
                  child: Row(children: [
                    const Icon(Icons.phone_rounded, size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    Text(p.emergencyPhone!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: Colors.red)),
                    const SizedBox(width: 6),
                    const Icon(Icons.copy_rounded, size: 13, color: Colors.red),
                  ]),
                ),
              ],
            ],
          ],
        ]),
      ),
    ]);
  }
}

