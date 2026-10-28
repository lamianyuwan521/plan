import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/calculators.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/models.dart';
import 'weight_chart.dart';
import 'weight_entry_sheet.dart';

class WeightPage extends StatefulWidget {
  const WeightPage({super.key});

  @override
  State<WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  int _rangeDays = 30;
  bool _showMovingAverage = true;

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final theme = Theme.of(context);
    final profile = repository.profile;
    final unit = profile.weightUnit;
    final records = repository.weightRecords;
    final descending = records.reversed.toList();
    final current = repository.currentWeightKg;
    final target = profile.targetWeightKg;
    final bmi = calculateBmi(current, profile.heightCm);
    final latest = repository.latestWeight;
    final totalChange = current - profile.startWeightKg;
    final targetDistance = target == null ? null : current - target;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        PageHeader(
          title: '体重',
          subtitle: '建议每天在同一时间、同样的状态下称重',
          actions: [
            FilledButton.icon(
              onPressed: () => showWeightEntrySheet(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('记录体重'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 4 : 2;
            const spacing = 12.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: width,
                  child: _StatCard(
                    label: '当前体重',
                    value: weightValueText(current, unit),
                    unit: weightUnitLabel(unit),
                    caption: latest == null
                        ? '来自初始体重'
                        : AppDate.dateLabel(
                            AppDate.parse(latest.date),
                          ),
                    accent: theme.colorScheme.primary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _StatCard(
                    label: '累计变化',
                    value: signedWeight(totalChange, unit),
                    caption: '初始 ${weightText(profile.startWeightKg, unit)}',
                    accent: totalChange <= 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _StatCard(
                    label: '距目标',
                    value: targetDistance == null
                        ? '未设置'
                        : signedWeight(targetDistance, unit),
                    caption: target == null
                        ? '在设置里设定目标'
                        : '目标 ${weightText(target, unit)}',
                    accent: target == null
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.primary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _StatCard(
                    label: 'BMI',
                    value: bmi.toStringAsFixed(1),
                    caption: '${bmiCategory(bmi)} · 中国标准',
                    accent: theme.colorScheme.primary,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '体重趋势',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  FilterChip(
                    label: const Text('7 日均线'),
                    selected: _showMovingAverage,
                    onSelected: (value) =>
                        setState(() => _showMovingAverage = value),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final option in const [
                    (7, '7 天'),
                    (30, '30 天'),
                    (90, '90 天'),
                    (0, '全部'),
                  ])
                    ChoiceChip(
                      label: Text(option.$2),
                      selected: _rangeDays == option.$1,
                      onSelected: (_) =>
                          setState(() => _rangeDays = option.$1),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              WeightChart(
                records: records,
                unit: unit,
                rangeDays: _rangeDays,
                showMovingAverage: _showMovingAverage,
                targetKg: target,
              ),
              if (_isWeeklyAggregated(records)) ...[
                const SizedBox(height: 8),
                Text(
                  '时间跨度超过 180 天，图表已按周平均展示。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              '记录',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '共 ${records.length} 条',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (descending.isEmpty)
          SectionCard(
            child: EmptyState(
              icon: Icons.monitor_weight_outlined,
              title: '还没有体重记录',
              message: '记录第一次体重，日历和趋势就会亮起来。',
              actionLabel: '记录体重',
              onAction: () => showWeightEntrySheet(context),
            ),
          )
        else
          ..._buildGroups(context, repository, descending, records, unit),
      ],
    );
  }

  bool _isWeeklyAggregated(List<WeightRecord> records) {
    if (_rangeDays != 0 || records.isEmpty) return false;
    final earliest = records
        .map((r) => AppDate.parse(r.date))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return AppDate.daysBetween(earliest, AppDate.today()) + 1 > 180;
  }

  List<Widget> _buildGroups(
    BuildContext context,
    AppRepository repository,
    List<WeightRecord> descending,
    List<WeightRecord> ascending,
    String unit,
  ) {
    final theme = Theme.of(context);
    final previousById = <String, WeightRecord>{};
    WeightRecord? previous;
    for (final record in ascending) {
      previousById[record.id] = previous ?? record;
      previous = record;
    }

    final groups = <String, List<WeightRecord>>{};
    for (final record in descending) {
      final key = record.date.length >= 7
          ? record.date.substring(0, 7)
          : record.date;
      groups.putIfAbsent(key, () => []).add(record);
    }

    final widgets = <Widget>[];
    for (final entry in groups.entries) {
      final parts = entry.key.split('-');
      final year = parts.isNotEmpty ? parts[0] : '';
      final month = parts.length > 1 ? parts[1] : '';
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            '$year 年 ${int.tryParse(month) ?? month} 月 · ${entry.value.length} 条',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      widgets.add(
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < entry.value.length; index++) ...[
                _WeightRow(
                  record: entry.value[index],
                  previous: previousById[entry.value[index].id] ==
                          entry.value[index]
                      ? null
                      : previousById[entry.value[index].id],
                  unit: unit,
                  onEdit: () => showWeightEntrySheet(
                    context,
                    existing: entry.value[index],
                  ),
                  onDelete: () => _deleteRecord(
                    context,
                    repository,
                    entry.value[index],
                  ),
                ),
                if (index < entry.value.length - 1)
                  const Divider(height: 1, indent: 14, endIndent: 14),
              ],
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Future<void> _deleteRecord(
    BuildContext context,
    AppRepository repository,
    WeightRecord record,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除这条体重记录？',
      message:
          '${AppDate.fullDateLabel(AppDate.parse(record.date))} · ${weightText(record.weightKg, repository.profile.weightUnit)}',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await repository.deleteWeight(record.id);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      '已删除记录',
      actionLabel: '撤销',
      onAction: () => repository.addWeight(record),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.accent,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;
  final String caption;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({
    required this.record,
    required this.previous,
    required this.unit,
    required this.onEdit,
    required this.onDelete,
  });

  final WeightRecord record;
  final WeightRecord? previous;
  final String unit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = AppDate.parse(record.date);
    final delta = previous == null ? null : record.weightKg - previous!.weightKg;
    final deltaText = previous == null
        ? '首次记录'
        : '较 ${previous!.date.substring(5).replaceAll('-', '/')} '
            '${signedWeight(delta!, unit)}';
    final deltaColor = delta != null && delta < 0
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${date.day} 日',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '周${AppDate.shortWeekday(date)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weightText(record.weightKg, unit),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppDate.timeLabel(record.recordedAt)} · $deltaText',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: deltaColor,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }
}
