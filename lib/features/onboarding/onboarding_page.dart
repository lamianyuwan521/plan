import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/app_theme.dart';
import '../../core/calculators.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/models.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  bool _saving = false;

  final _nickname = TextEditingController(text: '小一二');
  final _birthYear = TextEditingController(text: '1998');
  final _height = TextEditingController(text: '165');
  final _weight = TextEditingController(text: '65');
  final _target = TextEditingController(text: '58');

  String _gender = 'female';
  String _activity = 'light';
  String _unit = 'kg';
  double _rate = 0.5;
  bool _skipTarget = false;

  static const _activities = [
    ('sedentary', '久坐', '办公室工作，几乎不运动'),
    ('light', '轻度活动', '每周 1–3 次轻运动'),
    ('moderate', '中度活动', '每周 3–5 次运动'),
    ('active', '高度活动', '每周 6–7 次运动或体力工作'),
  ];

  @override
  void dispose() {
    _nickname.dispose();
    _birthYear.dispose();
    _height.dispose();
    _weight.dispose();
    _target.dispose();
    super.dispose();
  }

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  double? get _weightKg {
    final value = _parse(_weight.text);
    return value == null ? null : displayToKg(value, _unit);
  }

  double? get _targetKg {
    if (_skipTarget) return null;
    final value = _parse(_target.text);
    return value == null ? null : displayToKg(value, _unit);
  }

  Profile _draftProfile({bool onboardingDone = false}) {
    final weightKg = _weightKg ?? 65;
    final targetKg = _targetKg;
    final predicted = predictTargetDate(
      currentWeightKg: weightKg,
      targetWeightKg: targetKg,
      weeklyRateKg: _rate,
    );
    return Profile(
      nickname: _nickname.text.trim().isEmpty ? '小一二' : _nickname.text.trim(),
      gender: _gender,
      birthYear: int.tryParse(_birthYear.text.trim()) ?? 1998,
      heightCm: _parse(_height.text) ?? 165,
      activityLevel: _activity,
      weightUnit: _unit,
      startWeightKg: weightKg,
      targetWeightKg: targetKg,
      targetDate: predicted == null ? null : AppDate.key(predicted),
      weeklyRateKg: _rate,
      waterGoalMl: waterGoalFor(weightKg),
      waterGoalManual: false,
      onboardingDone: onboardingDone,
    );
  }

  String? _validateStep() {
    if (_step == 1) {
      if (_nickname.text.trim().isEmpty) return '给自己起个昵称吧';
      final birth = int.tryParse(_birthYear.text.trim());
      if (birth == null || birth < 1940 || birth > DateTime.now().year) {
        return '出生年份看起来不太对';
      }
      final height = _parse(_height.text);
      if (height == null || height < 100 || height > 230) {
        return '身高请填写 100–230 cm';
      }
      final weight = _weightKg;
      if (weight == null || weight < 20 || weight > 300) {
        return '体重请填写 20–300 kg（${weightUnitLabel(_unit)}模式按换算后的范围）';
      }
    }
    if (_step == 2 && !_skipTarget) {
      final target = _targetKg;
      if (target == null || target < 20 || target > 300) {
        return '目标体重请填写 20–300 kg';
      }
    }
    return null;
  }

  void _next() {
    final error = _validateStep();
    if (error != null) {
      showAppSnackBar(context, error);
      return;
    }
    if (_step >= 3) {
      _finish();
      return;
    }
    setState(() => _step += 1);
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    final repository = context.read<AppRepository>();
    final profile = _draftProfile(onboardingDone: true);
    try {
      await repository.addWeight(
        WeightRecord(
          id: repository.newId(),
          date: AppDate.todayKey(),
          recordedAt: DateTime.now(),
          weightKg: profile.startWeightKg,
        ),
      );
      await repository.updateProfile(profile);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, '保存失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            for (var i = 0; i < 4; i++)
                              Expanded(
                                child: Container(
                                  height: 4,
                                  margin:
                                      EdgeInsets.only(right: i < 3 ? 6 : 0),
                                  decoration: BoxDecoration(
                                    color: i <= _step
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_step + 1} / 4',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey<int>(_step),
                        child: _buildStep(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                  child: Row(
                    children: [
                      if (_step > 0)
                        TextButton(
                          onPressed: _saving ? null : _back,
                          child: const Text('上一步'),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _saving ? null : _next,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _step == 0
                                    ? '开始使用'
                                    : (_step == 3 ? '完成' : '下一步'),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _welcomeStep(),
      1 => _profileStep(),
      2 => _targetStep(),
      _ => _activityStep(),
    };
  }

  Widget _stepHeading(String title, String subtitle) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _welcomeStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const MascotAvatar(size: 92),
        const SizedBox(height: 22),
        Text(
          '小一二减肥记',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '把今天吃了什么、喝了多少、体重有没有降，\n收进一张不用动脑子的日历。',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 30),
        const _FeatureRow(
          icon: Icons.touch_app_outlined,
          title: '两步记录',
          message: '称重、打卡、喝水，每次不超过两步。',
        ),
        const _FeatureRow(
          icon: Icons.calendar_month_outlined,
          title: '一张日历复盘',
          message: '体重、三餐完成度、喝水达标情况同屏可见。',
        ),
        const _FeatureRow(
          icon: Icons.lock_outline,
          title: '数据只属于你',
          message: '不注册，记录保存在本机；只有使用 AI 助手时才会联网。',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.favorite_outline,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '慢慢来，小一二会陪你一起记录。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading('先认识一下你', '这些信息只用来计算每日热量预算和喝水目标。'),
        TextField(
          controller: _nickname,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '昵称',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
        Text('性别', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'female', label: Text('女')),
            ButtonSegment(value: 'male', label: Text('男')),
            ButtonSegment(value: 'unknown', label: Text('不透露')),
          ],
          selected: {_gender},
          onSelectionChanged: (value) =>
              setState(() => _gender = value.first),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _birthYear,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(labelText: '出生年份'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _height,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: '身高',
                  suffixText: 'cm',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('当前体重', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weight,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: '体重',
                  prefixIcon: Icon(Icons.monitor_weight_outlined),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'kg', label: Text('kg')),
                ButtonSegment(value: 'jin', label: Text('斤')),
              ],
              selected: {_unit},
              onSelectionChanged: (value) =>
                  setState(() => _unit = value.first),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '建议每天起床后、早餐前称重，数据会更稳定。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _targetStep() {
    final theme = Theme.of(context);
    final current = _weightKg ?? 65;
    final target = _targetKg;
    final predicted = predictTargetDate(
      currentWeightKg: current,
      targetWeightKg: target,
      weeklyRateKg: _rate,
    );
    final safe = target == null || isSafeWeeklyRate(_rate, current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading('想到达哪里？', '目标可以随时改，先设一个让自己舒服的节奏。'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _target,
                enabled: !_skipTarget,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: '目标体重',
                  suffixText: weightUnitLabel(_unit),
                  prefixIcon: const Icon(Icons.flag_outlined),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('每周减重速度', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final rate in const [0.25, 0.5, 0.75, 1.0])
              ChoiceChip(
                label: Text('$rate kg'),
                selected: _rate == rate,
                onSelected: (_) => setState(() => _rate = rate),
              ),
          ],
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Row(
            children: [
              Icon(
                predicted == null
                    ? Icons.self_improvement
                    : Icons.event_available_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      predicted == null
                          ? '先按维持体重来'
                          : '预计 ${AppDate.fullDateLabel(predicted)} 达成',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      predicted == null
                          ? '不设目标也可以，之后在设置里随时开启。'
                          : '按每周 $_rate kg 计算，约 ${((current - (target ?? current)) / _rate).ceil()} 周。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!safe) ...[
          const SizedBox(height: 10),
          Text(
            '这个速度偏快，建议每周不超过体重的 1%。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.warning,
            ),
          ),
        ],
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('先不定目标'),
          subtitle: const Text('按维持体重计算每日预算'),
          value: _skipTarget,
          onChanged: (value) => setState(() => _skipTarget = value),
        ),
      ],
    );
  }

  Widget _activityStep() {
    final theme = Theme.of(context);
    final profile = _draftProfile();
    final weightKg = profile.startWeightKg;
    final plan = calculateCaloriePlan(
      profile: profile,
      currentWeightKg: weightKg,
    );
    final bmi = calculateBmi(weightKg, profile.heightCm);
    final goal = waterGoalFor(weightKg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading('平时活动多吗？', '活动量决定每天的总消耗，也决定你的热量预算。'),
        for (final activity in _activities) ...[
          _ActivityOption(
            title: activity.$2,
            subtitle: activity.$3,
            selected: _activity == activity.$1,
            onTap: () => setState(() => _activity = activity.$1),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        SectionCard(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '你的每日计划',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ResultMetric(
                      label: '热量预算',
                      value: '${plan.budget}',
                      unit: 'kcal',
                    ),
                  ),
                  Expanded(
                    child: _ResultMetric(
                      label: '喝水目标',
                      value: '$goal',
                      unit: 'ml',
                    ),
                  ),
                  Expanded(
                    child: _ResultMetric(
                      label: 'BMI',
                      value: bmi.toStringAsFixed(1),
                      unit: bmiCategory(bmi),
                    ),
                  ),
                ],
              ),
              if (plan.floorApplied) ...[
                const SizedBox(height: 12),
                Text(
                  '已按健康下限调整预算，不建议吃得更少。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
              if (plan.maintain) ...[
                const SizedBox(height: 8),
                Text(
                  plan.maintain
                      ? '当前按维持体重计算，设置目标后会自动重新计算。'
                      : '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '完成后会进入「今日」，第一次体重已经帮你记好了。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
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

class _ActivityOption extends StatelessWidget {
  const _ActivityOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      onTap: onTap,
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
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

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
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
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
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
