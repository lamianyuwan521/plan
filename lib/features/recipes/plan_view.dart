import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../data/seed_plans.dart';
import '../../models/models.dart';
import 'add_food_sheet.dart';
import 'plan_detail_page.dart';

class PlanView extends StatefulWidget {
  const PlanView({super.key});

  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  DateTime? _weekStartOverride;

  DateTime _currentWeekStart(AppRepository repository) {
    return _weekStartOverride ??
        AppDate.startOfWeek(
          AppDate.today(),
          repository.profile.weekStart,
        );
  }

  void _shiftWeek(int delta) {
    final repository = context.read<AppRepository>();
    final current = _currentWeekStart(repository);
    setState(() {
      _weekStartOverride = current.add(Duration(days: 7 * delta));
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final theme = Theme.of(context);
    final today = AppDate.today();
    final weekStart = _currentWeekStart(repository);
    final days = AppDate.weekDays(weekStart, repository.profile.weekStart);
    final entriesByDate = <String, List<MealEntry>>{
      for (final day in days) AppDate.key(day): repository.entriesFor(AppDate.key(day)),
    };
    final allEntries = entriesByDate.values.expand((list) => list).toList();
    final totalKcal =
        allEntries.fold<int>(0, (sum, entry) => sum + entry.calories);
    final completed =
        allEntries.where((entry) => entry.isCompleted).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const _SectionHeading(title: '长期食谱', subtitle: '选一套方案，定好日期就能按天自动排进日历'),
        const SizedBox(height: 10),
        const _LongTermPlansSection(),
        const SizedBox(height: 22),
        const _SectionHeading(title: '本周安排', subtitle: '按周查看每天的三餐，到当天打勾'),
        const SizedBox(height: 10),
        SectionCard(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '上一周',
                    onPressed: () => _shiftWeek(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${weekStart.month}/${weekStart.day} – '
                        '${days.last.month}/${days.last.day}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '下一周',
                    onPressed: () => _shiftWeek(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _weekStartOverride = null),
                    child: const Text('本周'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _WeekStat(
                      label: '计划热量',
                      value: '$totalKcal',
                      unit: 'kcal',
                    ),
                  ),
                  Expanded(
                    child: _WeekStat(
                      label: '完成情况',
                      value: '$completed/${allEntries.length}',
                    ),
                  ),
                  Expanded(
                    child: _WeekStat(
                      label: '日均计划',
                      value: '${(totalKcal / 7).round()}',
                      unit: 'kcal',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (allEntries.isEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '这一周还没有安排。点每一天每餐右侧的「+」，从食谱库挑一份。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 2 : 1;
            const spacing = 12.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final day in days)
                  SizedBox(
                    width: width,
                    child: _PlanDayCard(
                      date: day,
                      today: today,
                      entries: entriesByDate[AppDate.key(day)] ?? const [],
                      isFuture: day.isAfter(today),
                      onToggle: (entry, value) =>
                          repository.setEntryCompleted(entry.id, value),
                      onAdd: (mealType) => showAddFoodSheet(
                        context,
                        date: AppDate.key(day),
                        initialMeal: mealType,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _LongTermPlansSection extends StatelessWidget {
  const _LongTermPlansSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          const spacing = 12.0;
          final width = (constraints.maxWidth - spacing) / 2;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final plan in seedPlans)
                SizedBox(
                  width: width,
                  height: 168,
                  child: _LongTermPlanCard(plan: plan),
                ),
            ],
          );
        }
        return SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: seedPlans.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => SizedBox(
              width: 268,
              child: _LongTermPlanCard(plan: seedPlans[index]),
            ),
          ),
        );
      },
    );
  }
}

class _LongTermPlanCard extends StatelessWidget {
  const _LongTermPlanCard({required this.plan});

  final DietPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlanDetailPage(planId: plan.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.65,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 19,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              plan.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TagChip(label: '${plan.days.length} 天'),
              const SizedBox(width: 6),
              TagChip(label: '日均 ${plan.averageCalories} kcal'),
              const Spacer(),
              for (final tag in plan.tags.take(1))
                Text(
                  tag,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekStat extends StatelessWidget {
  const _WeekStat({
    required this.label,
    required this.value,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanDayCard extends StatelessWidget {
  const _PlanDayCard({
    required this.date,
    required this.today,
    required this.entries,
    required this.isFuture,
    required this.onToggle,
    required this.onAdd,
  });

  final DateTime date;
  final DateTime today;
  final List<MealEntry> entries;
  final bool isFuture;
  final void Function(MealEntry entry, bool value) onToggle;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = AppDate.sameDay(date, today);
    final completed = entries.where((entry) => entry.isCompleted).length;
    final totalKcal =
        entries.fold<int>(0, (sum, entry) => sum + entry.calories);

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      color: isToday
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '周${AppDate.shortWeekday(date)} · '
                '${date.month}/${date.day}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 6),
                const TagChip(label: '今天'),
              ],
              const Spacer(),
              Text(
                entries.isEmpty
                    ? '未安排'
                    : '$completed/${entries.length} · $totalKcal kcal',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: entries.isNotEmpty && completed == entries.length
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final mealType in allMealTypes)
            _PlanMealRow(
              mealType: mealType,
              entries: entries
                  .where((entry) => entry.mealType == mealType)
                  .toList(),
              isFuture: isFuture,
              onToggle: onToggle,
              onAdd: () => onAdd(mealType),
            ),
        ],
      ),
    );
  }
}

class _PlanMealRow extends StatelessWidget {
  const _PlanMealRow({
    required this.mealType,
    required this.entries,
    required this.isFuture,
    required this.onToggle,
    required this.onAdd,
  });

  final String mealType;
  final List<MealEntry> entries;
  final bool isFuture;
  final void Function(MealEntry entry, bool value) onToggle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                mealShortLabel(mealType),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '未安排',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final entry in entries)
                        Row(
                          children: [
                            Checkbox(
                              value: entry.isCompleted,
                              onChanged: isFuture
                                  ? null
                                  : (value) =>
                                      onToggle(entry, value ?? false),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Expanded(
                              child: Text(
                                entry.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  decoration: entry.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: entry.isCompleted
                                      ? theme.colorScheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${entry.calories}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
          IconButton(
            onPressed: onAdd,
            tooltip: '添加${mealLabel(mealType)}',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}
