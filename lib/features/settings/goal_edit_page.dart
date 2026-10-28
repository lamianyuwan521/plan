import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/app_theme.dart';
import '../../core/calculators.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';

class GoalEditPage extends StatefulWidget {
  const GoalEditPage({super.key});

  @override
  State<GoalEditPage> createState() => _GoalEditPageState();
}

class _GoalEditPageState extends State<GoalEditPage> {
  late final TextEditingController _target;
  late final TextEditingController _budget;
  late final TextEditingController _water;
  late double _rate;
  late bool _budgetManual;
  late bool _waterManual;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final repository = context.read<AppRepository>();
    final profile = repository.profile;
    _target = TextEditingController(
      text: profile.targetWeightKg == null
          ? ''
          : weightValueText(profile.targetWeightKg!, profile.weightUnit),
    );
    _budget = TextEditingController(
      text: '${profile.calorieBudgetOverride ?? repository.dailyBudget}',
    );
    _water = TextEditingController(text: '${repository.waterGoal}');
    _rate = profile.weeklyRateKg;
    _budgetManual = profile.calorieBudgetOverride != null;
    _waterManual = profile.waterGoalManual;
  }

  @override
  void dispose() {
    _target.dispose();
    _budget.dispose();
    _water.dispose();
    super.dispose();
  }

  double? get _targetKg {
    final value = double.tryParse(_target.text.trim().replaceAll(',', '.'));
    if (value == null) return null;
    return displayToKg(
      value,
      context.read<AppRepository>().profile.weightUnit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repository = context.watch<AppRepository>();
    final profile = repository.profile;
    final unit = profile.weightUnit;
    final current = repository.currentWeightKg;
    final targetKg = _targetKg;
    final manualBudget = int.tryParse(_budget.text.trim());
    final manualWater = int.tryParse(_water.text.trim());
    final draft = profile.copyWith(
      targetWeightKg: targetKg,
      weeklyRateKg: _rate,
      calorieBudgetOverride: _budgetManual ? manualBudget : null,
      waterGoalManual: _waterManual,
      waterGoalMl: _waterManual
          ? (manualWater ?? profile.waterGoalMl)
          : profile.waterGoalMl,
    );
    final plan = calculateCaloriePlan(
      profile: draft,
      currentWeightKg: current,
    );
    final predicted = predictTargetDate(
      currentWeightKg: current,
      targetWeightKg: targetKg,
      weeklyRateKg: _rate,
    );
    final waterGoal = _waterManual
        ? (manualWater ?? profile.waterGoalMl)
        : waterGoalFor(current);
    final safe = targetKg == null || isSafeWeeklyRate(_rate, current);

    return Scaffold(
      appBar: AppBar(title: const Text('目标与预算')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          TextField(
            controller: _target,
            onChanged: (_) => setState(() {}),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: '目标体重',
              hintText: '留空表示暂不设目标',
              suffixText: weightUnitLabel(unit),
              prefixIcon: const Icon(Icons.flag_outlined),
            ),
          ),
          const SizedBox(height: 18),
          Text('每周减重速度', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final rate in const [0.25, 0.5, 0.75, 1.0])
                ChoiceChip(
                  label: Text('$rate kg'),
                  selected: _rate == rate,
                  onSelected: (_) => setState(() => _rate = rate),
                ),
            ],
          ),
          if (!safe) ...[
            const SizedBox(height: 8),
            Text(
              '这个速度偏快，建议每周不超过体重的 1%。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SectionCard(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '预览',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _PreviewMetric(
                        label: '每日预算',
                        value: '${plan.budget}',
                        unit: 'kcal',
                      ),
                    ),
                    Expanded(
                      child: _PreviewMetric(
                        label: '喝水目标',
                        value: '$waterGoal',
                        unit: 'ml',
                      ),
                    ),
                    Expanded(
                      child: _PreviewMetric(
                        label: '预计达成',
                        value: predicted == null
                            ? '—'
                            : '${predicted.month}/${predicted.day}',
                        unit: predicted == null ? '未设目标' : '${predicted.year} 年',
                      ),
                    ),
                  ],
                ),
                if (plan.maintain) ...[
                  const SizedBox(height: 10),
                  Text(
                    '当前按维持体重计算，热量预算 = 日常总消耗。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (plan.floorApplied) ...[
                  const SizedBox(height: 6),
                  Text(
                    '预算已按健康下限调整，不建议吃得更少。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('每日热量预算', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'auto', label: Text('自动计算')),
              ButtonSegment(value: 'manual', label: Text('手动设置')),
            ],
            selected: {_budgetManual ? 'manual' : 'auto'},
            onSelectionChanged: (value) => setState(() {
              _budgetManual = value.first == 'manual';
              if (!_budgetManual) _budget.text = '${plan.budget}';
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _budget,
            enabled: _budgetManual,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              labelText: _budgetManual ? '手动预算' : '自动预算',
              suffixText: 'kcal',
              helperText: _budgetManual
                  ? '建议不低于 1200 kcal，且不低于基础代谢'
                  : '按当前体重与活动量每日自动重算',
            ),
          ),
          const SizedBox(height: 18),
          Text('喝水目标', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'auto', label: Text('按体重自动')),
              ButtonSegment(value: 'manual', label: Text('手动设置')),
            ],
            selected: {_waterManual ? 'manual' : 'auto'},
            onSelectionChanged: (value) => setState(() {
              _waterManual = value.first == 'manual';
              if (!_waterManual) _water.text = '${waterGoalFor(current)}';
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _water,
            enabled: _waterManual,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              labelText: _waterManual ? '手动目标' : '自动目标',
              suffixText: 'ml',
              helperText: _waterManual
                  ? '建议 500–6000 ml'
                  : '体重 × 35 ml，限制在 1500–4000 ml',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final repository = context.read<AppRepository>();
    final profile = repository.profile;
    final targetKg = _targetKg;
    if (targetKg != null && (targetKg < 20 || targetKg > 300)) {
      showAppSnackBar(context, '目标体重超出范围');
      return;
    }
    int? budgetOverride;
    if (_budgetManual) {
      final value = int.tryParse(_budget.text.trim());
      if (value == null || value < 800 || value > 4000) {
        showAppSnackBar(context, '热量预算请填写 800–4000 kcal');
        return;
      }
      budgetOverride = value;
    }
    int? waterValue;
    if (_waterManual) {
      final value = int.tryParse(_water.text.trim());
      if (value == null || value < 500 || value > 6000) {
        showAppSnackBar(context, '喝水目标请填写 500–6000 ml');
        return;
      }
      waterValue = value;
    }
    final predicted = predictTargetDate(
      currentWeightKg: repository.currentWeightKg,
      targetWeightKg: targetKg,
      weeklyRateKg: _rate,
    );
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    await repository.updateProfile(
      profile.copyWith(
        targetWeightKg: targetKg,
        targetDate: predicted == null ? null : AppDate.key(predicted),
        weeklyRateKg: _rate,
        calorieBudgetOverride: budgetOverride,
        waterGoalManual: _waterManual,
        waterGoalMl: _waterManual
            ? waterValue!
            : waterGoalFor(repository.currentWeightKg),
      ),
    );
    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('目标与预算已更新')));
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          unit,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
