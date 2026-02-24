import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

// ── Bottom sheet launcher ─────────────────────────────────────────────────────
void showLifeSheet(BuildContext context, {required Widget child}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2))),
          Flexible(child: SingleChildScrollView(child: child)),
        ]))));
}

// ── Section header ────────────────────────────────────────────────────────────
class LifeSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const LifeSectionHeader({super.key, required this.title, this.trailing});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
          fontFamily: 'Nunito', color: isDark ? AppColors.textDark : AppColors.textLight)),
        const Spacer(),
        if (trailing != null) trailing!,
      ]));
  }
}

// ── Input field ───────────────────────────────────────────────────────────────
class LifeInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? inputType;
  const LifeInput({super.key, required this.controller, required this.hint,
    this.maxLines = 1, this.inputType});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc     = isDark ? AppColors.textDark : AppColors.textLight;
    final sub    = isDark ? AppColors.subDark  : AppColors.subLight;
    return Container(
      decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: TextField(
        controller: controller, maxLines: maxLines, minLines: 1,
        keyboardType: inputType,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(fontSize: 13, color: tc, fontFamily: 'Nunito'),
        decoration: InputDecoration.collapsed(hintText: hint,
          hintStyle: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito'))));
  }
}

// ── Label ─────────────────────────────────────────────────────────────────────
class LifeLabel extends StatelessWidget {
  final String text;
  const LifeLabel({super.key, required this.text});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 12),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
        fontFamily: 'Nunito', color: isDark ? AppColors.subDark : AppColors.subLight,
        letterSpacing: 0.8)));
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────
class LifeInfoRow extends StatelessWidget {
  final IconData icon; final String label; final Color? color;
  const LifeInfoRow({super.key, required this.icon, required this.label, this.color});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 13, color: color ?? sub),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: TextStyle(
          fontSize: 12, fontFamily: 'Nunito', color: color ?? sub))),
      ]));
  }
}

// ── Save button ───────────────────────────────────────────────────────────────
class LifeSaveButton extends StatelessWidget {
  final String label; final Color color; final VoidCallback onTap;
  const LifeSaveButton({super.key, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: SizedBox(width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
        child: Text(label, style: const TextStyle(fontSize: 15,
          fontWeight: FontWeight.w900, fontFamily: 'Nunito')))));
}

// ── Badge ─────────────────────────────────────────────────────────────────────
class LifeBadge extends StatelessWidget {
  final String text; final Color color;
  const LifeBadge({super.key, required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
      fontFamily: 'Nunito', color: color)));
}

// ── Empty state ───────────────────────────────────────────────────────────────
class LifeEmptyState extends StatelessWidget {
  final String emoji, title, subtitle;
  const LifeEmptyState({super.key, required this.emoji, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Nunito')),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(
          fontSize: 13, fontFamily: 'Nunito', color: AppColors.subDark)),
      ])));
}

// ── Date picker tile ──────────────────────────────────────────────────────────
class LifeDateTile extends StatelessWidget {
  final DateTime? date; final String hint; final Color color; final VoidCallback onTap;
  const LifeDateTile({super.key, this.date, required this.hint, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final _months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    String label = date != null ? '${date!.day} ${_months[date!.month]} ${date!.year}' : hint;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 15, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            fontFamily: 'Nunito', color: color))])));
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────
class ChatWidget extends StatefulWidget {
  final List<dynamic> messages;
  final bool isDark;
  final String Function(dynamic) textOf;
  final String Function(dynamic) senderOf;
  final void Function(String) onSend;
  const ChatWidget({super.key, required this.messages, required this.isDark,
    required this.textOf, required this.senderOf, required this.onSend});
  @override State<ChatWidget> createState() => _ChatWidgetState();
}
class _ChatWidgetState extends State<ChatWidget> {
  final _ctrl = TextEditingController();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final surfBg = widget.isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc     = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub    = widget.isDark ? AppColors.subDark  : AppColors.subLight;
    return Column(children: [
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(16),
        itemCount: widget.messages.length,
        itemBuilder: (_, i) {
          final m = widget.messages[i];
          final isMe = widget.senderOf(m) == 'me';
          return Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  CircleAvatar(radius: 16, backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(widget.senderOf(m).substring(0,1).toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                        color: AppColors.primary))),
                  const SizedBox(width: 8)],
                Flexible(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : surfBg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18))),
                  child: Text(widget.textOf(m), style: TextStyle(fontSize: 13,
                    fontFamily: 'Nunito', color: isMe ? Colors.white : tc)))),
              ]));
        })),
      Container(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: 16 + MediaQuery.of(context).viewInsets.bottom, top: 8),
        child: Row(children: [
          Expanded(child: Container(
            decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(22)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: TextField(controller: _ctrl,
              style: TextStyle(fontSize: 13, color: tc, fontFamily: 'Nunito'),
              decoration: InputDecoration.collapsed(hintText: 'Message…',
                hintStyle: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito'))))),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () { if (_ctrl.text.trim().isEmpty) return; widget.onSend(_ctrl.text.trim()); _ctrl.clear(); },
            child: Container(width: 44, height: 44,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
        ])),
    ]);
  }
}

// ── Quote card ────────────────────────────────────────────────────────────────
class QuoteCard extends StatelessWidget {
  final String vendor, service, phone;
  final double amount; final bool approved; final Color color;
  final VoidCallback onToggle;
  const QuoteCard({super.key, required this.vendor, required this.service,
    required this.phone, required this.amount, required this.approved,
    required this.color, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc     = isDark ? AppColors.textDark : AppColors.textLight;
    final sub    = isDark ? AppColors.subDark  : AppColors.subLight;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: approved ? AppColors.income.withOpacity(0.3) : color.withOpacity(0.1))),
      child: Row(children: [
        GestureDetector(onTap: onToggle,
          child: Icon(approved ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: approved ? AppColors.income : sub, size: 22)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(vendor, style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
          Text(service, style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
          if (phone.isNotEmpty) Row(children: [
            const Icon(Icons.phone_rounded, size: 11, color: AppColors.income),
            const SizedBox(width: 4),
            Text(phone, style: const TextStyle(fontSize: 11,
              fontFamily: 'Nunito', color: AppColors.income))]),
        ])),
        Text('₹${(amount/1000).toStringAsFixed(1)}K',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
            fontFamily: 'DM Mono', color: color)),
      ]));
  }
}
