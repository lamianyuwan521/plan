import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/app_date.dart';
import '../../core/app_theme.dart';
import '../../core/calculators.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';

class WeightChart extends StatelessWidget {
  const WeightChart({
    super.key,
    required this.records,
    required this.unit,
    required this.rangeDays,
    required this.showMovingAverage,
    this.targetKg,
  });

  final List<WeightRecord> records;
  final String unit;
  /// 7 / 30 / 90；0 表示全部。
  final int rangeDays;
  final bool showMovingAverage;
  final double? targetKg;

  @override
  Widget build(BuildContext context) {
    final data = _prepare();
    if (data.spots.isEmpty) {
      return EmptyState(
        icon: Icons.show_chart,
        title: '这段时间还没有体重记录',
        message: rangeDays == 0
            ? '记录 2 天以上就能看到趋势。'
            : '换一个时间范围，或记录今天的体重。',
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final values = <double>[
      ...data.spots.map((s) => s.y),
      ...data.maSpots.map((s) => s.y),
      if (data.target != null) data.target!,
    ];
    var minY = values.reduce(math.min);
    var maxY = values.reduce(math.max);
    final padding = unit == 'jin' ? 2.0 : 1.0;
    minY -= padding;
    maxY += padding;
    if (maxY - minY < 4) {
      final middle = (maxY + minY) / 2;
      minY = middle - 2;
      maxY = middle + 2;
    }
    if (minY < 0) {
      maxY += -minY;
      minY = 0;
    }

    final xCount = data.xDates.length;
    final maxX = math.max(1, xCount - 1).toDouble();
    final bottomInterval = math.max(1, (xCount / 4).ceil()).toDouble();
    final yInterval =
        math.max(0.5, ((maxY - minY) / 4 * 2).round() / 2).toDouble();

    return SizedBox(
      height: 236,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: bottomInterval,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= data.xDates.length) {
                    return const SizedBox.shrink();
                  }
                  if ((value - index).abs() > 0.01) {
                    return const SizedBox.shrink();
                  }
                  final date = data.xDates[index];
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(
                      '${date.month}/${date.day}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: yInterval,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(
                      value.toStringAsFixed(1),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (data.target != null)
                HorizontalLine(
                  y: data.target!,
                  color: scheme.outline.withValues(alpha: 0.75),
                  strokeWidth: 1,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    labelResolver: (_) => '目标',
                  ),
                ),
            ],
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => scheme.inverseSurface,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index =
                      spot.x.round().clamp(0, data.xDates.length - 1);
                  final date = data.xDates[index];
                  final label = spot.barIndex == 0 ? '体重' : '7 日均线';
                  return LineTooltipItem(
                    '${date.month} 月 ${date.day} 日 · $label\n'
                    '${spot.y.toStringAsFixed(1)} ${weightUnitLabel(unit)}',
                    TextStyle(
                      color: scheme.onInverseSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: data.spots,
              isCurved: false,
              color: AppColors.mint,
              barWidth: 2.6,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: data.spots.length <= 45,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 2.6,
                  color: AppColors.mint,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.mint.withValues(alpha: 0.16),
                    AppColors.mint.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            if (data.maSpots.isNotEmpty)
              LineChartBarData(
                spots: data.maSpots,
                isCurved: false,
                color: AppColors.peach,
                barWidth: 2,
                dashArray: [6, 4],
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
          ],
        ),
        duration: const Duration(milliseconds: 220),
      ),
    );
  }

  _ChartData _prepare() {
    final today = AppDate.today();
    final latestByDate = <String, WeightRecord>{};
    for (final record in records) {
      final existing = latestByDate[record.date];
      if (existing == null ||
          record.recordedAt.isAfter(existing.recordedAt)) {
        latestByDate[record.date] = record;
      }
    }
    final daily = <String, double>{
      for (final entry in latestByDate.entries) entry.key: entry.value.weightKg,
    };
    if (daily.isEmpty) {
      return const _ChartData(
        spots: [],
        maSpots: [],
        xDates: [],
        target: null,
      );
    }

    final earliest = daily.keys
        .map(AppDate.parse)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final start = rangeDays > 0
        ? today.subtract(Duration(days: rangeDays - 1))
        : (earliest.isBefore(today) ? earliest : today);
    final span = AppDate.daysBetween(start, today) + 1;
    final weekly = rangeDays == 0 && span > 180;

    final xDates = <DateTime>[];
    final spots = <FlSpot>[];
    final maSpots = <FlSpot>[];

    if (!weekly) {
      for (var i = 0; i < span; i++) {
        final day = DateTime(start.year, start.month, start.day + i);
        xDates.add(day);
        final value = daily[AppDate.key(day)];
        if (value != null) {
          spots.add(FlSpot(i.toDouble(), kgToDisplay(value, unit)));
        }
      }
      if (showMovingAverage) {
        for (var i = 0; i < span; i++) {
          final average = movingAverageAt(daily, xDates[i]);
          if (average != null) {
            maSpots.add(FlSpot(i.toDouble(), kgToDisplay(average, unit)));
          }
        }
      }
    } else {
      final firstWeek = AppDate.startOfWeek(start, 1);
      final totalDays = AppDate.daysBetween(firstWeek, today) + 1;
      final weekCount = (totalDays / 7).ceil();
      for (var week = 0; week < weekCount; week++) {
        final weekStart = DateTime(
          firstWeek.year,
          firstWeek.month,
          firstWeek.day + week * 7,
        );
        xDates.add(weekStart);
        final values = <double>[];
        for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
          final day = DateTime(
            weekStart.year,
            weekStart.month,
            weekStart.day + dayOffset,
          );
          if (day.isAfter(today)) break;
          final value = daily[AppDate.key(day)];
          if (value != null) values.add(value);
        }
        if (values.isNotEmpty) {
          final average =
              values.reduce((a, b) => a + b) / values.length;
          spots.add(FlSpot(week.toDouble(), kgToDisplay(average, unit)));
        }
      }
    }

    return _ChartData(
      spots: spots,
      maSpots: maSpots,
      xDates: xDates,
      target: targetKg == null ? null : kgToDisplay(targetKg!, unit),
    );
  }
}

class _ChartData {
  const _ChartData({
    required this.spots,
    required this.maSpots,
    required this.xDates,
    required this.target,
  });

  final List<FlSpot> spots;
  final List<FlSpot> maSpots;
  final List<DateTime> xDates;
  final double? target;
}
