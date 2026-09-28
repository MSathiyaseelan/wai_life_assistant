import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

final _dateTime = DateFormat('d MMM yyyy, HH:mm');
final _date = DateFormat('d MMM yyyy');
final _num = NumberFormat.decimalPattern('en_IN');

String fmtDateTime(dynamic v) {
  final d = v is String ? DateTime.tryParse(v) : v as DateTime?;
  return d == null ? '—' : _dateTime.format(d.toLocal());
}

String fmtDate(dynamic v) {
  final d = v is String ? DateTime.tryParse(v) : v as DateTime?;
  return d == null ? '—' : _date.format(d.toLocal());
}

String fmtNum(dynamic v) => v == null ? '—' : _num.format(v is num ? v : num.tryParse('$v') ?? 0);

/// "3h ago", "2d ago" — for last-seen columns.
String fmtAgo(dynamic v) {
  final d = v is String ? DateTime.tryParse(v) : v as DateTime?;
  if (d == null) return '—';
  final diff = DateTime.now().difference(d.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return fmtDate(d);
}

/// Page scaffold: title row with optional actions, then scrollable content.
class PageFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  const PageFrame({super.key, required this.title, this.subtitle, this.actions = const [], required this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
              ],
            ),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
          ],
        ),
        const SizedBox(height: 20),
        child,
      ],
    );
  }
}

/// FutureBuilder with consistent loading / error / retry states.
class Loader<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  const Loader({super.key, required this.future, required this.builder, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: StatusTone.critical.color(context)),
                  const SizedBox(width: 12),
                  Expanded(child: SelectableText('${snap.error}')),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        return builder(snap.data as T);
      },
    );
  }
}

/// Headline number tile.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final StatusTone? tone;
  const StatTile({super.key, required this.label, required this.value, this.caption, this.tone});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.labelMedium?.copyWith(color: muted)),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (tone != null) ...[
                    Icon(Icons.circle, size: 10, color: tone!.color(context)),
                    const SizedBox(width: 6),
                  ],
                  Text(value, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(caption!, style: t.bodySmall?.copyWith(color: muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

/// Coloured dot + text label — status is never colour alone.
class StatusChip extends StatelessWidget {
  final String label;
  final StatusTone tone;
  const StatusChip(this.label, this.tone, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = tone.color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: c),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Dropdown filter used in page action rows. `null` value = "All".
class FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;
  final bool allowAll;
  final bool enabled;
  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.allowAll = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String?>(
      label: Text(label),
      initialSelection: value,
      enabled: enabled,
      width: 170,
      inputDecorationTheme: const InputDecorationTheme(isDense: true, border: OutlineInputBorder()),
      onSelected: onChanged,
      dropdownMenuEntries: [
        if (allowAll) const DropdownMenuEntry(value: null, label: 'All'),
        ...options.entries.map((e) => DropdownMenuEntry(value: e.key, label: e.value)),
      ],
    );
  }
}

/// Wide tables scroll horizontally inside a card instead of overflowing.
class TableCard extends StatelessWidget {
  final DataTable table;
  const TableCard({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(constraints: BoxConstraints(minWidth: c.maxWidth), child: table),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ),
      );
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? StatusTone.critical.color(context) : null,
  ));
}
