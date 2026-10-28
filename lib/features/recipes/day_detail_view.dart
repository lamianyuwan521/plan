import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/models.dart';
import '../weight/weight_entry_sheet.dart';
import 'add_food_sheet.dart';
import 'recipe_detail_page.dart';

class DayDetailView extends StatelessWidget {
  const DayDetailView({super.key, required this.dateKey});

  final String dateKey;

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final theme = Theme.of(context);
    final unit = repository.profile.weightUnit;
    final date = AppDate.parse(dateKey);
    final summary = repository.summaryFor(dateKey);
    final records = repository.weightsForDate(dateKey);
    final entries = repository.entriesFor(dateKey);
    final budget = repository.dailyBudget;
    final isFuture = date.isAfter(AppDate.today());
    final weight = summary.weightKg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppDate.dateLabel(date),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    weight == null
                        ? '还没有记录体重'
                        : '体重 ${weightText(weight, unit)}'
                            '${records.length > 1 ? ' · ${records.length} 次记录' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: weight == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: isFuture
                  ? null
                  : () => showWeightEntrySheet(
                        context,
                        date: date,
                        existing: repository.lastRecordOnDate(dateKey),
                      ),
              icon: const Icon(Icons.monitor_weight_outlined, size: 18),
              label: Text(weight == null ? '记录体重' : '改体重'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SummaryPill(
              label: '已吃',
              value: '${summary.consumedKcal} / $budget kcal',
              color: summary.consumedKcal > budget
                  ? AppColors.warning
                  : theme.colorScheme.primary,
            ),
            _SummaryPill(
              label: '计划',
              value: '${summary.plannedKcal} kcal',
            ),
            _SummaryPill(
              label: '完成',
              value: summary.totalCount == 0
                  ? '未安排'
                  : '${summary.completedCount}/${summary.totalCount}',
            ),
            _SummaryPill(
              label: '喝水',
              value:
                  '${summary.waterMl} / ${summary.waterGoalMl} ml',
              color: AppColors.water,
            ),
          ],
        ),
        if (isFuture) ...[
          const SizedBox(height: 10),
          Text(
            '这是未来的计划，到当天才能打卡。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < allMealTypes.length; index++) ...[
                _MealBlock(
                  mealType: allMealTypes[index],
                  entries: entries
                      .where(
                        (entry) => entry.mealType == allMealTypes[index],
                      )
                      .toList(),
                  isFuture: isFuture,
                  onToggle: (entry, value) =>
                      repository.setEntryCompleted(entry.id, value),
                  onAdd: () => showAddFoodSheet(
                    context,
                    date: dateKey,
                    initialMeal: allMealTypes[index],
                  ),
                  onViewRecipe: (entry) {
                    if (entry.recipeId == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RecipeDetailPage(
                          recipeId: entry.recipeId!,
                        ),
                      ),
                    );
                  },
                  onDelete: (entry) =>
                      _deleteEntry(context, repository, entry),
                  canViewRecipe: (entry) =>
                      entry.recipeId != null &&
                      repository.recipeById(entry.recipeId) != null,
                ),
                if (index < allMealTypes.length - 1)
                  const Divider(height: 20),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _deleteEntry(
    BuildContext context,
    AppRepository repository,
    MealEntry entry,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除这条饮食记录？',
      message:
          '${mealLabel(entry.mealType)} · ${entry.name} · ${entry.calories} kcal',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await repository.deleteMealEntry(entry.id);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      '已删除',
      actionLabel: '撤销',
      onAction: () => repository.addMealEntry(entry),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealBlock extends StatelessWidget {
  const _MealBlock({
    required this.mealType,
    required this.entries,
    required this.isFuture,
    required this.onToggle,
    required this.onAdd,
    required this.onViewRecipe,
    required this.onDelete,
    required this.canViewRecipe,
  });

  final String mealType;
  final List<MealEntry> entries;
  final bool isFuture;
  final void Function(MealEntry entry, bool value) onToggle;
  final VoidCallback onAdd;
  final void Function(MealEntry entry) onViewRecipe;
  final void Function(MealEntry entry) onDelete;
  final bool Function(MealEntry entry) canViewRecipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.calories);
    final completed = entries.where((entry) => entry.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              mealLabel(mealType),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            if (entries.isNotEmpty) ...[
              Text(
                '$total kcal',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$completed/${entries.length} 完成',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: completed == entries.length
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else
              Text(
                '未安排',
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
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '还没有安排，去食谱库挑一份',
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
                    onChanged: isFuture
                        ? null
                        : (value) => onToggle(entry, value ?? false),
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
                      if (value == 'view') onViewRecipe(entry);
                      if (value == 'delete') onDelete(entry);
                    },
                    itemBuilder: (context) => [
                      if (canViewRecipe(entry))
                        const PopupMenuItem(
                          value: 'view',
                          child: Text('查看食谱'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('删除'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
