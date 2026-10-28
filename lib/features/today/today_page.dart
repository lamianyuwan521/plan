import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/models.dart';
import '../recipes/add_food_sheet.dart';
import '../weight/weight_entry_sheet.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.onOpenRecipes,
    required this.onOpenWater,
  });

  final VoidCallback onOpenRecipes;
  final VoidCallback onOpenWater;

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final theme = Theme.of(context);
    final profile = repository.profile;
    final unit = profile.weightUnit;
    final today = AppDate.today();
    final todayKey = AppDate.key(today);
    final summary = repository.summaryFor(todayKey);
    final budget = repository.dailyBudget;
    final consumed = summary.consumedKcal;
    final planned = summary.plannedKcal;
    final weight = summary.weightKg;
    final previousWeight = repository.previousWeightBefore(todayKey);
    final goal = repository.waterGoal;
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? '早上好'
        : hour < 18
            ? '下午好'
            : '晚上好';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting，${profile.nickname}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppDate.dateLabel(today),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StreakChip(streak: repository.streak),
          ],
        ),
        const SizedBox(height: 18),
        _WeightCard(
          weightKg: weight,
          previousKg: previousWeight,
          unit: unit,
          lastRecord: repository.latestWeight,
          onRecord: () => showWeightEntrySheet(context, date: today),
        ),
        const SizedBox(height: 14),
        SectionCard(
          onTap: onOpenRecipes,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '今日热量',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '去食谱 ›',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ProgressRing(
                    value: budget == 0 ? 0 : consumed / budget,
                    size: 118,
                    strokeWidth: 11,
                    color: consumed > budget
                        ? AppColors.warning
                        : theme.colorScheme.primary,
                    markerValue: budget == 0 ? null : planned / budget,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$consumed',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: consumed > budget
                                ? AppColors.warning
                                : theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          '/ $budget kcal',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      children: [
                        _CalorieRow(label: '已吃', value: '$consumed kcal'),
                        const SizedBox(height: 8),
                        _CalorieRow(label: '今日计划', value: '$planned kcal'),
                        const SizedBox(height: 8),
                        _CalorieRow(
                          label: consumed > budget ? '超出' : '剩余',
                          value:
                              '${(budget - consumed).abs()} kcal',
                          color: consumed > budget
                              ? AppColors.warning
                              : theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (planned > budget) ...[
                const SizedBox(height: 10),
                Text(
                  '今天的计划比预算多 ${planned - budget} kcal，可以换一道更轻的菜。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _MealsCard(
          repository: repository,
          dateKey: todayKey,
          summary: summary,
          onOpenRecipes: onOpenRecipes,
        ),
        const SizedBox(height: 14),
        SectionCard(
          onTap: onOpenWater,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop_outlined,
                      size: 18, color: AppColors.water),
                  const SizedBox(width: 6),
                  Text(
                    '喝水',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${summary.waterMl} / $goal ml',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.water,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: goal == 0
                      ? 0
                      : (summary.waterMl / goal).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor:
                      AppColors.water.withValues(alpha: 0.14),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.water),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amount in const [200, 300, 500])
                    FilledButton.tonal(
                      onPressed: () => repository.addWater(amount),
                      child: Text('+$amount ml'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          child: Row(
            children: [
              const MascotAvatar(size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _encouragement(
                    repository: repository,
                    summary: summary,
                    budget: budget,
                    weight: weight,
                    todayKey: todayKey,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _encouragement({
    required AppRepository repository,
    required DaySummary summary,
    required int budget,
    required double? weight,
    required String todayKey,
  }) {
    final profile = repository.profile;
    if (!summary.hasAny) {
      return '新的一天，先称个体重开个好头吧。';
    }
    if (summary.consumedKcal > budget) {
      return '比预算多了 ${summary.consumedKcal - budget} kcal，晚上散步 20 分钟就差不多啦。';
    }
    if (repository.streak >= 7) {
      return '已经连续记录 ${repository.streak} 天，小一二替你骄傲。';
    }
    if (weight != null) {
      final previous = repository.weightRecords
          .where((record) => record.date != todayKey)
          .map((record) => record.weightKg)
          .toList();
      if (previous.isNotEmpty &&
          weight <= previous.reduce(math.min) + 0.001) {
        return '新低！${weightText(weight, profile.weightUnit)}，离目标又近了一点。';
      }
    }
    final target = profile.targetWeightKg;
    if (target != null &&
        repository.currentWeightKg <= target) {
      return '目标达成！接下来一起稳稳维持。';
    }
    return '今天稳稳的，继续保持。';
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department,
              size: 17, color: AppColors.peach),
          const SizedBox(width: 4),
          Text(
            streak > 0 ? '连续 $streak 天' : '今天开个头',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.weightKg,
    required this.previousKg,
    required this.unit,
    required this.lastRecord,
    required this.onRecord,
  });

  final double? weightKg;
  final double? previousKg;
  final String unit;
  final WeightRecord? lastRecord;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = weightKg == null || previousKg == null
        ? null
        : weightKg! - previousKg!;
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日体重',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: weightKg == null
                            ? '—'
                            : weightValueText(weightKg!, unit),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      TextSpan(
                        text: ' ${weightUnitLabel(unit)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  weightKg == null
                      ? (lastRecord == null
                          ? '还没有称重记录'
                          : '上次 ${AppDate.dateLabel(AppDate.parse(lastRecord!.date))} · ${weightText(lastRecord!.weightKg, unit)}')
                      : (delta == null
                          ? '第一次记录'
                          : '较上次 ${signedWeight(delta, unit)}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: delta != null && delta < 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: onRecord,
            icon: const Icon(Icons.add, size: 18),
            label: Text(weightKg == null ? '记录体重' : '再记一次'),
          ),
        ],
      ),
    );
  }
}

class _CalorieRow extends StatelessWidget {
  const _CalorieRow({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MealsCard extends StatelessWidget {
  const _MealsCard({
    required this.repository,
    required this.dateKey,
    required this.summary,
    required this.onOpenRecipes,
  });

  final AppRepository repository;
  final String dateKey;
  final DaySummary summary;
  final VoidCallback onOpenRecipes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = repository.entriesFor(dateKey);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '今日餐单',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                summary.totalCount == 0
                    ? '未安排'
                    : '${summary.completedCount}/${summary.totalCount} 完成',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => showAddFoodSheet(
                  context,
                  date: dateKey,
                  initialMeal: _currentMealType(),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
          if (entries.isEmpty)
            EmptyState(
              icon: Icons.restaurant_menu,
              title: '今天还没有安排',
              message: '从食谱库挑一份，或者直接记一笔。',
              actionLabel: '去食谱库',
              onAction: onOpenRecipes,
            )
          else
            for (final mealType in allMealTypes) ...[
              _MealBlock(
                mealType: mealType,
                entries: entries
                    .where((entry) => entry.mealType == mealType)
                    .toList(),
                onToggle: (entry, value) =>
                    repository.setEntryCompleted(entry.id, value),
                onAdd: () => showAddFoodSheet(
                  context,
                  date: dateKey,
                  initialMeal: mealType,
                ),
                onDelete: (entry) => _deleteEntry(context, entry),
              ),
              if (mealType != allMealTypes.last) const Divider(height: 18),
            ],
        ],
      ),
    );
  }

  String _currentMealType() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) return 'breakfast';
    if (hour >= 10 && hour < 15) return 'lunch';
    if (hour >= 15 && hour < 17) return 'snack';
    if (hour >= 17 && hour < 22) return 'dinner';
    return 'snack';
  }

  Future<void> _deleteEntry(BuildContext context, MealEntry entry) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除这条饮食记录？',
      message: '${mealLabel(entry.mealType)} · ${entry.name} · ${entry.calories} kcal',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) return;
    await repository.deleteMealEntry(entry.id);
  }
}

class _MealBlock extends StatelessWidget {
  const _MealBlock({
    required this.mealType,
    required this.entries,
    required this.onToggle,
    required this.onAdd,
    required this.onDelete,
  });

  final String mealType;
  final List<MealEntry> entries;
  final void Function(MealEntry entry, bool value) onToggle;
  final VoidCallback onAdd;
  final void Function(MealEntry entry) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.calories);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              mealLabel(mealType),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            if (entries.isNotEmpty)
              Text(
                '$total kcal',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const Spacer(),
            IconButton(
              onPressed: onAdd,
              tooltip: '添加${mealLabel(mealType)}',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline, size: 20),
            ),
          ],
        ),
        if (entries.isEmpty)
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '未安排 · 点这里添加',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Checkbox(
                    value: entry.isCompleted,
                    onChanged: (value) => onToggle(entry, value ?? false),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: entry.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: entry.isCompleted
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.calories} kcal',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '更多',
                    icon: const Icon(Icons.more_vert, size: 18),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'delete') onDelete(entry);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
