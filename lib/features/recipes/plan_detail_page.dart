import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/models.dart';
import 'plan_edit_page.dart';

class PlanDetailPage extends StatelessWidget {
  const PlanDetailPage({super.key, required this.planId});

  final String planId;

  void _openEditor(BuildContext context, DietPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PlanEditPage(initialPlan: plan, saveAsCopy: !plan.isCustom),
      ),
    );
  }

  Future<void> _delete(BuildContext context, DietPlan plan) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除「${plan.name}」？',
      message: '只会删除这套方案，已经铺进日历的三餐不会受影响。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final repository = context.read<AppRepository>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await repository.deleteDietPlan(plan.id);
    if (!context.mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('已删除「${plan.name}」')));
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final plan = repository.dietPlanById(planId);
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('长期食谱')),
        body: const EmptyState(
          icon: Icons.calendar_month_outlined,
          title: '方案不存在',
          message: '这套长期食谱可能已经删除。',
        ),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: plan.isCustom ? '编辑方案' : '复制并编辑',
            onPressed: () => _openEditor(context, plan),
            icon: Icon(
              plan.isCustom ? Icons.edit_outlined : Icons.content_copy_outlined,
            ),
          ),
          if (plan.isCustom)
            PopupMenuButton<String>(
              tooltip: '更多',
              onSelected: (value) {
                if (value == 'delete') _delete(context, plan);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('删除方案')),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plan.description.isNotEmpty)
                  Text(
                    plan.description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  )
                else
                  Text(
                    '自定义长期食谱',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (plan.isCustom) const TagChip(label: '自定义'),
                    for (final tag in plan.tags) TagChip(label: tag),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _PlanStat(
                      label: '天数',
                      value: '${plan.days.length}',
                      unit: '天',
                    ),
                    _PlanStat(
                      label: '日均热量',
                      value: '${plan.averageCalories}',
                      unit: 'kcal',
                    ),
                    _PlanStat(
                      label: '餐次',
                      value: '${plan.mealCount}',
                      unit: '餐',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (plan.days.isEmpty) ...[
            const SizedBox(height: 16),
            EmptyState(
              icon: Icons.edit_note_outlined,
              title: '这套方案还没有安排',
              message: '点右上角的编辑按钮，给每天加上三餐。',
              actionLabel: '编辑方案',
              onAction: () => _openEditor(context, plan),
            ),
          ],
          const SizedBox(height: 16),
          for (var index = 0; index < plan.days.length; index++) ...[
            _PlanDayCard(index: index, day: plan.days[index]),
            if (index < plan.days.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          SectionCard(
            color: AppColors.warning.withValues(alpha: 0.07),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '热量为估算值，仅用于计划统计。极低热量方案不适合长期执行，'
                    '出现头晕、心慌、乏力或月经异常时请暂停方案、恢复正常饮食，'
                    '必要时咨询医生。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: plan.days.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => _AddPlanToCalendarSheet(plan: plan),
                  ),
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('加入计划'),
                ),
              ),
            ),
    );
  }
}

class _PlanStat extends StatelessWidget {
  const _PlanStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
      ),
    );
  }
}

class _PlanDayCard extends StatelessWidget {
  const _PlanDayCard({required this.index, required this.day});

  final int index;
  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '第 ${index + 1} 天',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (day.weightJin != null) ...[
                const SizedBox(width: 8),
                TagChip(
                  label: '体重 ${day.weightJin!.toStringAsFixed(1)} 斤',
                  color: AppColors.water,
                ),
              ],
              const Spacer(),
              Text(
                '${day.calories} kcal',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (day.note != null) ...[
            const SizedBox(height: 4),
            Text(
              day.note!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final mealType in mainMealTypes)
            _PlanMealRow(mealType: mealType, meal: day.mealOf(mealType)),
        ],
      ),
    );
  }
}

class _PlanMealRow extends StatelessWidget {
  const _PlanMealRow({required this.mealType, required this.meal});

  final String mealType;
  final PlanMeal? meal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              mealLabel(mealType),
              style: theme.textTheme.labelSmall?.copyWith(
                color: muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              meal?.name ?? '未安排',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
                color: meal == null ? muted.withValues(alpha: 0.7) : null,
              ),
            ),
          ),
          if (meal != null) ...[
            const SizedBox(width: 10),
            Text(
              '${meal!.calories} kcal',
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddPlanToCalendarSheet extends StatefulWidget {
  const _AddPlanToCalendarSheet({required this.plan});

  final DietPlan plan;

  @override
  State<_AddPlanToCalendarSheet> createState() =>
      _AddPlanToCalendarSheetState();
}

class _AddPlanToCalendarSheetState extends State<_AddPlanToCalendarSheet> {
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;

  DietPlan get _plan => widget.plan;

  int get _dayCount {
    final start = DateTime.utc(_start.year, _start.month, _start.day);
    final end = DateTime.utc(_end.year, _end.month, _end.day);
    return end.difference(start).inDays + 1;
  }

  DateTime get _latestEnd =>
      DateTime(_start.year, _start.month, _start.day + _plan.days.length - 1);

  int get _mealCount => _plan.days
      .take(_dayCount)
      .fold<int>(0, (sum, day) => sum + day.meals.length);

  int get _totalKcal =>
      _plan.days.take(_dayCount).fold<int>(0, (sum, day) => sum + day.calories);

  @override
  void initState() {
    super.initState();
    _start = AppDate.today();
    _end = _latestEnd;
  }

  DateTime _dayAt(int offset) =>
      DateTime(_start.year, _start.month, _start.day + offset);

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '从哪一天开始',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _start = AppDate.dateOnly(picked);
      if (_end.isBefore(_start)) _end = _start;
      if (_end.isAfter(_latestEnd)) _end = _latestEnd;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: _latestEnd,
      helpText: '到哪一天结束',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    setState(() => _end = AppDate.dateOnly(picked));
  }

  Future<void> _save() async {
    if (_saving) return;
    final repository = context.read<AppRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final dayCount = _dayCount;
    final entries = <MealEntry>[];
    final ids = <String>[];
    for (var offset = 0; offset < dayCount; offset++) {
      final dateKey = AppDate.key(_dayAt(offset));
      final day = _plan.days[offset];
      final orders = <String, int>{
        for (final meal in day.meals)
          meal.mealType: repository
              .entriesFor(dateKey, mealType: meal.mealType)
              .length,
      };
      for (final meal in day.meals) {
        final id = repository.newId();
        ids.add(id);
        entries.add(
          MealEntry(
            id: id,
            date: dateKey,
            mealType: meal.mealType,
            name: meal.name,
            calories: meal.calories,
            sortOrder: orders[meal.mealType] ?? 0,
          ),
        );
        orders[meal.mealType] = (orders[meal.mealType] ?? 0) + 1;
      }
    }
    setState(() => _saving = true);
    await repository.addMealEntries(entries);
    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已加入 $dayCount 天 · ${entries.length} 餐'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => repository.deleteMealEntries(ids),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final truncated = _dayCount < _plan.days.length;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '加入计划',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                ),
              ],
            ),
            Text(
              '${_plan.name} · 共 ${_plan.days.length} 天 · '
              '日均 ${_plan.averageCalories} kcal',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _DateField(
              label: '开始日期',
              value: AppDate.fullDateLabel(_start),
              onTap: _pickStart,
            ),
            const SizedBox(height: 10),
            _DateField(
              label: '结束日期',
              value: AppDate.fullDateLabel(_end),
              onTap: _pickEnd,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppDate.key(_start)} → ${AppDate.key(_end)} · '
                    '$_dayCount 天 · $_mealCount 餐 · 约 $_totalKcal kcal',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    truncated
                        ? '只安排方案的前 $_dayCount 天（方案共 ${_plan.days.length} 天）。'
                        : '从方案第 1 天开始，完整安排 $_dayCount 天。',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '目标日期已有安排的餐次会追加，不会覆盖；加入后可在日历里逐条调整。',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('加入 $_dayCount 天计划'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.edit_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
