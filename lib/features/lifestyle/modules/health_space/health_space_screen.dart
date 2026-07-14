import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/confirm_delete.dart';
import '../../../../../core/services/ai_parser.dart';
import 'package:wai_life_assistant/shared/utils/ai_limit_snackbar.dart';
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


// ── Shared AI helpers ─────────────────────────────────────────────────────────

Widget _aiButton(bool active, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      gradient: active ? null : const LinearGradient(colors: [_healthColor, Color(0xFF00897B)]),
      color: active ? _healthColor.withValues(alpha: 0.15) : null,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('✦', style: TextStyle(fontSize: 12, color: active ? _healthColor : Colors.white)),
      const SizedBox(width: 5),
      Text('Fill with AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
        fontFamily: 'Nunito', color: active ? _healthColor : Colors.white)),
    ]),
  ),
);

Widget _aiBox(TextEditingController ctrl, bool parsing, Future<void> Function() onFill,
    Color sub, Color surfBg, bool isDark, {required String hint}) =>
  Container(
    decoration: BoxDecoration(
      color: surfBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _healthColor.withValues(alpha: 0.35)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: TextField(
          controller: ctrl,
          maxLines: 3,
          minLines: 2,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(fontSize: 13, fontFamily: 'Nunito',
            color: isDark ? AppColors.textDark : AppColors.textLight),
          decoration: InputDecoration.collapsed(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito', height: 1.45),
          ),
        ),
      ),
      Divider(height: 1, indent: 14, endIndent: 14, color: _healthColor.withValues(alpha: 0.2)),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
        child: Row(children: [
          Expanded(child: Text('Plain text → AI fills all fields',
            style: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito'))),
          GestureDetector(
            onTap: parsing ? null : onFill,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                gradient: parsing ? null : const LinearGradient(colors: [_healthColor, Color(0xFF00897B)]),
                color: parsing ? _healthColor.withValues(alpha: 0.3) : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: parsing
                ? const SizedBox(width: 64, height: 16,
                    child: LinearProgressIndicator(backgroundColor: Colors.transparent, color: Colors.white))
                : const Text('Fill →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito', color: Colors.white)),
            ),
          ),
        ]),
      ),
    ]),
  );

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
    final aiCtrl = TextEditingController();
    bool aiActive = false;
    bool aiParsing = false;
    String? aiError;

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

      void applyAiData(Map<String, dynamic> data) {
        final bg = data['blood_group'] as String?;
        final ht = data['height'] as String?;
        final wt = data['weight'] as String?;
        final allergies = (data['allergies'] as List<dynamic>?)?.cast<String>() ?? [];
        final conditions = (data['conditions'] as List<dynamic>?)?.cast<String>() ?? [];
        final disabilities = (data['disabilities'] as List<dynamic>?)?.cast<String>() ?? [];
        final ec = data['emergency_contact'] as String?;
        final ep = data['emergency_phone'] as String?;
        ss(() {
          if (bg != null && bg.isNotEmpty) bgCtrl.text = bg;
          if (ht != null && ht.isNotEmpty) htCtrl.text = ht;
          if (wt != null && wt.isNotEmpty) wtCtrl.text = wt;
          for (final a in allergies) {
            if (!allergiesRef[0].contains(a)) allergiesRef[0].add(a);
          }
          for (final c in conditions) {
            if (!conditionsRef[0].contains(c)) conditionsRef[0].add(c);
          }
          for (final d in disabilities) {
            if (!disabilitiesRef[0].contains(d)) disabilitiesRef[0].add(d);
          }
          if (ec != null && ec.isNotEmpty) ecCtrl.text = ec;
          if (ep != null && ep.isNotEmpty) epCtrl.text = ep;
          aiActive = false;
          aiCtrl.clear();
        });
      }

      // Local regex fallback when AI is unavailable
      Map<String, dynamic> parseLocally(String text) {
        final result = <String, dynamic>{};
        // Blood group
        final bgMatch = RegExp(r'\b(AB|A|B|O)\s*(positive|negative|\+|-)\b', caseSensitive: false).firstMatch(text);
        if (bgMatch != null) {
          final group = bgMatch.group(1)!.toUpperCase();
          final sign = bgMatch.group(2)!.toLowerCase();
          result['blood_group'] = '$group${(sign == 'positive' || sign == '+') ? '+' : '-'}';
        }
        // Height cm
        final htCm = RegExp(r'(\d+(?:\.\d+)?)\s*cm', caseSensitive: false).firstMatch(text);
        if (htCm != null) result['height'] = htCm.group(1)!;
        // Weight kg
        final wtKg = RegExp(r'(\d+(?:\.\d+)?)\s*kg', caseSensitive: false).firstMatch(text);
        if (wtKg != null) result['weight'] = wtKg.group(1)!;
        // Allergies
        final allergyMatch = RegExp(r'allerg(?:ic\s+to|y\s*:?)\s+([^.;\n]+)', caseSensitive: false).firstMatch(text);
        if (allergyMatch != null) {
          result['allergies'] = allergyMatch.group(1)!
              .split(RegExp(r'[,&]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        }
        // Conditions — keyword scan
        final conditionWords = ['diabetes', 'diabetic', 'hypertension', 'asthma', 'thyroid',
          'arthritis', 'migraine', 'cardiac', 'cholesterol', 'bp', 'pcod', 'pcos',
          'anemia', 'epilepsy', 'depression', 'anxiety'];
        final found = conditionWords.where((w) => text.toLowerCase().contains(w)).toList();
        if (found.isNotEmpty) result['conditions'] = found;
        return result;
      }

      Future<void> runAI() async {
        final text = aiCtrl.text.trim();
        if (text.isEmpty) return;
        ss(() { aiParsing = true; aiError = null; });
        try {
          final result = await AIParser.parseText(
            feature: 'lifestyle',
            subFeature: 'health_profile',
            text: text,
          );
          if (!ctx2.mounted) return;
          if (result.success && result.data != null) {
            applyAiData(result.data!);
          } else {
            maybeShowAiLimitSnackbar(ctx2, result.error);
            // Fallback to local parser
            applyAiData(parseLocally(text));
          }
        } catch (_) {
          if (!ctx2.mounted) return;
          applyAiData(parseLocally(aiCtrl.text.trim()));
        } finally {
          if (ctx2.mounted) ss(() => aiParsing = false);
        }
      }

      final isDark = Theme.of(ctx2).brightness == Brightness.dark;
      final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
      final sub    = isDark ? AppColors.subDark  : AppColors.subLight;

      return Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 36), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [

        // ── Header ──────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Expanded(child: Text('Edit Health Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito'))),
          GestureDetector(
            onTap: () => ss(() { aiActive = !aiActive; aiError = null; }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: aiActive ? null : const LinearGradient(
                  colors: [_healthColor, Color(0xFF00897B)]),
                color: aiActive ? _healthColor.withValues(alpha: 0.15) : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('✦', style: TextStyle(fontSize: 12,
                  color: aiActive ? _healthColor : Colors.white)),
                const SizedBox(width: 5),
                Text('Fill with AI',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: aiActive ? _healthColor : Colors.white)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // ── AI input box ─────────────────────────────────────────────────
        if (aiActive) ...[
          Container(
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _healthColor.withValues(alpha: 0.35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: TextField(
                  controller: aiCtrl,
                  maxLines: 3,
                  minLines: 2,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 13, fontFamily: 'Nunito',
                    color: isDark ? AppColors.textDark : AppColors.textLight),
                  decoration: InputDecoration.collapsed(
                    hintText: 'e.g. "I\'m O+, 172cm, 68kg, allergic to penicillin, have diabetes and hypertension. Emergency: Priya, 9876543210"',
                    hintStyle: TextStyle(fontSize: 12, color: sub,
                      fontFamily: 'Nunito', height: 1.45),
                  ),
                ),
              ),
              Divider(height: 1, indent: 14, endIndent: 14,
                color: _healthColor.withValues(alpha: 0.2)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
                child: Row(children: [
                  Expanded(child: Text('Plain text → AI fills all fields',
                    style: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito'))),
                  GestureDetector(
                    onTap: aiParsing ? null : runAI,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: aiParsing ? null
                          : const LinearGradient(colors: [_healthColor, Color(0xFF00897B)]),
                        color: aiParsing ? _healthColor.withValues(alpha: 0.3) : null,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: aiParsing
                        ? const SizedBox(width: 64, height: 16,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.transparent,
                              color: Colors.white))
                        : const Text('Fill →',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito', color: Colors.white)),
                    ),
                  ),
                ]),
              ),
              if (aiError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Text(aiError!,
                    style: TextStyle(fontSize: 11, color: Colors.red.withValues(alpha: 0.8),
                      fontFamily: 'Nunito')),
                ),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // ── Form fields ──────────────────────────────────────────────────
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
          final messenger = ScaffoldMessenger.of(ctx2);
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
              messenger.showSnackBar(const SnackBar(content: Text('Failed to save profile')));
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
                  onDelete: () async {
                    try {
                      await HealthService.instance.deleteMedication(m.id);
                      onDelete(m.id);
                    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_delete_med'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete medication'))); }
                  },
                  onEdit: () => _showMedSheet(context, existing: m),
                  onToggle: () async {
                    try {
                      await HealthService.instance.updateMedication(m.id, {'is_active': false});
                      onToggle(Medication(id: m.id, walletId: m.walletId, memberId: m.memberId, name: m.name, dosage: m.dosage, frequency: m.frequency, scheduleTimes: m.scheduleTimes, mealTiming: m.mealTiming, notes: m.notes, isActive: false, startDate: m.startDate, endDate: m.endDate, refillDate: m.refillDate));
                    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_deactivate_med'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update medication'))); }
                  })),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 8),
                const LifeLabel(text: 'PAST MEDICATIONS'),
                ...past.map((m) => _MedCard(m: m, cardBg: cardBg, isDark: isDark,
                  onDelete: () async {
                    try {
                      await HealthService.instance.deleteMedication(m.id);
                      onDelete(m.id);
                    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_delete_med'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete medication'))); }
                  },
                  onEdit: () => _showMedSheet(context, existing: m),
                  onToggle: () async {
                    try {
                      await HealthService.instance.updateMedication(m.id, {'is_active': true});
                      onToggle(Medication(id: m.id, walletId: m.walletId, memberId: m.memberId, name: m.name, dosage: m.dosage, frequency: m.frequency, scheduleTimes: m.scheduleTimes, mealTiming: m.mealTiming, notes: m.notes, isActive: true, startDate: m.startDate, endDate: m.endDate, refillDate: m.refillDate));
                    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_activate_med'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update medication'))); }
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

    final aiCtrl    = TextEditingController();
    bool aiActive   = false;
    bool aiParsing  = false;

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) {
      final isDark = ctx2.isDark;
      final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
      final sub = isDark ? AppColors.subDark : AppColors.subLight;

      void applyMedAiData(Map<String, dynamic> data) {
        final name      = data['name']       as String?;
        final dosage    = data['dosage']     as String?;
        final freq      = data['frequency']  as String?;
        final times     = (data['schedule_times'] as List<dynamic>?)?.cast<String>() ?? [];
        final meal      = data['meal_timing'] as String?;
        final durLabel  = data['duration_label'] as String?;
        final notesVal  = data['notes']      as String?;
        ss(() {
          if (name    != null && name.isNotEmpty)   nameCtrl.text   = name;
          if (dosage  != null && dosage.isNotEmpty) dosageCtrl.text = dosage;
          if (freq    != null && freq.isNotEmpty)   freqCtrl.text   = freq;
          if (times.isNotEmpty) scheduleTimesRef[0] = times;
          if (meal    != null && meal.isNotEmpty)   mealTimingRef[0] = meal;
          if (durLabel != null) {
            final valid = durations.any((d) => d.$1 == durLabel);
            if (valid) {
              durationLabel[0] = durLabel;
              endRef[0] = computeEnd(startRef[0], durLabel);
            }
          }
          if (notesVal != null && notesVal.isNotEmpty) notesCtrl.text = notesVal;
          aiActive = false;
          aiCtrl.clear();
        });
      }

      Map<String, dynamic> parseMedLocally(String text) {
        final result = <String, dynamic>{};
        // Medicine name — first capitalized word(s) before dosage
        final nameMatch = RegExp(r'^([A-Za-z][A-Za-z\s]+?)(?:\s+\d)', multiLine: false).firstMatch(text.trim());
        if (nameMatch != null) result['name'] = nameMatch.group(1)!.trim();
        // Dosage
        final dosageMatch = RegExp(r'(\d+(?:\.\d+)?\s*(?:mg|mcg|ml|g|iu|units?))', caseSensitive: false).firstMatch(text);
        if (dosageMatch != null) result['dosage'] = dosageMatch.group(1)!;
        // Frequency
        final freqMap = {
          r'once\s+(a\s+)?day|1\s+time': 'Once daily',
          r'twice\s+(a\s+)?day|2\s+times': 'Twice daily',
          r'three\s+times|thrice': 'Thrice daily',
          r'every\s+8\s+hours': 'Every 8 hours',
          r'every\s+12\s+hours': 'Every 12 hours',
          r'once\s+a\s+week': 'Once a week',
          r'as\s+needed|sos': 'As needed',
        };
        for (final entry in freqMap.entries) {
          if (RegExp(entry.key, caseSensitive: false).hasMatch(text)) {
            result['frequency'] = entry.value;
            break;
          }
        }
        // Schedule times
        final times = <String>[];
        if (RegExp(r'\bmorning\b', caseSensitive: false).hasMatch(text)) times.add('Morning');
        if (RegExp(r'\bafternoon\b', caseSensitive: false).hasMatch(text)) times.add('Afternoon');
        if (RegExp(r'\bevening\b', caseSensitive: false).hasMatch(text)) times.add('Evening');
        if (RegExp(r'\bnight\b|\bbedtime\b', caseSensitive: false).hasMatch(text)) times.add('Night');
        if (times.isNotEmpty) result['schedule_times'] = times;
        // Meal timing
        if (RegExp(r'\bbefore\s+(food|meal|eating)\b', caseSensitive: false).hasMatch(text)) {
          result['meal_timing'] = 'Before food';
        } else if (RegExp(r'\bafter\s+(food|meal|eating)\b', caseSensitive: false).hasMatch(text)) {
          result['meal_timing'] = 'After food';
        }
        // Duration
        final durPatterns = {
          r'3\s*days?': '3 Days', r'5\s*days?': '5 Days', r'7\s*days?|one\s+week': '7 Days',
          r'10\s*days?': '10 Days', r'14\s*days?|two\s+weeks?|fortnight': '14 Days',
          r'1\s*month|one\s+month': '1 Month', r'3\s*months?|three\s+months?': '3 Months',
          r'6\s*months?|six\s+months?': '6 Months', r'ongoing|lifelong|life\s+long|chronic': 'Ongoing',
        };
        for (final e in durPatterns.entries) {
          if (RegExp(e.key, caseSensitive: false).hasMatch(text)) {
            result['duration_label'] = e.value;
            break;
          }
        }
        return result;
      }

      Future<void> runMedAI() async {
        final text = aiCtrl.text.trim();
        if (text.isEmpty) return;
        ss(() { aiParsing = true; });
        try {
          final result = await AIParser.parseText(
            feature: 'lifestyle', subFeature: 'medication', text: text);
          if (!ctx2.mounted) return;
          if (result.success && result.data != null) {
            applyMedAiData(result.data!);
          } else {
            maybeShowAiLimitSnackbar(ctx2, result.error);
            applyMedAiData(parseMedLocally(text));
          }
        } catch (_) {
          if (!ctx2.mounted) return;
          applyMedAiData(parseMedLocally(aiCtrl.text.trim()));
        } finally {
          if (ctx2.mounted) ss(() => aiParsing = false);
        }
      }

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
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Text(existing == null ? 'Add Medication' : 'Edit Medication',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito'))),
            GestureDetector(
              onTap: () => ss(() { aiActive = !aiActive; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: aiActive ? null : const LinearGradient(colors: [_healthColor, Color(0xFF00897B)]),
                  color: aiActive ? _healthColor.withValues(alpha: 0.15) : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('✦', style: TextStyle(fontSize: 12, color: aiActive ? _healthColor : Colors.white)),
                  const SizedBox(width: 5),
                  Text('Fill with AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito', color: aiActive ? _healthColor : Colors.white)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (aiActive) ...[
            Container(
              decoration: BoxDecoration(
                color: surfBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _healthColor.withValues(alpha: 0.35)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: TextField(
                    controller: aiCtrl,
                    maxLines: 3,
                    minLines: 2,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(fontSize: 13, fontFamily: 'Nunito',
                      color: isDark ? AppColors.textDark : AppColors.textLight),
                    decoration: InputDecoration.collapsed(
                      hintText: 'e.g. "Metformin 500mg, twice daily after food, morning and night, for 3 months"',
                      hintStyle: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito', height: 1.45),
                    ),
                  ),
                ),
                Divider(height: 1, indent: 14, endIndent: 14, color: _healthColor.withValues(alpha: 0.2)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
                  child: Row(children: [
                    Expanded(child: Text('Plain text → AI fills all fields',
                      style: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito'))),
                    GestureDetector(
                      onTap: aiParsing ? null : runMedAI,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          gradient: aiParsing ? null : const LinearGradient(colors: [_healthColor, Color(0xFF00897B)]),
                          color: aiParsing ? _healthColor.withValues(alpha: 0.3) : null,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: aiParsing
                          ? const SizedBox(width: 64, height: 16,
                              child: LinearProgressIndicator(backgroundColor: Colors.transparent, color: Colors.white))
                          : const Text('Fill →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito', color: Colors.white)),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],
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
            final messenger = ScaffoldMessenger.of(ctx2);
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
              } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_save_med'); messenger.showSnackBar(const SnackBar(content: Text('Failed to save medication'))); }
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
  final Future<void> Function() onDelete;
  final VoidCallback onToggle, onEdit;
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
                    try {
                      await HealthService.instance.deleteDoctor(d.id);
                      onDelete(d.id);
                    } catch (e, stack) {
                      ErrorLogger.log(e, stackTrace: stack, action: 'health_delete_doctor');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete doctor')));
                      }
                    }
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
    final aiCtrl    = TextEditingController();
    bool aiActive   = false;
    bool aiParsing  = false;

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) {
      final isDark = Theme.of(ctx2).brightness == Brightness.dark;
      final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
      final sub    = isDark ? AppColors.subDark  : AppColors.subLight;

      void applyDocAiData(Map<String, dynamic> data) {
        final name     = data['name']      as String?;
        final spec     = data['specialty'] as String?;
        final hosp     = data['hospital']  as String?;
        final phone    = data['phone']     as String?;
        final notesVal = data['notes']     as String?;
        ss(() {
          if (name     != null && name.isNotEmpty)     nameCtrl.text  = name;
          if (spec     != null && spec.isNotEmpty)     specCtrl.text  = spec;
          if (hosp     != null && hosp.isNotEmpty)     hospCtrl.text  = hosp;
          if (phone    != null && phone.isNotEmpty)    phoneCtrl.text = phone;
          if (notesVal != null && notesVal.isNotEmpty) notesCtrl.text = notesVal;
          aiActive = false;
          aiCtrl.clear();
        });
      }

      Future<void> runDocAI() async {
        final text = aiCtrl.text.trim();
        if (text.isEmpty) return;
        ss(() => aiParsing = true);
        try {
          final result = await AIParser.parseText(
            feature: 'lifestyle', subFeature: 'doctor', text: text);
          if (!ctx2.mounted) return;
          if (result.success && result.data != null) {
            applyDocAiData(result.data!);
          } else {
            maybeShowAiLimitSnackbar(ctx2, result.error);
            // Simple local fallback — just put the whole text in name
            ss(() { if (nameCtrl.text.isEmpty) nameCtrl.text = text; aiActive = false; });
          }
        } catch (_) {
          if (!ctx2.mounted) return;
          ss(() { if (nameCtrl.text.isEmpty) nameCtrl.text = text; aiActive = false; });
        } finally {
          if (ctx2.mounted) ss(() => aiParsing = false);
        }
      }

      return Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 36), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Text(existing == null ? 'Add Doctor' : 'Edit Doctor',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito'))),
          GestureDetector(
            onTap: () => ss(() => aiActive = !aiActive),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: aiActive ? null : const LinearGradient(colors: [_healthColor, Color(0xFF00897B)]),
                color: aiActive ? _healthColor.withValues(alpha: 0.15) : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('✦', style: TextStyle(fontSize: 12, color: aiActive ? _healthColor : Colors.white)),
                const SizedBox(width: 5),
                Text('Fill with AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito', color: aiActive ? _healthColor : Colors.white)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (aiActive) ...[
          Container(
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _healthColor.withValues(alpha: 0.35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: TextField(
                  controller: aiCtrl,
                  maxLines: 3,
                  minLines: 2,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 13, fontFamily: 'Nunito',
                    color: isDark ? AppColors.textDark : AppColors.textLight),
                  decoration: InputDecoration.collapsed(
                    hintText: 'e.g. "Dr. Ramesh Kumar, Cardiologist at Apollo Hospital, Chennai. 9876543210"',
                    hintStyle: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito', height: 1.45),
                  ),
                ),
              ),
              Divider(height: 1, indent: 14, endIndent: 14, color: _healthColor.withValues(alpha: 0.2)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
                child: Row(children: [
                  Expanded(child: Text('Plain text → AI fills all fields',
                    style: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito'))),
                  GestureDetector(
                    onTap: aiParsing ? null : runDocAI,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: aiParsing ? null : const LinearGradient(colors: [_healthColor, Color(0xFF00897B)]),
                        color: aiParsing ? _healthColor.withValues(alpha: 0.3) : null,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: aiParsing
                        ? const SizedBox(width: 64, height: 16,
                            child: LinearProgressIndicator(backgroundColor: Colors.transparent, color: Colors.white))
                        : const Text('Fill →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito', color: Colors.white)),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
        ],
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
          final messenger = ScaffoldMessenger.of(ctx2);
          Navigator.pop(ctx2);
          if (existing == null) {
            final data = DoctorRecord(id: '', walletId: walletId, memberId: memberId, name: name, specialty: specialty, hospital: hospital, phone: phone, notes: notes);
            () async { try { final row = await HealthService.instance.addDoctor(data.toJson()); onAdd(DoctorRecord.fromJson(row)); } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_add_doctor'); messenger.showSnackBar(const SnackBar(content: Text('Failed to save doctor'))); } }();
          } else {
            final updates = {'name': name, 'specialty': specialty, 'hospital': hospital, 'phone': phone, 'notes': notes};
            () async { try { await HealthService.instance.updateDoctor(existing.id, updates); onUpdate(DoctorRecord(id: existing.id, walletId: existing.walletId, memberId: existing.memberId, name: name, specialty: specialty, hospital: hospital, phone: phone, notes: notes)); } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_update_doctor'); messenger.showSnackBar(const SnackBar(content: Text('Failed to save doctor'))); } }();
          }
        }),
      ]));
    }));
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
                    try { await HealthService.instance.deleteDocument(d.id, d.fileUrls); onDelete(d.id); } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_delete_doc'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete document'))); }
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
                      // ── Body (notes + attachments) ──
                      if (d.notes != null || d.fileUrls.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (d.notes != null) Text(d.notes!, style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: isDark ? AppColors.subDark : AppColors.subLight), maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (d.fileUrls.isNotEmpty) ...[
                              if (d.notes != null) const SizedBox(height: 8),
                              Wrap(spacing: 6, runSpacing: 6, children: [
                                for (int i = 0; i < d.fileUrls.length; i++)
                                  GestureDetector(
                                    onTap: () => launchUrl(Uri.parse(d.fileUrls[i]), mode: LaunchMode.externalApplication),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(color: _healthColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _healthColor.withValues(alpha: 0.3))),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(d.fileUrls[i].endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.image_rounded, size: 14, color: _healthColor),
                                        const SizedBox(width: 6),
                                        Text(d.fileUrls.length == 1 ? 'View Attachment' : 'Attachment ${i + 1}', style: const TextStyle(fontSize: 12, fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: _healthColor)),
                                        const SizedBox(width: 4),
                                        Icon(Icons.open_in_new_rounded, size: 12, color: _healthColor.withValues(alpha: 0.7)),
                                      ]),
                                    ),
                                  ),
                              ]),
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
    final typeRef   = <MedDocType>[existing?.docType ?? MedDocType.prescription];
    final dateRef   = <DateTime>[existing?.docDate ?? DateTime.now()];
    // existingUrls: already-uploaded URLs (shown in edit mode; user can remove them)
    final existingUrls = <String>[...?existing?.fileUrls];
    // newLocalPaths: newly picked local files (to be uploaded on save)
    final newLocalPaths = <String>[];

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) {
      final surfBg = ctx2.isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
      final sub    = ctx2.isDark ? AppColors.subDark  : AppColors.subLight;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(existing == null ? 'Add Document' : 'Edit Document',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
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
                  decoration: BoxDecoration(color: typeRef[0] == t ? _healthColor.withValues(alpha: 0.15) : surfBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: typeRef[0] == t ? _healthColor : Colors.transparent)),
                  child: Text('${t.emoji} ${t.label}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: typeRef[0] == t ? _healthColor : sub)),
                ),
              ),
          ])),
          const SizedBox(height: 8),
          LifeInput(controller: titleCtrl, hint: 'Title *'),
          const SizedBox(height: 8),
          LifeDateTile(date: dateRef[0], hint: 'Document Date', color: _healthColor,
              onTap: () async { final d = await _pickDate(ctx2, initial: dateRef[0]); if (d != null) ss(() => dateRef[0] = d); }),
          const SizedBox(height: 8),
          LifeInput(controller: notesCtrl, hint: 'Notes', maxLines: 2),
          const SizedBox(height: 12),

          // ── Attachments section ──────────────────────────────────────────
          Text('ATTACHMENTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1, fontFamily: 'Nunito', color: sub)),
          const SizedBox(height: 8),
          // Existing uploaded URLs
          if (existingUrls.isNotEmpty) ...[
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (int i = 0; i < existingUrls.length; i++)
                _AttachmentChip(
                  label: 'File ${i + 1}',
                  isPdf: existingUrls[i].endsWith('.pdf'),
                  isLocal: false,
                  onRemove: () => ss(() => existingUrls.removeAt(i)),
                  onTap: () => launchUrl(Uri.parse(existingUrls[i]), mode: LaunchMode.externalApplication),
                ),
            ]),
            const SizedBox(height: 8),
          ],
          // Newly picked local files
          if (newLocalPaths.isNotEmpty) ...[
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (int i = 0; i < newLocalPaths.length; i++)
                _AttachmentChip(
                  label: newLocalPaths[i].split('/').last.split('\\').last,
                  isPdf: newLocalPaths[i].toLowerCase().endsWith('.pdf'),
                  isLocal: true,
                  localPath: newLocalPaths[i],
                  onRemove: () => ss(() => newLocalPaths.removeAt(i)),
                ),
            ]),
            const SizedBox(height: 8),
          ],
          // Add attachment button
          GestureDetector(
            onTap: () async {
              final p = await _pickPhoto(ctx2);
              if (p != null) ss(() => newLocalPaths.add(p));
            },
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: _healthColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _healthColor.withValues(alpha: 0.3), style: BorderStyle.solid),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate_rounded, color: _healthColor.withValues(alpha: 0.7), size: 22),
                const SizedBox(width: 8),
                Text('Add Attachment', style: TextStyle(fontSize: 13, fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: _healthColor.withValues(alpha: 0.8))),
              ]),
            ),
          ),
          const SizedBox(height: 4),

          LifeSaveButton(label: existing == null ? 'Save' : 'Update', color: _healthColor, onTap: () {
            if (titleCtrl.text.trim().isEmpty) return;
            final title      = titleCtrl.text.trim();
            final notes      = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
            final type       = typeRef[0];
            final date       = dateRef[0];
            final retained   = List<String>.from(existingUrls);
            final newPaths   = List<String>.from(newLocalPaths);
            final messenger = ScaffoldMessenger.of(ctx2);
            Navigator.pop(ctx2);
            () async {
              try {
                final svc = HealthService.instance;
                // Upload newly picked files
                final newUrls = newPaths.isNotEmpty
                    ? await svc.uploadDocs(newPaths, memberId: memberId)
                    : <String>[];
                final allUrls = [...retained, ...newUrls];
                if (existing == null) {
                  final data = MedicalDocument(id: '', walletId: walletId, memberId: memberId, title: title, docType: type, fileUrls: allUrls, notes: notes, docDate: date);
                  final row = await svc.addDocument(data.toJson());
                  onAdd(MedicalDocument.fromJson(row));
                } else {
                  // Delete removed URLs from storage
                  final removedUrls = existing.fileUrls.where((u) => !retained.contains(u)).toList();
                  await Future.wait(removedUrls.map(svc.deleteDoc));
                  final updates = {'title': title, 'doc_type': type.name, 'doc_date': date.toIso8601String().substring(0, 10), 'file_urls': allUrls, if (notes != null) 'notes': notes else 'notes': null};
                  await svc.updateDocument(existing.id, updates);
                  onUpdate(MedicalDocument(id: existing.id, walletId: existing.walletId, memberId: existing.memberId, title: title, docType: type, fileUrls: allUrls, notes: notes, docDate: date));
                }
              } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_save_doc'); messenger.showSnackBar(const SnackBar(content: Text('Failed to save document'))); }
            }();
          }),
        ]),
      );
    }));
  }
}

extension _CtxDark on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTACHMENT CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _AttachmentChip extends StatelessWidget {
  final String label;
  final bool isPdf;
  final bool isLocal;
  final String? localPath;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const _AttachmentChip({
    required this.label,
    required this.isPdf,
    required this.isLocal,
    required this.onRemove,
    this.localPath,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        decoration: BoxDecoration(
          color: _healthColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _healthColor.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // Thumbnail for local images; icon otherwise
          if (isLocal && !isPdf && localPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(File(localPath!), width: 32, height: 32, fit: BoxFit.cover),
            )
          else
            Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
              size: 22,
              color: _healthColor,
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 16, color: _healthColor.withValues(alpha: 0.7)),
          ),
        ]),
      ),
    );
  }
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
                  onDelete: () async { try { await HealthService.instance.deleteAppointment(a.id); onDelete(a.id); } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_delete_appt'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete appointment'))); } },
                  onEdit: () => _showSheet(context, existing: a))),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 8),
                const LifeLabel(text: 'PAST'),
                ...past.map((a) => _ApptCard(a: a, cardBg: cardBg, isDark: isDark,
                  onDelete: () async { try { await HealthService.instance.deleteAppointment(a.id); onDelete(a.id); } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_delete_appt'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete appointment'))); } },
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
    final aiCtrl   = TextEditingController();
    bool aiActive  = false;
    bool aiParsing = false;

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) {
      final isDark = Theme.of(ctx2).brightness == Brightness.dark;
      final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
      final sub    = isDark ? AppColors.subDark  : AppColors.subLight;

      void applyData(Map<String, dynamic> data) {
        final doctor   = data['doctor_name'] as String?;
        final time     = data['time']        as String?;
        final location = data['location']    as String?;
        final notesVal = data['notes']       as String?;
        final dateStr  = data['date']        as String?;
        ss(() {
          if (doctor   != null && doctor.isNotEmpty)   doctorCtrl.text   = doctor;
          if (time     != null && time.isNotEmpty)     timeCtrl.text     = time;
          if (location != null && location.isNotEmpty) locationCtrl.text = location;
          if (notesVal != null && notesVal.isNotEmpty) notesCtrl.text    = notesVal;
          if (dateStr  != null) { final d = DateTime.tryParse(dateStr); if (d != null) dateRef[0] = d; }
          aiActive = false;
          aiCtrl.clear();
        });
      }

      Future<void> runAI() async {
        final text = aiCtrl.text.trim();
        if (text.isEmpty) return;
        ss(() => aiParsing = true);
        try {
          final result = await AIParser.parseText(
            feature: 'lifestyle', subFeature: 'appointment', text: text,
            context: {'today': DateTime.now().toIso8601String().split('T')[0]});
          if (!ctx2.mounted) return;
          if (result.success && result.data != null) {
            applyData(result.data!);
          } else {
            maybeShowAiLimitSnackbar(ctx2, result.error);
            ss(() { aiActive = false; });
          }
        } catch (_) {
          if (ctx2.mounted) ss(() { aiActive = false; });
        } finally {
          if (ctx2.mounted) ss(() => aiParsing = false);
        }
      }

      return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Text(existing == null ? 'Book Appointment' : 'Edit Appointment',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito'))),
          _aiButton(aiActive, () => ss(() => aiActive = !aiActive)),
        ]),
        const SizedBox(height: 10),
        if (aiActive) ...[
          _aiBox(aiCtrl, aiParsing, runAI, sub, surfBg, isDark,
            hint: 'e.g. "Dr. Ramesh, Apollo Hospital, 15 July 10:30 AM, ground floor OPD"'),
          const SizedBox(height: 10),
        ],
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
          final messenger = ScaffoldMessenger.of(ctx2);
          Navigator.pop(ctx2);
          if (existing == null) {
            () async {
              try {
                final data = Appointment(id: '', walletId: walletId, memberId: memberId, doctorName: doctor, apptDate: date, apptTime: time, location: location, notes: notes);
                final row = await HealthService.instance.addAppointment(data.toJson());
                onAdd(Appointment.fromJson(row));
              } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_add_appt'); messenger.showSnackBar(const SnackBar(content: Text('Failed to save appointment'))); }
            }();
          } else {
            final updates = {'doctor_name': doctor, 'appt_date': date.toIso8601String().substring(0, 10), 'appt_time': time, 'location': location, 'notes': notes};
            () async {
              try {
                await HealthService.instance.updateAppointment(existing.id, updates);
                onUpdate(Appointment(id: existing.id, walletId: existing.walletId, memberId: existing.memberId, doctorName: doctor, apptDate: date, apptTime: time, location: location, notes: notes));
              } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_update_appt'); messenger.showSnackBar(const SnackBar(content: Text('Failed to save appointment'))); }
            }();
          }
        }),
      ]),
    );
    }));
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
                      onDismissed: (_) async { try { await HealthService.instance.deleteVital(v.id); widget.onDelete(v.id); } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_delete_vital'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete vital'))); } },
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
    final aiCtrl   = TextEditingController();
    bool aiActive  = false;
    bool aiParsing = false;

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) {
      final isDark = Theme.of(ctx2).brightness == Brightness.dark;
      final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
      final sub    = isDark ? AppColors.subDark  : AppColors.subLight;

      void applyData(Map<String, dynamic> data) {
        final typeName = data['vital_type'] as String?;
        final val      = data['value']      as num?;
        final val2     = data['value2']     as num?;
        final subType  = data['sub_type']   as String?;
        final notesVal = data['notes']      as String?;
        ss(() {
          if (typeName != null) {
            try { typeRef[0] = VitalType.values.firstWhere((t) => t.name == typeName); } catch (_) {}
          }
          if (val    != null) v1Ctrl.text = val.toString();
          if (val2   != null) v2Ctrl.text = val2.toString();
          if (subType  != null && subType.isNotEmpty)  subCtrl.text   = subType;
          if (notesVal != null && notesVal.isNotEmpty) notesCtrl.text = notesVal;
          aiActive = false;
          aiCtrl.clear();
        });
      }

      Future<void> runAI() async {
        final text = aiCtrl.text.trim();
        if (text.isEmpty) return;
        ss(() => aiParsing = true);
        try {
          final result = await AIParser.parseText(
            feature: 'lifestyle', subFeature: 'vital', text: text);
          if (!ctx2.mounted) return;
          if (result.success && result.data != null) {
            applyData(result.data!);
          } else {
            maybeShowAiLimitSnackbar(ctx2, result.error);
            ss(() { aiActive = false; });
          }
        } catch (_) {
          if (ctx2.mounted) ss(() { aiActive = false; });
        } finally {
          if (ctx2.mounted) ss(() => aiParsing = false);
        }
      }

      return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Text(existing == null ? 'Log Vital' : 'Edit Vital',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito'))),
          _aiButton(aiActive, () => ss(() => aiActive = !aiActive)),
        ]),
        const SizedBox(height: 10),
        if (aiActive) ...[
          _aiBox(aiCtrl, aiParsing, runAI, sub, surfBg, isDark,
            hint: 'e.g. "BP 120/80" or "Blood sugar fasting 95 mg/dL" or "Weight 68kg, Heart rate 78 bpm"'),
          const SizedBox(height: 10),
        ],
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
          final messenger = ScaffoldMessenger.of(ctx2);
          Navigator.pop(ctx2);
          if (existing == null) {
            () async {
              try {
                final data = HealthVital(id: '', walletId: widget.walletId, memberId: widget.memberId, type: type, value: v1, value2: v2, subType: sub, notes: notes);
                final row = await HealthService.instance.addVital(data.toJson());
                widget.onAdd(HealthVital.fromJson(row));
              } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_add_vital'); messenger.showSnackBar(const SnackBar(content: Text('Failed to save vital'))); }
            }();
          } else {
            final updates = {'value': v1, if (v2 != null) 'value2': v2, 'sub_type': sub, 'notes': notes};
            () async {
              try {
                await HealthService.instance.updateVital(existing.id, updates);
                widget.onUpdate(HealthVital(id: existing.id, walletId: existing.walletId, memberId: existing.memberId, type: existing.type, value: v1, value2: v2, subType: sub, notes: notes, recordedAt: existing.recordedAt));
              } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_update_vital'); messenger.showSnackBar(const SnackBar(content: Text('Failed to save vital'))); }
            }();
          }
        }),
      ]),
    );
    }));
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
              if (overdue.isNotEmpty) ...[const LifeLabel(text: '⚠️ OVERDUE'), ...overdue.map((v) => _VaccineCard(v: v, cardBg: cardBg, isDark: isDark, statusColor: Colors.red, onDelete: () async { try { await HealthService.instance.deleteVaccination(v.id); onDelete(v.id); } catch (err, stack) { ErrorLogger.log(err, stackTrace: stack, action: 'health_delete_vaccination'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete vaccination'))); } }, onEdit: () => _showSheet(context, existing: v)))],
              if (dueSoon.isNotEmpty) ...[if (overdue.isNotEmpty) const SizedBox(height: 8), const LifeLabel(text: '🔔 DUE SOON'), ...dueSoon.map((v) => _VaccineCard(v: v, cardBg: cardBg, isDark: isDark, statusColor: Colors.orange, onDelete: () async { try { await HealthService.instance.deleteVaccination(v.id); onDelete(v.id); } catch (err, stack) { ErrorLogger.log(err, stackTrace: stack, action: 'health_delete_vaccination'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete vaccination'))); } }, onEdit: () => _showSheet(context, existing: v)))],
              if (rest.isNotEmpty) ...[if (overdue.isNotEmpty || dueSoon.isNotEmpty) const SizedBox(height: 8), const LifeLabel(text: 'COMPLETED'), ...rest.map((v) => _VaccineCard(v: v, cardBg: cardBg, isDark: isDark, statusColor: _healthColor, onDelete: () async { try { await HealthService.instance.deleteVaccination(v.id); onDelete(v.id); } catch (err, stack) { ErrorLogger.log(err, stackTrace: stack, action: 'health_delete_vaccination'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete vaccination'))); } }, onEdit: () => _showSheet(context, existing: v)))],
            ]),
    );
  }

  void _showSheet(BuildContext ctx, {Vaccination? existing}) {
    final nameCtrl  = TextEditingController(text: existing?.vaccineName ?? '');
    final doseCtrl  = TextEditingController(text: existing?.doseNumber?.toString() ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final givenRef  = <DateTime>[existing?.dateGiven ?? DateTime.now()];
    final dueRef    = <DateTime?>[existing?.nextDue];
    final aiCtrl   = TextEditingController();
    bool aiActive  = false;
    bool aiParsing = false;

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) {
      final isDark = Theme.of(ctx2).brightness == Brightness.dark;
      final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
      final sub    = isDark ? AppColors.subDark  : AppColors.subLight;

      void applyData(Map<String, dynamic> data) {
        final name     = data['vaccine_name'] as String?;
        final dose     = data['dose_number']  as num?;
        final notesVal = data['notes']        as String?;
        final givenStr = data['date_given']   as String?;
        final dueStr   = data['next_due']     as String?;
        ss(() {
          if (name     != null && name.isNotEmpty)     nameCtrl.text  = name;
          if (dose     != null) doseCtrl.text = dose.toInt().toString();
          if (notesVal != null && notesVal.isNotEmpty) notesCtrl.text = notesVal;
          if (givenStr != null) { final d = DateTime.tryParse(givenStr); if (d != null) givenRef[0] = d; }
          if (dueStr   != null) { final d = DateTime.tryParse(dueStr);   if (d != null) dueRef[0]   = d; }
          aiActive = false;
          aiCtrl.clear();
        });
      }

      Future<void> runAI() async {
        final text = aiCtrl.text.trim();
        if (text.isEmpty) return;
        ss(() => aiParsing = true);
        try {
          final result = await AIParser.parseText(
            feature: 'lifestyle', subFeature: 'vaccination', text: text,
            context: {'today': DateTime.now().toIso8601String().split('T')[0]});
          if (!ctx2.mounted) return;
          if (result.success && result.data != null) {
            applyData(result.data!);
          } else {
            maybeShowAiLimitSnackbar(ctx2, result.error);
            ss(() { aiActive = false; });
          }
        } catch (_) {
          if (ctx2.mounted) ss(() { aiActive = false; });
        } finally {
          if (ctx2.mounted) ss(() => aiParsing = false);
        }
      }

      return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Text(existing == null ? 'Add Vaccination' : 'Edit Vaccination',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito'))),
          _aiButton(aiActive, () => ss(() => aiActive = !aiActive)),
        ]),
        const SizedBox(height: 10),
        if (aiActive) ...[
          _aiBox(aiCtrl, aiParsing, runAI, sub, surfBg, isDark,
            hint: 'e.g. "Covishield dose 2, given 15 Mar 2022, next due Mar 2023"'),
          const SizedBox(height: 10),
        ],
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
          final messenger = ScaffoldMessenger.of(ctx2);
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
            } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_save_vaccine'); messenger.showSnackBar(const SnackBar(content: Text('Failed to save vaccination'))); }
          }();
        }),
      ]),
    );
    }));
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
                  onDismissed: (_) async { try { await HealthService.instance.deleteInsurance(p.id); onDelete(p.id); } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_delete_insurance'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete insurance policy'))); } },
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
                                Text('${AppPrefs.cs}${p.coverageAmount!.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'DM Mono', color: _healthColor)),
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
    final nameCtrl  = TextEditingController(text: existing?.policyName ?? '');
    final numCtrl   = TextEditingController(text: existing?.policyNumber ?? '');
    final provCtrl  = TextEditingController(text: existing?.provider ?? '');
    final covCtrl   = TextEditingController(text: existing?.coverageAmount?.toStringAsFixed(0) ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final expiryRef = <DateTime?>[existing?.expiryDate];
    final aiCtrl   = TextEditingController();
    bool aiActive  = false;
    bool aiParsing = false;

    showLifeSheet(ctx, child: StatefulBuilder(builder: (ctx2, ss) {
      final isDark = Theme.of(ctx2).brightness == Brightness.dark;
      final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
      final sub    = isDark ? AppColors.subDark  : AppColors.subLight;

      void applyData(Map<String, dynamic> data) {
        final name       = data['policy_name']    as String?;
        final num_       = data['policy_number']  as String?;
        final prov       = data['provider']       as String?;
        final cov        = data['coverage_amount'] as num?;
        final notesVal   = data['notes']          as String?;
        final expiryStr  = data['expiry_date']    as String?;
        ss(() {
          if (name     != null && name.isNotEmpty)     nameCtrl.text = name;
          if (num_     != null && num_.isNotEmpty)     numCtrl.text  = num_;
          if (prov     != null && prov.isNotEmpty)     provCtrl.text = prov;
          if (cov      != null) covCtrl.text = cov.toInt().toString();
          if (notesVal != null && notesVal.isNotEmpty) notesCtrl.text = notesVal;
          if (expiryStr != null) { final d = DateTime.tryParse(expiryStr); if (d != null) expiryRef[0] = d; }
          aiActive = false;
          aiCtrl.clear();
        });
      }

      Future<void> runAI() async {
        final text = aiCtrl.text.trim();
        if (text.isEmpty) return;
        ss(() => aiParsing = true);
        try {
          final result = await AIParser.parseText(
            feature: 'lifestyle', subFeature: 'insurance_policy', text: text,
            context: {'today': DateTime.now().toIso8601String().split('T')[0]});
          if (!ctx2.mounted) return;
          if (result.success && result.data != null) {
            applyData(result.data!);
          } else {
            maybeShowAiLimitSnackbar(ctx2, result.error);
            ss(() { aiActive = false; });
          }
        } catch (_) {
          if (ctx2.mounted) ss(() { aiActive = false; });
        } finally {
          if (ctx2.mounted) ss(() => aiParsing = false);
        }
      }

      return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Text(existing == null ? 'Add Insurance Policy' : 'Edit Insurance Policy',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito'))),
          _aiButton(aiActive, () => ss(() => aiActive = !aiActive)),
        ]),
        const SizedBox(height: 10),
        if (aiActive) ...[
          _aiBox(aiCtrl, aiParsing, runAI, sub, surfBg, isDark,
            hint: 'e.g. "Star Health individual, policy SH12345, Star Health Insurance, coverage 5 lakhs, expires Jan 2026"'),
          const SizedBox(height: 10),
        ],
        LifeInput(controller: nameCtrl, hint: 'Policy name *'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: LifeInput(controller: numCtrl, hint: 'Policy number')),
          const SizedBox(width: 8),
          Expanded(child: LifeInput(controller: provCtrl, hint: 'Provider')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: LifeInput(controller: covCtrl, hint: 'Coverage amount (${AppPrefs.cs})', inputType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
          const SizedBox(width: 8),
          Expanded(child: LifeDateTile(date: expiryRef[0], hint: 'Expiry Date', color: Colors.orange, onTap: () async { final d = await _pickDate(ctx2); if (d != null) ss(() => expiryRef[0] = d); })),
        ]),
        const SizedBox(height: 8),
        LifeInput(controller: notesCtrl, hint: 'Notes', maxLines: 2),
        LifeSaveButton(label: existing == null ? 'Save' : 'Update', color: _healthColor, onTap: () {
          if (nameCtrl.text.trim().isEmpty) return;
          final policyName   = nameCtrl.text.trim();
          final policyNumber = numCtrl.text.trim().isEmpty  ? null : numCtrl.text.trim();
          final provider     = provCtrl.text.trim().isEmpty ? null : provCtrl.text.trim();
          final coverageAmount = double.tryParse(covCtrl.text.trim());
          final notes  = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
          final expiry = expiryRef[0];
          final messenger = ScaffoldMessenger.of(ctx2);
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
            } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'health_save_insurance'); messenger.showSnackBar(const SnackBar(content: Text('Failed to save insurance policy'))); }
          }();
        }),
      ]),
      );
    }));
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

