import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/models.dart';
import 'day_detail_view.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final today = AppDate.today();
    _selected = today;
    _month = DateTime(today.year, today.month, 1);
  }

  void _goMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta, 1);
    final today = AppDate.today();
    setState(() {
      _month = next;
      _selected = (today.year == next.year && today.month == next.month)
          ? today
          : next;
    });
  }

  void _goToday() {
    final today = AppDate.today();
    setState(() {
      _selected = today;
      _month = DateTime(today.year, today.month, 1);
    });
  }

  void _select(DateTime date) {
    setState(() {
      _selected = date;
      if (date.year != _month.year || date.month != _month.month) {
        _month = DateTime(date.year, date.month, 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final theme = Theme.of(context);
    final unit = repository.profile.weightUnit;
    final weekStart = repository.profile.weekStart;
    final summaries = repository.summariesForMonth(_month);
    final days = AppDate.monthGridDays(_month, weekStart);
    final headers = AppDate.weekdayHeaders(weekStart);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SectionCard(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: '上个月',
                        onPressed: () => _goMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            AppDate.monthTitle(_month),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '下个月',
                        onPressed: () => _goMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                      TextButton(
                        onPressed: _goToday,
                        child: const Text('今天'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      for (final label in headers)
                        Expanded(
                          child: Center(
                            child: Text(
                              label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (var week = 0; week < 6; week++)
                    SizedBox(
                      height: 64,
                      child: Row(
                        children: [
                          for (var day = 0; day < 7; day++)
                            Expanded(
                              child: _DayCell(
                                date: days[week * 7 + day],
                                summary:
                                    summaries[AppDate.key(days[week * 7 + day])],
                                selected: AppDate.sameDay(
                                  days[week * 7 + day],
                                  _selected,
                                ),
                                inMonth:
                                    days[week * 7 + day].month == _month.month,
                                unit: unit,
                                onTap: () =>
                                    _select(days[week * 7 + day]),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  const _CalendarLegend(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DayDetailView(dateKey: AppDate.key(_selected)),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.summary,
    required this.selected,
    required this.inMonth,
    required this.unit,
    required this.onTap,
  });

  final DateTime date;
  final DaySummary? summary;
  final bool selected;
  final bool inMonth;
  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = AppDate.isToday(date);
    final weight = summary?.weightKg;
    final dayColor = inMonth
        ? (isToday ? scheme.primary : scheme.onSurface)
        : scheme.onSurfaceVariant.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : (isToday
                ? scheme.primaryContainer.withValues(alpha: 0.35)
                : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(color: scheme.primary, width: 1.4)
                  : null,
            ),
            padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '${date.day}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight:
                            isToday ? FontWeight.w900 : FontWeight.w600,
                        color: dayColor,
                      ),
                    ),
                    const Spacer(),
                    if (summary?.waterGoalMet == true)
                      const Icon(
                        Icons.water_drop,
                        size: 9,
                        color: AppColors.water,
                      ),
                  ],
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    weight == null ? '—' : weightValueText(weight, unit),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: weight == null
                          ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
                          : (inMonth
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < mainMealTypes.length; index++) ...[
                      if (index > 0) const SizedBox(width: 3),
                      _MealDot(progress: summary?.meals[mainMealTypes[index]]),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MealDot extends StatelessWidget {
  const _MealDot({this.progress});

  final MealProgress? progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color;
    if (progress == null || !progress!.hasEntries) {
      color = scheme.outlineVariant.withValues(alpha: 0.5);
    } else if (progress!.allDone) {
      color = scheme.primary;
    } else {
      color = scheme.primary.withValues(alpha: 0.42);
    }
    return Container(
      width: 4.5,
      height: 4.5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _LegendItem(
          color: scheme.primary,
          label: '已完成',
        ),
        _LegendItem(
          color: scheme.primary.withValues(alpha: 0.42),
          label: '未完成',
        ),
        _LegendItem(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          label: '未安排',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water_drop, size: 10, color: AppColors.water),
            const SizedBox(width: 4),
            Text(
              '喝水达标',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
