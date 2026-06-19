import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/confirm_delete.dart';
import 'package:wai_life_assistant/data/models/health/health_models.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import 'package:wai_life_assistant/data/services/health_service.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
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
  final int initialTab;
  const HealthSpaceScreen({super.key, required this.walletId, required this.members, this.initialTab = 0});
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
    _tab = TabController(length: _tabs.length, vsync: this, initialIndex: widget.initialTab.clamp(0, _tabs.length - 1));
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
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'health_load_data');
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
                      onUpdate: (m) => setState(() { final i = _medications.indexWhere((x) => x.id == m.id); if (i >= 0) _medications[i] = m; }),
                    ),
                    _DoctorsTab(walletId: widget.walletId, memberId: _selectedMember, doctors: _doctors.where((d) => d.memberId == _selectedMember).toList(), isDark: isDark, surfBg: surfBg,
                      onAdd: (d) => setState(() => _doctors.add(d)),
                      onDelete: (id) => setState(() => _doctors.removeWhere((d) => d.id == id)),
                      onUpdate: (d) => setState(() { final i = _doctors.indexWhere((x) => x.id == d.id); if (i >= 0) _doctors[i] = d; }),
                    ),
                    _DocumentsTab(walletId: widget.walletId, memberId: _selectedMember, docs: _documents.where((d) => d.memberId == _selectedMember).toList(), isDark: isDark, surfBg: surfBg,
                      onAdd: (d) => setState(() => _documents.insert(0, d)),
                      onDelete: (id) => setState(() => _documents.removeWhere((d) => d.id == id)),
                      onUpdate: (d) => setState(() { final i = _documents.indexWhere((x) => x.id == d.id); if (i >= 0) _documents[i] = d; }),
                    ),
                    _AppointmentsTab(walletId: widget.walletId, memberId: _selectedMember, appointments: _appointments.where((a) => a.memberId == _selectedMember).toList(), isDark: isDark, surfBg: surfBg,
                      onAdd: (a) => setState(() => _appointments.insert(0, a)),
                      onDelete: (id) => setState(() => _appointments.removeWhere((a) => a.id == id)),
                      onUpdate: (a) => setState(() { final i = _appointments.indexWhere((x) => x.id == a.id); if (i >= 0) _appointments[i] = a; }),
                    ),
                    _VitalsTab(walletId: widget.walletId, memberId: _selectedMember, vitals: _vitals.where((v) => v.memberId == _selectedMember).toList(), isDark: isDark, surfBg: surfBg,
                      onAdd: (v) => setState(() => _vitals.insert(0, v)),
                      onDelete: (id) => setState(() => _vitals.removeWhere((v) => v.id == id)),
                      onUpdate: (v) => setState(() { final i = _vitals.indexWhere((x) => x.id == v.id); if (i >= 0) _vitals[i] = v; }),
                    ),
                    _VaccinesTab(walletId: widget.walletId, memberId: _selectedMember, vaccinations: _vaccinations.where((v) => v.memberId == _selectedMember).toList(), isDark: isDark, surfBg: surfBg,
                      onAdd: (v) => setState(() => _vaccinations.insert(0, v)),
                      onDelete: (id) => setState(() => _vaccinations.removeWhere((v) => v.id == id)),
                      onUpdate: (v) => setState(() { final i = _vaccinations.indexWhere((x) => x.id == v.id); if (i >= 0) _vaccinations[i] = v; }),
                    ),
                    _InsuranceTab(walletId: widget.walletId, memberId: _selectedMember, policies: _insurance.where((p) => p.memberId == _selectedMember).toList(), isDark: isDark, surfBg: surfBg,
                      onAdd: (p) => setState(() => _insurance.insert(0, p)),
                      onDelete: (id) => setState(() => _insurance.removeWhere((p) => p.id == id)),
                      onUpdate: (p) => setState(() { final i = _insurance.indexWhere((x) => x.id == p.id); if (i >= 0) _insurance[i] = p; }),
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
    final tc  = isDark ? AppColors.textDark  : AppColors.textLight;
    final sub = isDark ? AppColors.subDark   : AppColors.subLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;

    if (p == null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80,
            decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('🏥', style: TextStyle(fontSize: 40))),
          const SizedBox(height: 20),
          Text('No Health Profile Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: tc)),
          const SizedBox(height: 8),
          Text('Add your medical details for quick access\nduring emergencies', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: sub)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _showEditProfile(context, null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(color: _healthColor, borderRadius: BorderRadius.circular(14)),
              child: const Text('Set Up Profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: Colors.white)),
            ),
          ),
        ]),
      ));
    }

    // BMI
    double? bmiVal;
    Color bmiColor = Colors.green;
    String bmiLabel = '';
    if (p.height != null && p.weight != null) {
      final h = double.tryParse(p.height!.replaceAll(RegExp(r'[^0-9.]'), ''));
      final w = double.tryParse(p.weight!.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (h != null && w != null && h > 0) {
        final hm = h > 10 ? h / 100 : h;
        bmiVal = w / (hm * hm);
        bmiLabel = bmiVal < 18.5 ? 'Underweight' : bmiVal < 25 ? 'Normal' : bmiVal < 30 ? 'Overweight' : 'Obese';
        bmiColor = bmiVal < 18.5 ? Colors.blue : bmiVal < 25 ? Colors.green : bmiVal < 30 ? Colors.orange : Colors.red;
      }
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [

      // ── Header banner ─────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_healthColor.withValues(alpha: 0.18), _healthColor.withValues(alpha: 0.04)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _healthColor.withValues(alpha: 0.3))),
        child: Row(children: [
          Container(width: 56, height: 56,
            decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.18), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('🩺', style: TextStyle(fontSize: 30))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Health Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: tc)),
            Text('Personal medical record', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub)),
          ])),
          GestureDetector(
            onTap: () => _showEditProfile(context, p),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _healthColor, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16)),
          ),
        ]),
      ),
      const SizedBox(height: 14),

      // ── Stats row (blood group / height / weight) ──────────────────
      if (p.bloodGroup != null || p.height != null || p.weight != null) ...[
        Row(children: [
          if (p.bloodGroup != null) ...[
            Expanded(child: _statTile('🩸', 'Blood', p.bloodGroup!, Colors.red, cardBg, tc, sub)),
            const SizedBox(width: 10),
          ],
          if (p.height != null) ...[
            Expanded(child: _statTile('📏', 'Height', p.height!, _healthColor, cardBg, tc, sub)),
            const SizedBox(width: 10),
          ],
          if (p.weight != null)
            Expanded(child: _statTile('⚖️', 'Weight', p.weight!, Colors.indigo, cardBg, tc, sub)),
        ]),
        const SizedBox(height: 10),
      ],

      // ── BMI card ───────────────────────────────────────────────────
      if (bmiVal != null) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bmiColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bmiColor.withValues(alpha: 0.25))),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: bmiColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: const Text('📊', style: TextStyle(fontSize: 22))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('BODY MASS INDEX', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'Nunito', letterSpacing: 0.6, color: sub)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(bmiVal.toStringAsFixed(1), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, fontFamily: 'DM Mono', color: bmiColor, height: 1)),
                const SizedBox(width: 8),
                Padding(padding: const EdgeInsets.only(bottom: 3),
                  child: Text(bmiLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: bmiColor))),
              ]),
            ])),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 56, child: Stack(clipBehavior: Clip.none, children: [
                Container(height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(colors: [Colors.blue, Colors.green, Colors.orange, Colors.red]))),
                Positioned(
                  left: (((bmiVal - 15) / 25).clamp(0.0, 1.0) * 48).toDouble(),
                  top: -3,
                  child: Container(width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      border: Border.all(color: bmiColor, width: 2),
                      boxShadow: [BoxShadow(color: bmiColor.withValues(alpha: 0.4), blurRadius: 4)]))),
              ])),
              const SizedBox(height: 6),
              Text('15       40', style: TextStyle(fontSize: 9, fontFamily: 'DM Mono', color: sub)),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
      ],

      // ── Allergies ──────────────────────────────────────────────────
      if (p.allergies.isNotEmpty) ...[
        _chipsSection('⚠️', 'Allergies', p.allergies, Colors.orange, cardBg, tc),
        const SizedBox(height: 10),
      ],

      // ── Conditions ─────────────────────────────────────────────────
      if (p.conditions.isNotEmpty) ...[
        _chipsSection('🩺', 'Conditions', p.conditions, Colors.red, cardBg, tc),
        const SizedBox(height: 10),
      ],

      // ── Special Needs ──────────────────────────────────────────────
      if (p.disabilities.isNotEmpty) ...[
        _chipsSection('♿', 'Special Needs', p.disabilities, _healthColor, cardBg, tc),
        const SizedBox(height: 10),
      ],

      // ── Emergency contact ──────────────────────────────────────────
      if (p.emergencyContact != null)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.25))),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: const Icon(Icons.emergency_rounded, color: Colors.red, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('EMERGENCY CONTACT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'Nunito', letterSpacing: 0.5, color: Colors.red)),
              const SizedBox(height: 4),
              Text(p.emergencyContact!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
              if (p.emergencyPhone != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.phone_rounded, size: 13, color: Colors.red),
                  const SizedBox(width: 5),
                  Text(p.emergencyPhone!, style: const TextStyle(fontSize: 13, fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: Colors.red)),
                ]),
              ],
            ])),
          ]),
        ),
    ]);
  }

  Widget _statTile(String emoji, String label, String value, Color color, Color cardBg, Color tc, Color sub) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'DM Mono', color: tc), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: sub)),
      ]),
    );

  Widget _chipsSection(String emoji, String title, List<String> items, Color color, Color cardBg, Color tc) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'Nunito', letterSpacing: 0.7, color: color)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: items.map((item) => _chip(item, color)).toList()),
      ]),
    );

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
            } catch (e, stack) {
              ErrorLogger.log(e, stackTrace: stack, action: 'health_upsert_profile');
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
  final void Function(Medication) onUpdate;
  const _MedicationsTab({required this.walletId, required this.memberId, required this.meds, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete, required this.onToggle, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final active = meds.where((m) => m.isActive).toList();
    final past = meds.where((m) => !m.isActive).toList();
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _healthColor,
        onPressed: () => _showMedSheet(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Medicine', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: meds.isEmpty
          ? const LifeEmptyState(emoji: '💊', title: 'No medications yet', subtitle: 'Track current and past medications')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              if (active.isNotEmpty) ...[
                const LifeLabel(text: 'ACTIVE MEDICATIONS'),
                ...active.map((m) => _MedCard(m: m, cardBg: cardBg, isDark: isDark,
                  onDelete: () => onDelete(m.id),
                  onEdit: () => _showMedSheet(context, existing: m),
                  onToggle: () async {
                    try {
                      await HealthService.instance.updateMedication(m.id, {'is_active': false});
                      onToggle(Medication(id: m.id, walletId: m.walletId, memberId: m.memberId, name: m.name, dosage: m.dosage, frequency: m.frequency, scheduleTimes: m.scheduleTimes, mealTiming: m.mealTiming, notes: m.notes, isActive: false, startDate: m.startDate, endDate: m.endDate, refillDate: m.refillDate));
                    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_deactivate_med'); debugPrint('[Health] toggleMed: $e'); }
                  })),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 8),
                const LifeLabel(text: 'PAST MEDICATIONS'),
                ...past.map((m) => _MedCard(m: m, cardBg: cardBg, isDark: isDark,
                  onDelete: () => onDelete(m.id),
                  onEdit: () => _showMedSheet(context, existing: m),
                  onToggle: () async {
                    try {
                      await HealthService.instance.updateMedication(m.id, {'is_active': true});
                      onToggle(Medication(id: m.id, walletId: m.walletId, memberId: m.memberId, name: m.name, dosage: m.dosage, frequency: m.frequency, scheduleTimes: m.scheduleTimes, mealTiming: m.mealTiming, notes: m.notes, isActive: true, startDate: m.startDate, endDate: m.endDate, refillDate: m.refillDate));
                    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_activate_med'); debugPrint('[Health] toggleMed: $e'); }
                  })),
              ],
            ]),
    );
  }

  void _showMedSheet(BuildContext ctx, {Medication? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final dosageCtrl = TextEditingController(text: existing?.dosage);
    final freqCtrl = TextEditingController(text: existing?.frequency);
    final notesCtrl = TextEditingController(text: existing?.notes);
    final startRef = <DateTime>[existing?.startDate ?? DateTime.now()];
    final refillRef = <DateTime?>[existing?.refillDate];
    final endRef = <DateTime?>[existing?.endDate];
    final scheduleTimesRef = <List<String>>[List.from(existing?.scheduleTimes ?? [])];
    final mealTimingRef = <String?>[existing?.mealTiming ?? ''];

    // Duration options: (label, days, months) — 0/0 = ongoing
    final durations = <(String, int, int)>[
      ('3 Days', 3, 0), ('5 Days', 5, 0), ('7 Days', 7, 0), ('10 Days', 10, 0),
      ('14 Days', 14, 0), ('1 Month', 0, 1), ('3 Months', 0, 3), ('6 Months', 0, 6),
      ('Ongoing', 0, 0),
    ];

    DateTime? computeEnd(DateTime start, String label) {
      if (label == 'Ongoing') return null;
      for (final (lbl, days, months) in durations) {
        if (lbl == label) {
          return months > 0
              ? DateTime(start.year, start.month + months, start.day)
              : start.add(Duration(days: days));
        }
      }
      return null;
    }

    // Pre-select chip for existing med's end_date
    String? initLabel;
    if (existing != null) {
      if (existing.endDate == null) {
        initLabel = 'Ongoing';
      } else {
        final s = existing.startDate;
        final e = existing.endDate!;
        for (final (lbl, days, months) in durations) {
          if (lbl == 'Ongoing') continue;
          final exp = months > 0
              ? DateTime(s.year, s.month + months, s.day)
              : s.add(Duration(days: days));
          if (exp.year == e.year && exp.month == e.month && exp.day == e.day) {
            initLabel = lbl;
            break;
          }
        }
      }
    }
    final durationLabel = <String?>[initLabel];

    const scheduleOptions = [
      ('🌅', 'Morning'), ('☀️', 'Afternoon'), ('🌆', 'Evening'), ('🌙', 'Night'),
    ];
    const mealOptions = [
      ('🍽️', 'Before food'), ('🥢', 'After food'),
    ];

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) {
      final isDark = ctx2.isDark;
      final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
      final sub = isDark ? AppColors.subDark : AppColors.subLight;

      Widget pillRow(List<(String, String)> options, String? selected, bool multiSelect, void Function(String) onTap) {
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (emoji, label) in options)
            GestureDetector(
              onTap: () => onTap(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: (multiSelect ? scheduleTimesRef[0].contains(label) : selected == label)
                      ? _healthColor.withValues(alpha: 0.15)
                      : surfBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (multiSelect ? scheduleTimesRef[0].contains(label) : selected == label)
                        ? _healthColor
                        : Colors.transparent,
                  ),
                ),
                child: Text('$emoji  $label', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Nunito',
                  color: (multiSelect ? scheduleTimesRef[0].contains(label) : selected == label)
                      ? _healthColor : sub,
                )),
              ),
            ),
        ]);
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(existing == null ? 'Add Medication' : 'Edit Medication', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
          const SizedBox(height: 12),
          LifeInput(controller: nameCtrl, hint: 'Medicine name *'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: LifeInput(controller: dosageCtrl, hint: 'Dosage (e.g. 500mg)')),
            const SizedBox(width: 8),
            Expanded(child: LifeInput(controller: freqCtrl, hint: 'Frequency (e.g. Twice daily)')),
          ]),
          const LifeLabel(text: 'TIME OF DAY'),
          pillRow(scheduleOptions, null, true, (label) {
            final list = scheduleTimesRef[0];
            scheduleTimesRef[0] = list.contains(label) ? list.where((x) => x != label).toList() : [...list, label];
            ss(() {});
          }),
          const LifeLabel(text: 'MEAL TIMING'),
          pillRow(mealOptions, mealTimingRef[0], false, (label) {
            mealTimingRef[0] = mealTimingRef[0] == label ? null : label;
            ss(() {});
          }),
          const LifeLabel(text: 'DURATION'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (lbl, _, _) in durations)
              GestureDetector(
                onTap: () {
                  durationLabel[0] = lbl;
                  endRef[0] = computeEnd(startRef[0], lbl);
                  ss(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: durationLabel[0] == lbl
                        ? _healthColor.withValues(alpha: 0.15)
                        : surfBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: durationLabel[0] == lbl ? _healthColor : Colors.transparent,
                    ),
                  ),
                  child: Text(lbl, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Nunito',
                    color: durationLabel[0] == lbl ? _healthColor : sub,
                  )),
                ),
              ),
          ]),
          if (endRef[0] != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.flag_rounded, size: 13, color: _healthColor),
              const SizedBox(width: 4),
              Text(
                'Until ${_fmtDate(endRef[0]!)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: _healthColor),
              ),
            ]),
          ],
          const SizedBox(height: 8),
          LifeInput(controller: notesCtrl, hint: 'Notes (optional)', maxLines: 2),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: LifeDateTile(date: startRef[0], hint: 'Start Date', color: _healthColor, onTap: () async { final d = await _pickDate(ctx2, initial: startRef[0]); if (d != null) ss(() => startRef[0] = d); })),
            const SizedBox(width: 8),
            Expanded(child: LifeDateTile(date: refillRef[0], hint: 'Refill Date', color: Colors.orange, onTap: () async { final d = await _pickDate(ctx2); if (d != null) ss(() => refillRef[0] = d); })),
          ]),
          LifeSaveButton(label: existing == null ? 'Save' : 'Update', color: _healthColor, onTap: () {
            if (nameCtrl.text.trim().isEmpty || dosageCtrl.text.trim().isEmpty || freqCtrl.text.trim().isEmpty) return;
            final name = nameCtrl.text.trim();
            final dosage = dosageCtrl.text.trim();
            final freq = freqCtrl.text.trim();
            final scheduleTimes = List<String>.from(scheduleTimesRef[0]);
            final mealTiming = mealTimingRef[0]?.isEmpty == true ? null : mealTimingRef[0];
            final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
            final start = startRef[0];
            final end = endRef[0];
            final refill = refillRef[0];
            Navigator.pop(ctx2);
            () async {
              try {
                if (existing == null) {
                  final data = Medication(id: '', walletId: walletId, memberId: memberId, name: name, dosage: dosage, frequency: freq, scheduleTimes: scheduleTimes, mealTiming: mealTiming, notes: notes, startDate: start, endDate: end, refillDate: refill);
                  final row = await HealthService.instance.addMedication(data.toJson());
                  onAdd(Medication.fromJson(row));
                } else {
                  final updates = {
                    'name': name, 'dosage': dosage, 'frequency': freq,
                    'schedule_times': scheduleTimes,
                    'meal_timing': mealTiming,
                    'notes': notes,
                    'start_date': start.toIso8601String().substring(0, 10),
                    'end_date': end?.toIso8601String().substring(0, 10),
                    if (refill != null) 'refill_date': refill.toIso8601String().substring(0, 10),
                  };
                  await HealthService.instance.updateMedication(existing.id, updates);
                  onUpdate(Medication(id: existing.id, walletId: existing.walletId, memberId: existing.memberId, name: name, dosage: dosage, frequency: freq, scheduleTimes: scheduleTimes, mealTiming: mealTiming, notes: notes, isActive: existing.isActive, startDate: start, endDate: end, refillDate: refill));
                }
              } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_save_med'); debugPrint('[Health] saveMed: $e'); }
            }();
          }),
        ]),
      );
    }));
  }
}

class _MedCard extends StatelessWidget {
  final Medication m;
  final Color cardBg;
  final bool isDark;
  final VoidCallback onDelete, onToggle, onEdit;
  const _MedCard({required this.m, required this.cardBg, required this.isDark, required this.onDelete, required this.onToggle, required this.onEdit});

  static const _scheduleEmojis = {'Morning': '🌅', 'Afternoon': '☀️', 'Evening': '🌆', 'Night': '🌙'};

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: fg)),
  );

  @override
  Widget build(BuildContext context) {
    final tc  = isDark ? AppColors.textDark  : AppColors.textLight;
    final sub = isDark ? AppColors.subDark   : AppColors.subLight;
    final accent = m.isActive ? _healthColor : Colors.grey;
    final hasSchedule = m.scheduleTimes.isNotEmpty || m.mealTiming != null;

    return Dismissible(
      key: ValueKey(m.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_rounded, color: Colors.red)),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: m.isActive ? 0.3 : 0.15))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Top row ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Stack(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13)),
                  alignment: Alignment.center,
                  child: const Text('💊', style: TextStyle(fontSize: 24))),
                if (m.isActive)
                  Positioned(right: 1, top: 1,
                    child: Container(
                      width: 11, height: 11,
                      decoration: BoxDecoration(
                        color: _healthColor, shape: BoxShape.circle,
                        border: Border.all(color: cardBg, width: 2)))),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: tc)),
                const SizedBox(height: 5),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7)),
                    child: Text(m.dosage, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'DM Mono', color: accent))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m.frequency, style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub), overflow: TextOverflow.ellipsis)),
                ]),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text(m.isActive ? '● Active' : '○ Past',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: accent)))),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onEdit,
                  child: Icon(Icons.edit_outlined, size: 16, color: sub)),
              ]),
            ]),
          ),

          // ── Schedule chips ───────────────────────────────────────
          if (hasSchedule)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                for (final t in m.scheduleTimes)
                  _pill('${_scheduleEmojis[t] ?? '⏰'} $t',
                    _healthColor.withValues(alpha: 0.1), _healthColor),
                if (m.mealTiming != null)
                  _pill(m.mealTiming!.contains('Before') ? '🍽️ ${m.mealTiming!}' : '🥢 ${m.mealTiming!}',
                    Colors.purple.withValues(alpha: 0.1), Colors.purple),
              ]),
            ),

          // ── Footer: dates ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: sub),
                const SizedBox(width: 4),
                Text('Since ${_fmtDate(m.startDate)}', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                if (m.endDate != null) ...[
                  const SizedBox(width: 6),
                  Text('·', style: TextStyle(fontSize: 11, color: sub)),
                  const SizedBox(width: 6),
                  Icon(Icons.flag_rounded, size: 12, color: accent),
                  const SizedBox(width: 4),
                  Text('Until ${_fmtDate(m.endDate!)}',
                    style: TextStyle(fontSize: 11, fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: accent)),
                ] else ...[
                  const SizedBox(width: 6),
                  Text('·', style: TextStyle(fontSize: 11, color: sub)),
                  const SizedBox(width: 6),
                  Text('Ongoing', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                ],
              ]),
              if (m.refillDate != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.refresh_rounded, size: 12, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text('Refill ${_fmtDate(m.refillDate!)}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'Nunito', color: Colors.orange, fontWeight: FontWeight.w700)),
                ]),
              ],
            ]),
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
  final void Function(DoctorRecord) onUpdate;
  const _DoctorsTab({required this.walletId, required this.memberId, required this.doctors, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _healthColor,
        onPressed: () => _showSheet(context),
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
                  background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.delete_rounded, color: Colors.red)),
                  confirmDismiss: (_) => confirmDelete(context),
                  onDismissed: (_) async {
                    try { await HealthService.instance.deleteDoctor(d.id); onDelete(d.id); } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_delete_doctor'); debugPrint('[Health] deleteDoctor: $e'); }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _healthColor.withValues(alpha: 0.2))),
                    child: IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      // Left accent strip
                      Container(
                        width: 5,
                        decoration: BoxDecoration(
                          color: _healthColor,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)))),
                      Expanded(child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
                              alignment: Alignment.center,
                              child: const Text('👨‍⚕️', style: TextStyle(fontSize: 26))),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Dr. ${d.name}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: isDark ? AppColors.textDark : AppColors.textLight)),
                              const SizedBox(height: 5),
                              if (d.specialty != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                  child: Text(d.specialty!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: _healthColor))),
                            ])),
                            GestureDetector(
                              onTap: () => _showSheet(context, existing: d),
                              child: Icon(Icons.edit_outlined, size: 18, color: isDark ? AppColors.subDark : AppColors.subLight)),
                          ]),
                          if (d.hospital != null || d.phone != null) ...[
                            const SizedBox(height: 10),
                            Divider(height: 1, color: _healthColor.withValues(alpha: 0.1)),
                            const SizedBox(height: 10),
                          ],
                          if (d.hospital != null) ...[
                            Row(children: [
                              Icon(Icons.local_hospital_rounded, size: 13, color: isDark ? AppColors.subDark : AppColors.subLight),
                              const SizedBox(width: 6),
                              Expanded(child: Text(d.hospital!, style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: isDark ? AppColors.subDark : AppColors.subLight))),
                            ]),
                            if (d.phone != null) const SizedBox(height: 6),
                          ],
                          if (d.phone != null)
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.phone_rounded, size: 13, color: Colors.green),
                                  const SizedBox(width: 5),
                                  Text(d.phone!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: Colors.green)),
                                ])),
                            ]),
                          if (d.notes != null) ...[
                            const SizedBox(height: 8),
                            Text(d.notes!, style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: isDark ? AppColors.subDark : AppColors.subLight), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ]),
                      )),
                    ]),
                    ),
                  ),
                ),
            ]),
    );
  }

  void _showSheet(BuildContext ctx, {DoctorRecord? existing}) {
    final nameCtrl  = TextEditingController(text: existing?.name ?? '');
    final specCtrl  = TextEditingController(text: existing?.specialty ?? '');
    final hospCtrl  = TextEditingController(text: existing?.hospital ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    showLifeSheet(ctx, child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 36), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(existing == null ? 'Add Doctor' : 'Edit Doctor', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
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
      LifeSaveButton(label: existing == null ? 'Save' : 'Update', color: _healthColor, onTap: () {
        if (nameCtrl.text.trim().isEmpty) return;
        final name      = nameCtrl.text.trim();
        final specialty = specCtrl.text.trim().isEmpty  ? null : specCtrl.text.trim();
        final hospital  = hospCtrl.text.trim().isEmpty  ? null : hospCtrl.text.trim();
        final phone     = phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim();
        final notes     = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
        Navigator.pop(ctx);
        if (existing == null) {
          final data = DoctorRecord(id: '', walletId: walletId, memberId: memberId, name: name, specialty: specialty, hospital: hospital, phone: phone, notes: notes);
          () async { try { final row = await HealthService.instance.addDoctor(data.toJson()); onAdd(DoctorRecord.fromJson(row)); } catch (e) { debugPrint('[Health] addDoctor: $e'); } }();
        } else {
          final updates = {'name': name, 'specialty': specialty, 'hospital': hospital, 'phone': phone, 'notes': notes};
          () async { try { await HealthService.instance.updateDoctor(existing.id, updates); onUpdate(DoctorRecord(id: existing.id, walletId: existing.walletId, memberId: existing.memberId, name: name, specialty: specialty, hospital: hospital, phone: phone, notes: notes)); } catch (e) { debugPrint('[Health] updateDoctor: $e'); } }();
        }
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
  final void Function(MedicalDocument) onUpdate;
  const _DocumentsTab({required this.walletId, required this.memberId, required this.docs, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _healthColor,
        onPressed: () => _showSheet(context),
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
                  background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.delete_rounded, color: Colors.red)),
                  confirmDismiss: (_) => confirmDelete(context),
                  onDismissed: (_) async {
                    try { await HealthService.instance.deleteDocument(d.id, d.fileUrl); onDelete(d.id); } catch (e) { debugPrint('[Health] deleteDoc: $e'); }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _healthColor.withValues(alpha: 0.18))),
                    child: Column(children: [
                      // ── Header banner ──
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: _healthColor.withValues(alpha: 0.07),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: Text(d.docType.emoji, style: const TextStyle(fontSize: 22))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: isDark ? AppColors.textDark : AppColors.textLight), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                              child: Text(d.docType.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: _healthColor))),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                              child: Text(_fmtDate(d.docDate), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'DM Mono', color: isDark ? AppColors.subDark : AppColors.subLight))),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _showSheet(context, existing: d),
                              child: Icon(Icons.edit_outlined, size: 16, color: isDark ? AppColors.subDark : AppColors.subLight)),
                          ]),
                        ]),
                      ),
                      // ── Body (notes + file) ──
                      if (d.notes != null || d.fileUrl != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (d.notes != null) Text(d.notes!, style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: isDark ? AppColors.subDark : AppColors.subLight), maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (d.fileUrl != null) ...[
                              if (d.notes != null) const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => launchUrl(Uri.parse(d.fileUrl!), mode: LaunchMode.externalApplication),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _healthColor.withValues(alpha: 0.3))),
                                  child: Row(children: [
                                    Icon(d.fileUrl!.endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.image_rounded, size: 14, color: _healthColor),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text('View Attachment', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: _healthColor))),
                                    Icon(Icons.open_in_new_rounded, size: 13, color: _healthColor.withValues(alpha: 0.7)),
                                  ]),
                                ),
                              ),
                            ],
                          ]),
                        ),
                    ]),
                  ),
                ),
            ]),
    );
  }

  void _showSheet(BuildContext ctx, {MedicalDocument? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final typeRef = <MedDocType>[existing?.docType ?? MedDocType.prescription];
    final dateRef = <DateTime>[existing?.docDate ?? DateTime.now()];
    final pathRef = <String?>[null];

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(existing == null ? 'Add Document' : 'Edit Document', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
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
        if (existing == null) ...[
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
        ],
        LifeSaveButton(label: existing == null ? 'Save' : 'Update', color: _healthColor, onTap: () {
          if (titleCtrl.text.trim().isEmpty) return;
          final title = titleCtrl.text.trim();
          final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
          final type  = typeRef[0];
          final date  = dateRef[0];
          Navigator.pop(ctx2);
          if (existing == null) {
            final localPath = pathRef[0];
            () async {
              try {
                String? fileUrl;
                if (localPath != null) fileUrl = await HealthService.instance.uploadDoc(localPath, memberId: memberId);
                final data = MedicalDocument(id: '', walletId: walletId, memberId: memberId, title: title, docType: type, fileUrl: fileUrl, notes: notes, docDate: date);
                final row = await HealthService.instance.addDocument(data.toJson());
                onAdd(MedicalDocument.fromJson(row));
              } catch (e) { debugPrint('[Health] addDoc: $e'); }
            }();
          } else {
            final updates = {'title': title, 'doc_type': type.name, 'doc_date': date.toIso8601String().substring(0, 10), if (notes != null) 'notes': notes};
            () async {
              try {
                await HealthService.instance.updateDocument(existing.id, updates);
                onUpdate(MedicalDocument(id: existing.id, walletId: existing.walletId, memberId: existing.memberId, title: title, docType: type, fileUrl: existing.fileUrl, notes: notes, docDate: date));
              } catch (e) { debugPrint('[Health] updateDoc: $e'); }
            }();
          }
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
  final void Function(Appointment) onUpdate;
  const _AppointmentsTab({required this.walletId, required this.memberId, required this.appointments, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final upcoming = appointments.where((a) => a.isUpcoming).toList()..sort((a, b) => a.apptDate.compareTo(b.apptDate));
    final past = appointments.where((a) => !a.isUpcoming).toList();
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _healthColor,
        onPressed: () => _showSheet(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Book Appointment', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: appointments.isEmpty
          ? const LifeEmptyState(emoji: '📅', title: 'No appointments', subtitle: 'Track upcoming and past doctor visits')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              if (upcoming.isNotEmpty) ...[
                const LifeLabel(text: 'UPCOMING'),
                ...upcoming.map((a) => _ApptCard(a: a, cardBg: cardBg, isDark: isDark,
                  onDelete: () async { try { await HealthService.instance.deleteAppointment(a.id); onDelete(a.id); } catch (e) { debugPrint('[Health] deleteAppt: $e'); } },
                  onEdit: () => _showSheet(context, existing: a))),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 8),
                const LifeLabel(text: 'PAST'),
                ...past.map((a) => _ApptCard(a: a, cardBg: cardBg, isDark: isDark,
                  onDelete: () async { try { await HealthService.instance.deleteAppointment(a.id); onDelete(a.id); } catch (e) { debugPrint('[Health] deleteAppt: $e'); } },
                  onEdit: () => _showSheet(context, existing: a))),
              ],
            ]),
    );
  }

  void _showSheet(BuildContext ctx, {Appointment? existing}) {
    final doctorCtrl   = TextEditingController(text: existing?.doctorName ?? '');
    final timeCtrl     = TextEditingController(text: existing?.apptTime ?? '');
    final locationCtrl = TextEditingController(text: existing?.location ?? '');
    final notesCtrl    = TextEditingController(text: existing?.notes ?? '');
    final dateRef = <DateTime>[existing?.apptDate ?? DateTime.now().add(const Duration(days: 1))];

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(existing == null ? 'Book Appointment' : 'Edit Appointment', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
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
        LifeSaveButton(label: existing == null ? 'Save' : 'Update', color: _healthColor, onTap: () {
          if (doctorCtrl.text.trim().isEmpty) return;
          final doctor   = doctorCtrl.text.trim();
          final time     = timeCtrl.text.trim().isEmpty     ? null : timeCtrl.text.trim();
          final location = locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim();
          final notes    = notesCtrl.text.trim().isEmpty    ? null : notesCtrl.text.trim();
          final date     = dateRef[0];
          Navigator.pop(ctx2);
          if (existing == null) {
            () async {
              try {
                final data = Appointment(id: '', walletId: walletId, memberId: memberId, doctorName: doctor, apptDate: date, apptTime: time, location: location, notes: notes);
                final row = await HealthService.instance.addAppointment(data.toJson());
                onAdd(Appointment.fromJson(row));
              } catch (e) { debugPrint('[Health] addAppt: $e'); }
            }();
          } else {
            final updates = {'doctor_name': doctor, 'appt_date': date.toIso8601String().substring(0, 10), 'appt_time': time, 'location': location, 'notes': notes};
            () async {
              try {
                await HealthService.instance.updateAppointment(existing.id, updates);
                onUpdate(Appointment(id: existing.id, walletId: existing.walletId, memberId: existing.memberId, doctorName: doctor, apptDate: date, apptTime: time, location: location, notes: notes));
              } catch (e) { debugPrint('[Health] updateAppt: $e'); }
            }();
          }
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
  final VoidCallback onEdit;
  const _ApptCard({required this.a, required this.cardBg, required this.isDark, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final tc  = isDark ? AppColors.textDark  : AppColors.textLight;
    final sub = isDark ? AppColors.subDark   : AppColors.subLight;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysUntil = a.apptDate.difference(today).inDays;
    final isToday    = daysUntil == 0;
    final isTomorrow = daysUntil == 1;
    final isPast = !a.isUpcoming;

    final Color accent;
    final String bannerText;
    if (isPast) {
      accent = Colors.grey;
      bannerText = _fmtDate(a.apptDate);
    } else if (isToday) {
      accent = Colors.red;
      bannerText = 'Today';
    } else if (isTomorrow) {
      accent = Colors.orange;
      bannerText = 'Tomorrow';
    } else if (daysUntil <= 7) {
      accent = Colors.orange;
      bannerText = 'In $daysUntil days';
    } else {
      accent = _healthColor;
      bannerText = _fmtDate(a.apptDate);
    }

    return Dismissible(
      key: ValueKey(a.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_rounded, color: Colors.red)),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: isPast ? 0.15 : 0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Banner ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isPast ? 0.05 : 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [
              Icon(isPast ? Icons.event_available_rounded : Icons.event_rounded, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(bannerText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: accent)),
              const Spacer(),
              if (a.apptTime != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.schedule_rounded, size: 11, color: accent),
                    const SizedBox(width: 4),
                    Text(a.apptTime!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'DM Mono', color: accent)),
                  ])),
                const SizedBox(width: 8),
              ],
              GestureDetector(onTap: onEdit, child: Icon(Icons.edit_outlined, size: 16, color: accent)),
            ]),
          ),

          // ── Body ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(
                  isPast ? '✓' : '🏥',
                  style: TextStyle(fontSize: isPast ? 22 : 22, fontWeight: FontWeight.w900,
                    color: isPast ? accent : null))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.doctorName,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'Nunito',
                    color: isPast ? sub : tc)),
                if (a.location != null) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.location_on_rounded, size: 13, color: sub),
                    const SizedBox(width: 4),
                    Expanded(child: Text(a.location!, style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub), overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                if (a.notes != null) ...[
                  const SizedBox(height: 4),
                  Text(a.notes!, style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ])),
            ]),
          ),
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
  final void Function(HealthVital) onUpdate;
  const _VitalsTab({required this.walletId, required this.memberId, required this.vitals, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete, required this.onUpdate});
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
        onPressed: () => _showSheet(context),
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
                      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.delete_rounded, color: Colors.red)),
                      confirmDismiss: (_) => confirmDelete(context),
                      onDismissed: (_) async { try { await HealthService.instance.deleteVital(v.id); widget.onDelete(v.id); } catch (e) { debugPrint('[Health] deleteVital: $e'); } },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _healthColor.withValues(alpha: 0.18))),
                        child: Column(children: [
                          // ── Value banner ──
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [_healthColor.withValues(alpha: 0.12), _healthColor.withValues(alpha: 0.03)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                                alignment: Alignment.center,
                                child: Text(v.type.emoji, style: const TextStyle(fontSize: 26))),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(v.displayValue, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'DM Mono', color: _healthColor)),
                                if (v.subType != null) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                    child: Text(v.subType!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: _healthColor))),
                                ],
                              ])),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(_fmtDateShort(v.recordedAt), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: widget.isDark ? AppColors.subDark : AppColors.subLight)),
                                const SizedBox(height: 2),
                                Text('${v.recordedAt.hour.toString().padLeft(2, '0')}:${v.recordedAt.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'DM Mono', color: widget.isDark ? AppColors.textDark : AppColors.textLight)),
                                const SizedBox(height: 6),
                                GestureDetector(onTap: () => _showSheet(context, existing: v), child: Icon(Icons.edit_outlined, size: 15, color: widget.isDark ? AppColors.subDark : AppColors.subLight)),
                              ]),
                            ]),
                          ),
                          if (v.notes != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                              child: Row(children: [
                                Icon(Icons.notes_rounded, size: 13, color: widget.isDark ? AppColors.subDark : AppColors.subLight),
                                const SizedBox(width: 6),
                                Expanded(child: Text(v.notes!, style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: widget.isDark ? AppColors.subDark : AppColors.subLight), maxLines: 2, overflow: TextOverflow.ellipsis)),
                              ]),
                            ),
                        ]),
                      ),
                    ),
                ]),
        ),
      ]),
    );
  }

  void _showSheet(BuildContext ctx, {HealthVital? existing}) {
    final v1Ctrl    = TextEditingController(text: existing?.value.toString() ?? '');
    final v2Ctrl    = TextEditingController(text: existing?.value2?.toString() ?? '');
    final subCtrl   = TextEditingController(text: existing?.subType ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final typeRef   = <VitalType>[existing?.type ?? _selected];

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(existing == null ? 'Log Vital' : 'Edit Vital', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
        const SizedBox(height: 12),
        if (existing == null) ...[
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
        ],
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
        LifeSaveButton(label: existing == null ? 'Log' : 'Update', color: _healthColor, onTap: () {
          final v1 = double.tryParse(v1Ctrl.text.trim());
          if (v1 == null) return;
          final type  = typeRef[0];
          final v2    = double.tryParse(v2Ctrl.text.trim());
          final sub   = subCtrl.text.trim().isEmpty   ? null : subCtrl.text.trim();
          final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
          Navigator.pop(ctx2);
          if (existing == null) {
            () async {
              try {
                final data = HealthVital(id: '', walletId: widget.walletId, memberId: widget.memberId, type: type, value: v1, value2: v2, subType: sub, notes: notes);
                final row = await HealthService.instance.addVital(data.toJson());
                widget.onAdd(HealthVital.fromJson(row));
              } catch (e) { debugPrint('[Health] addVital: $e'); }
            }();
          } else {
            final updates = {'value': v1, if (v2 != null) 'value2': v2, 'sub_type': sub, 'notes': notes};
            () async {
              try {
                await HealthService.instance.updateVital(existing.id, updates);
                widget.onUpdate(HealthVital(id: existing.id, walletId: existing.walletId, memberId: existing.memberId, type: existing.type, value: v1, value2: v2, subType: sub, notes: notes, recordedAt: existing.recordedAt));
              } catch (e) { debugPrint('[Health] updateVital: $e'); }
            }();
          }
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
  final void Function(Vaccination) onUpdate;
  const _VaccinesTab({required this.walletId, required this.memberId, required this.vaccinations, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete, required this.onUpdate});

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
        onPressed: () => _showSheet(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Vaccine', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: vaccinations.isEmpty
          ? const LifeEmptyState(emoji: '💉', title: 'No vaccinations', subtitle: 'Track vaccines and due dates')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              if (overdue.isNotEmpty) ...[const LifeLabel(text: '⚠️ OVERDUE'), ...overdue.map((v) => _VaccineCard(v: v, cardBg: cardBg, isDark: isDark, statusColor: Colors.red, onDelete: () async { try { await HealthService.instance.deleteVaccination(v.id); onDelete(v.id); } catch (err) { debugPrint('[Health] deleteVaccination: $err'); } }, onEdit: () => _showSheet(context, existing: v)))],
              if (dueSoon.isNotEmpty) ...[if (overdue.isNotEmpty) const SizedBox(height: 8), const LifeLabel(text: '🔔 DUE SOON'), ...dueSoon.map((v) => _VaccineCard(v: v, cardBg: cardBg, isDark: isDark, statusColor: Colors.orange, onDelete: () async { try { await HealthService.instance.deleteVaccination(v.id); onDelete(v.id); } catch (err) { debugPrint('[Health] deleteVaccination: $err'); } }, onEdit: () => _showSheet(context, existing: v)))],
              if (rest.isNotEmpty) ...[if (overdue.isNotEmpty || dueSoon.isNotEmpty) const SizedBox(height: 8), const LifeLabel(text: 'COMPLETED'), ...rest.map((v) => _VaccineCard(v: v, cardBg: cardBg, isDark: isDark, statusColor: _healthColor, onDelete: () async { try { await HealthService.instance.deleteVaccination(v.id); onDelete(v.id); } catch (err) { debugPrint('[Health] deleteVaccination: $err'); } }, onEdit: () => _showSheet(context, existing: v)))],
            ]),
    );
  }

  void _showSheet(BuildContext ctx, {Vaccination? existing}) {
    final nameCtrl = TextEditingController(text: existing?.vaccineName ?? '');
    final doseCtrl = TextEditingController(text: existing?.doseNumber?.toString() ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final givenRef = <DateTime>[existing?.dateGiven ?? DateTime.now()];
    final dueRef = <DateTime?>[existing?.nextDue];

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(existing == null ? 'Add Vaccination' : 'Edit Vaccination', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
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
        LifeSaveButton(label: existing == null ? 'Save' : 'Update', color: _healthColor, onTap: () {
          if (nameCtrl.text.trim().isEmpty) return;
          final name = nameCtrl.text.trim();
          final dose = int.tryParse(doseCtrl.text.trim());
          final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
          final given = givenRef[0];
          final due = dueRef[0];
          Navigator.pop(ctx2);
          () async {
            try {
              if (existing == null) {
                final data = Vaccination(id: '', walletId: walletId, memberId: memberId, vaccineName: name, dateGiven: given, nextDue: due, doseNumber: dose, notes: notes);
                final row = await HealthService.instance.addVaccination(data.toJson());
                onAdd(Vaccination.fromJson(row));
              } else {
                final updates = {'vaccine_name': name, 'dose_number': dose, 'notes': notes, 'date_given': given.toIso8601String().substring(0, 10), if (due != null) 'next_due': due.toIso8601String().substring(0, 10)};
                await HealthService.instance.updateVaccination(existing.id, updates);
                onUpdate(Vaccination(id: existing.id, walletId: existing.walletId, memberId: existing.memberId, vaccineName: name, dateGiven: given, nextDue: due, doseNumber: dose, notes: notes));
              }
            } catch (e) { debugPrint('[Health] saveVaccine: $e'); }
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
  final VoidCallback onEdit;
  const _VaccineCard({required this.v, required this.cardBg, required this.isDark, required this.statusColor, required this.onDelete, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final tc  = isDark ? AppColors.textDark  : AppColors.textLight;
    final sub = isDark ? AppColors.subDark   : AppColors.subLight;
    return Dismissible(
      key: ValueKey(v.id),
      direction: DismissDirection.endToStart,
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.delete_rounded, color: Colors.red)),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: statusColor.withValues(alpha: 0.25))),
        child: Column(children: [
          // ── Top banner ──
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Text('💉', style: TextStyle(fontSize: 22))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.vaccineName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: tc), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (v.doseNumber != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text('Dose ${v.doseNumber}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: statusColor))),
                ],
              ])),
              if (v.isOverdue)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), child: const Text('OVERDUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: Colors.white)))
              else if (v.isDueSoon)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)), child: const Text('DUE SOON', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: Colors.white))),
              const SizedBox(width: 8),
              GestureDetector(onTap: onEdit, child: Icon(Icons.edit_outlined, size: 18, color: statusColor.withValues(alpha: 0.7))),
            ]),
          ),
          // ── Date row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(children: [
              Row(children: [
                Icon(Icons.check_circle_rounded, size: 13, color: _healthColor),
                const SizedBox(width: 5),
                Text('Given', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: sub)),
                const SizedBox(width: 4),
                Text(_fmtDate(v.dateGiven), style: TextStyle(fontSize: 11, fontFamily: 'DM Mono', fontWeight: FontWeight.w700, color: tc)),
              ]),
              if (v.nextDue != null) ...[
                const Spacer(),
                Row(children: [
                  Icon(Icons.schedule_rounded, size: 13, color: statusColor),
                  const SizedBox(width: 5),
                  Text('Next', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: sub)),
                  const SizedBox(width: 4),
                  Text(_fmtDate(v.nextDue!), style: TextStyle(fontSize: 11, fontFamily: 'DM Mono', fontWeight: FontWeight.w700, color: statusColor)),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
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
  final void Function(InsurancePolicy) onUpdate;
  const _InsuranceTab({required this.walletId, required this.memberId, required this.policies, required this.isDark, required this.surfBg, required this.onAdd, required this.onDelete, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _healthColor,
        onPressed: () => _showSheet(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Policy', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: policies.isEmpty
          ? const LifeEmptyState(emoji: '🛡️', title: 'No insurance policies', subtitle: 'Keep track of your health insurance')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              for (final p in policies) () {
                final tc  = isDark ? AppColors.textDark  : AppColors.textLight;
                final sub = isDark ? AppColors.subDark   : AppColors.subLight;
                final accent = p.isExpired ? Colors.red : p.expiresSoon ? Colors.orange : _healthColor;
                return Dismissible(
                  key: ValueKey(p.id),
                  direction: DismissDirection.endToStart,
                  background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.delete_rounded, color: Colors.red)),
                  confirmDismiss: (_) => confirmDelete(context),
                  onDismissed: (_) async { try { await HealthService.instance.deleteInsurance(p.id); onDelete(p.id); } catch (e) { debugPrint('[Health] deleteInsurance: $e'); } },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: accent.withValues(alpha: 0.25))),
                    child: Column(children: [
                      // ── Header ──
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.07),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                        child: Row(children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(13)),
                            alignment: Alignment.center,
                            child: const Text('🛡️', style: TextStyle(fontSize: 24))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.policyName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: tc), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (p.provider != null) ...[
                              const SizedBox(height: 3),
                              Text(p.provider!, style: TextStyle(fontSize: 12, fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: accent)),
                            ],
                          ])),
                          if (p.isExpired)
                            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), child: const Text('EXPIRED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: Colors.white)))
                          else if (p.expiresSoon)
                            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)), child: const Text('EXPIRING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: Colors.white))),
                          const SizedBox(width: 8),
                          GestureDetector(onTap: () => _showSheet(context, existing: p), child: Icon(Icons.edit_outlined, size: 18, color: accent.withValues(alpha: 0.7))),
                        ]),
                      ),
                      // ── Stats row ──
                      if (p.policyNumber != null || p.coverageAmount != null || p.expiryDate != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Row(children: [
                            if (p.policyNumber != null) ...[
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('POLICY NO.', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: sub, letterSpacing: 0.5)),
                                const SizedBox(height: 3),
                                Text(p.policyNumber!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'DM Mono', color: tc), overflow: TextOverflow.ellipsis),
                              ])),
                            ],
                            if (p.coverageAmount != null) ...[
                              if (p.policyNumber != null) const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('COVERAGE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: sub, letterSpacing: 0.5)),
                                const SizedBox(height: 3),
                                Text('₹${p.coverageAmount!.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'DM Mono', color: _healthColor)),
                              ])),
                            ],
                            if (p.expiryDate != null) ...[
                              if (p.policyNumber != null || p.coverageAmount != null) const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('EXPIRES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: sub, letterSpacing: 0.5)),
                                const SizedBox(height: 3),
                                Text(_fmtDate(p.expiryDate!), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'DM Mono', color: accent)),
                              ])),
                            ],
                          ]),
                        ),
                    ]),
                  ),
                );
              }(),
            ]),
    );
  }

  void _showSheet(BuildContext ctx, {InsurancePolicy? existing}) {
    final nameCtrl = TextEditingController(text: existing?.policyName ?? '');
    final numCtrl = TextEditingController(text: existing?.policyNumber ?? '');
    final provCtrl = TextEditingController(text: existing?.provider ?? '');
    final covCtrl = TextEditingController(text: existing?.coverageAmount?.toStringAsFixed(0) ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final expiryRef = <DateTime?>[existing?.expiryDate];

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(existing == null ? 'Add Insurance Policy' : 'Edit Insurance Policy', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
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
        LifeSaveButton(label: existing == null ? 'Save' : 'Update', color: _healthColor, onTap: () {
          if (nameCtrl.text.trim().isEmpty) return;
          final policyName = nameCtrl.text.trim();
          final policyNumber = numCtrl.text.trim().isEmpty ? null : numCtrl.text.trim();
          final provider = provCtrl.text.trim().isEmpty ? null : provCtrl.text.trim();
          final coverageAmount = double.tryParse(covCtrl.text.trim());
          final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
          final expiry = expiryRef[0];
          Navigator.pop(ctx2);
          () async {
            try {
              if (existing == null) {
                final policy = InsurancePolicy(id: '', walletId: walletId, memberId: memberId, policyName: policyName, policyNumber: policyNumber, provider: provider, coverageAmount: coverageAmount, expiryDate: expiry, notes: notes);
                final row = await HealthService.instance.addInsurance(policy.toJson());
                onAdd(InsurancePolicy.fromJson(row));
              } else {
                final updates = {'policy_name': policyName, if (policyNumber != null) 'policy_number': policyNumber, if (provider != null) 'provider': provider, if (coverageAmount != null) 'coverage_amount': coverageAmount, if (expiry != null) 'expiry_date': expiry.toIso8601String().substring(0, 10), if (notes != null) 'notes': notes};
                await HealthService.instance.updateInsurance(existing.id, updates);
                onUpdate(InsurancePolicy(id: existing.id, walletId: existing.walletId, memberId: existing.memberId, policyName: policyName, policyNumber: policyNumber, provider: provider, coverageAmount: coverageAmount, expiryDate: expiry, notes: notes));
              }
            } catch (e) { debugPrint('[Health] saveInsurance: $e'); }
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
    final tc  = isDark ? AppColors.textDark  : AppColors.textLight;
    final sub = isDark ? AppColors.subDark   : AppColors.subLight;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [

      // ── Identity header card ────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.red.withValues(alpha: 0.15), Colors.red.withValues(alpha: 0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withValues(alpha: 0.35), width: 1.5)),
        child: Row(children: [
          Container(
            width: 60, height: 60,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 30)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('EMERGENCY CARD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: Colors.red, letterSpacing: 1.2)),
            const SizedBox(height: 3),
            Text('${member.emoji}  ${member.name}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: tc)),
          ])),
          if (p?.bloodGroup != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text(p!.bloodGroup!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: Colors.white)),
                const Text('Blood', style: TextStyle(fontSize: 9, fontFamily: 'Nunito', color: Colors.white70, fontWeight: FontWeight.w700)),
              ])),
        ]),
      ),

      if (p == null) ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withValues(alpha: 0.15))),
          child: Column(children: [
            const Text('🏥', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('Profile Not Set Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
            const SizedBox(height: 6),
            Text('Go to the Profile tab to fill in your medical details. They will appear here for emergencies.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: sub)),
          ]),
        ),
      ] else ...[

        // ── Medical info sections ──────────────────────────────────────
        if (p.allergies.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: const Text('⚠️', style: TextStyle(fontSize: 14))),
                const SizedBox(width: 8),
                const Text('ALLERGIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: Colors.orange, letterSpacing: 0.8)),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: p.allergies.map((a) => _chip(a, Colors.orange)).toList()),
            ]),
          ),
        ],

        if (p.conditions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withValues(alpha: 0.25))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: const Text('🩺', style: TextStyle(fontSize: 14))),
                const SizedBox(width: 8),
                const Text('CONDITIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: Colors.red, letterSpacing: 0.8)),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: p.conditions.map((c) => _chip(c, Colors.red)).toList()),
            ]),
          ),
        ],

        if (meds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _healthColor.withValues(alpha: 0.25))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 28, height: 28, decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: const Text('💊', style: TextStyle(fontSize: 14))),
                const SizedBox(width: 8),
                const Text('ACTIVE MEDICATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: _healthColor, letterSpacing: 0.8)),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: meds.map((m) => _chip('${m.name} ${m.dosage}', _healthColor)).toList()),
            ]),
          ),
        ],

        // ── Emergency contact card ─────────────────────────────────────
        if (p.emergencyContact != null) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withValues(alpha: 0.25))),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.07), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                child: Row(children: [
                  Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: const Text('🚨', style: TextStyle(fontSize: 14))),
                  const SizedBox(width: 8),
                  const Text('EMERGENCY CONTACT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: Colors.red, letterSpacing: 0.8)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.person_rounded, color: Colors.red, size: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.emergencyContact!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: tc)),
                    if (p.emergencyPhone != null)
                      Text(p.emergencyPhone!, style: const TextStyle(fontSize: 13, fontFamily: 'DM Mono', fontWeight: FontWeight.w700, color: Colors.red)),
                  ])),
                  if (p.emergencyPhone != null)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: p.emergencyPhone!));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone copied'), duration: Duration(seconds: 1)));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.copy_rounded, color: Colors.white, size: 18))),
                ]),
              ),
            ]),
          ),
        ],
      ],
    ]);
  }
}

