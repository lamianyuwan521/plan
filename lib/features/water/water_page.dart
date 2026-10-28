import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/models.dart';

class WaterPage extends StatelessWidget {
  const WaterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final theme = Theme.of(context);
    final today = AppDate.today();
    final todayKey = AppDate.key(today);
    final total = repository.waterTotalFor(todayKey);
    final goal = repository.waterGoal;
    final logs = repository.waterFor(todayKey);
    final percent = goal == 0 ? 0.0 : total / goal;
    final reached = total >= goal;
    final streak = _streak(repository);
    final recentDays = List<DateTime>.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        PageHeader(
          title: '喝水',
          subtitle: '目标 $goal ml · 少量多次更容易坚持',
          actions: [
            OutlinedButton.icon(
              onPressed: () => _editGoal(context, repository),
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('目标'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            children: [
              ProgressRing(
                value: percent,
                size: 150,
                strokeWidth: 13,
                color: AppColors.water,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.water,
                      ),
                    ),
                    Text(
                      '/ $goal ml',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reached ? '已达标' : percentText(percent),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: reached
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _WaterStat(
                    label: '今日目标',
                    value: '$goal ml',
                  ),
                  _WaterStat(
                    label: reached ? '超出目标' : '还差',
                    value: '${(goal - total).abs()} ml',
                    color: reached
                        ? theme.colorScheme.primary
                        : AppColors.water,
                  ),
                  _WaterStat(
                    label: '连续达标',
                    value: '$streak 天',
                    color: streak > 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '记一笔',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amount in const [200, 300, 500])
                    FilledButton.tonal(
                      onPressed: () => repository.addWater(amount),
                      child: Text('+$amount ml'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _customAdd(context, repository),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('自定义'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '一杯水大约 200–300 ml，运动或天气热时可以适当增加。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '今日记录',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${logs.length} 次',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (logs.isEmpty)
                EmptyState(
                  icon: Icons.water_drop_outlined,
                  title: '今天还没有喝水记录',
                  message: '点上面的快捷按钮，或自定义记一笔。',
                )
              else
                for (var index = 0; index < logs.length; index++) ...[
                  _WaterLogRow(
                    log: logs[index],
                    onDelete: () => _deleteLog(context, repository, logs[index]),
                  ),
                  if (index < logs.length - 1) const Divider(height: 14),
                ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '近 7 天',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '柱高 = 当日饮水量',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              MiniBarChart(
                values: recentDays
                    .map((day) => repository.waterTotalFor(AppDate.key(day)))
                    .toList(),
                labels:
                    recentDays.map((day) => AppDate.shortWeekday(day)).toList(),
                highlight: recentDays
                    .map((day) =>
                        repository.waterTotalFor(AppDate.key(day)) >= goal)
                    .toList(),
                height: 120,
                color: AppColors.water,
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _streak(AppRepository repository) {
    var day = AppDate.today();
    final goal = repository.waterGoal;
    if (repository.waterTotalFor(AppDate.key(day)) < goal) {
      day = day.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (repository.waterTotalFor(AppDate.key(day)) >= goal) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  Future<void> _editGoal(
    BuildContext context,
    AppRepository repository,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _WaterGoalDialog(repository: repository),
    );
  }

  Future<void> _customAdd(
    BuildContext context,
    AppRepository repository,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _WaterAddSheet(repository: repository),
    );
  }

  Future<void> _deleteLog(
    BuildContext context,
    AppRepository repository,
    WaterLog log,
  ) async {
    await repository.deleteWater(log.id);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      '已删除记录',
      actionLabel: '撤销',
      onAction: () => repository.addWaterLog(log),
    );
  }
}

class _WaterStat extends StatelessWidget {
  const _WaterStat({
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
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
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

class _WaterLogRow extends StatelessWidget {
  const _WaterLogRow({required this.log, required this.onDelete});

  final WaterLog log;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.water_drop, size: 16, color: AppColors.water),
        const SizedBox(width: 8),
        Text(
          AppDate.timeLabel(log.recordedAt),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          '+${log.amountMl} ml',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton(
          onPressed: onDelete,
          tooltip: '删除这条记录',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.undo, size: 18),
        ),
      ],
    );
  }
}

class _WaterAddSheet extends StatefulWidget {
  const _WaterAddSheet({required this.repository});

  final AppRepository repository;

  @override
  State<_WaterAddSheet> createState() => _WaterAddSheetState();
}

class _WaterAddSheetState extends State<_WaterAddSheet> {
  final _amount = TextEditingController(text: '300');
  DateTime _date = AppDate.today();
  TimeOfDay _time = TimeOfDay.fromDateTime(DateTime.now());

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() => _date = AppDate.dateOnly(picked));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: '选择时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null || amount < 50 || amount > 2000) {
      showAppSnackBar(context, '水量请填写 50–2000 ml');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final at = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    await widget.repository.addWater(amount, at: at);
    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('已记录 +$amount ml')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '自定义喝水',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: '关闭',
              ),
            ],
          ),
          TextField(
            controller: _amount,
            autofocus: false,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: const InputDecoration(
              labelText: '水量',
              suffixText: 'ml',
              prefixIcon: Icon(Icons.water_drop_outlined),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('${_date.year}/${_date.month}/${_date.day}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  label: Text(
                    AppDate.timeLabel(
                      DateTime(2000, 1, 1, _time.hour, _time.minute),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _save,
            child: const Text('记一笔'),
          ),
        ],
      ),
    );
  }
}

class _WaterGoalDialog extends StatefulWidget {
  const _WaterGoalDialog({required this.repository});

  final AppRepository repository;

  @override
  State<_WaterGoalDialog> createState() => _WaterGoalDialogState();
}

class _WaterGoalDialogState extends State<_WaterGoalDialog> {
  late bool _auto;
  late final TextEditingController _goal;

  @override
  void initState() {
    super.initState();
    _auto = !widget.repository.profile.waterGoalManual;
    _goal = TextEditingController(
      text: '${widget.repository.waterGoal}',
    );
  }

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repository = widget.repository;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_auto) {
      await repository.updateProfile(
        repository.profile.copyWith(waterGoalManual: false),
      );
    } else {
      final value = int.tryParse(_goal.text.trim());
      if (value == null || value < 500 || value > 6000) {
        showAppSnackBar(context, '目标请填写 500–6000 ml');
        return;
      }
      await repository.updateProfile(
        repository.profile.copyWith(
          waterGoalManual: true,
          waterGoalMl: value,
        ),
      );
    }
    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('喝水目标已更新')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final autoGoal = repositoryAutoGoal(widget.repository);
    return AlertDialog(
      title: const Text('喝水目标'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('按体重自动计算'),
            subtitle: Text(
              '当前推荐 $autoGoal ml（体重 × 35 ml）',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            value: _auto,
            onChanged: (value) => setState(() {
              _auto = value;
              if (value) _goal.text = '$autoGoal';
            }),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _goal,
            enabled: !_auto,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: const InputDecoration(
              labelText: '每日目标',
              suffixText: 'ml',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  int repositoryAutoGoal(AppRepository repository) {
    final weight = repository.currentWeightKg;
    final raw = weight * 35;
    final rounded = (raw / 100).round() * 100;
    return rounded.clamp(1500, 4000).toInt();
  }
}
