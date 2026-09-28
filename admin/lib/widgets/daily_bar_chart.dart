import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

/// One measure per day as thin columns. Single series, so the card title
/// names it and there's no legend. Hover shows the day + value.
class DailyBarChart extends StatelessWidget {
  final String title;
  final List<(DateTime, num)> points;
  const DailyBarChart({super.key, required this.title, required this.points});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final muted = scheme.onSurfaceVariant;
    final series = AdminTheme.series(context);
    final total = points.fold<num>(0, (s, p) => s + p.$2);
    final maxV = points.fold<num>(0, (m, p) => math.max(m, p.$2));
    final niceMax = _niceCeil(maxV.toDouble());
    final labelEvery = math.max(1, (points.length / 6).ceil());

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                Text('${NumberFormat.decimalPattern('en_IN').format(total)} total', style: t.bodySmall?.copyWith(color: muted)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  maxY: niceMax,
                  minY: 0,
                  alignment: BarChartAlignment.spaceBetween,
                  borderData: FlBorderData(
                    show: true,
                    border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: niceMax / 2,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: scheme.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: niceMax / 2,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(_compact(v), style: t.labelSmall?.copyWith(color: muted)),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= points.length || i % labelEvery != 0) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(DateFormat('d MMM').format(points[i].$1), style: t.labelSmall?.copyWith(color: muted)),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => scheme.inverseSurface,
                      tooltipBorderRadius: BorderRadius.circular(6),
                      getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                        '${DateFormat('EEE, d MMM').format(points[group.x].$1)}\n',
                        TextStyle(color: scheme.onInverseSurface, fontSize: 11),
                        children: [
                          TextSpan(
                            text: NumberFormat.decimalPattern('en_IN').format(rod.toY),
                            style: TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].$2.toDouble(),
                            color: series,
                            width: points.length > 20 ? 6 : 14,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Axis max = 2 × a round step (1, 2 or 5 × 10^k), so the midline and top
  /// gridlines both land on whole numbers.
  static double _niceCeil(double v) {
    final half = math.max(v / 2, 1);
    final mag = math.pow(10, (math.log(half) / math.ln10).floor()).toDouble();
    final step = [1, 2, 5, 10].map((m) => m * mag).firstWhere((s) => s >= half);
    return step * 2;
  }

  static String _compact(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k' : v.toStringAsFixed(0);
}
