import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _nickname;
  late final TextEditingController _birthYear;
  late final TextEditingController _height;
  late final TextEditingController _startWeight;
  late String _gender;
  late String _activity;
  bool _saving = false;

  static const _activities = [
    ('sedentary', '久坐', '几乎不运动'),
    ('light', '轻度活动', '每周 1–3 次轻运动'),
    ('moderate', '中度活动', '每周 3–5 次运动'),
    ('active', '高度活动', '每周 6–7 次运动'),
  ];

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppRepository>().profile;
    _nickname = TextEditingController(text: profile.nickname);
    _birthYear = TextEditingController(text: '${profile.birthYear}');
    _height = TextEditingController(text: profile.heightCm.toStringAsFixed(0));
    _startWeight = TextEditingController(
      text: weightValueText(profile.startWeightKg, profile.weightUnit),
    );
    _gender = profile.gender;
    _activity = profile.activityLevel;
  }

  @override
  void dispose() {
    _nickname.dispose();
    _birthYear.dispose();
    _height.dispose();
    _startWeight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final repository = context.read<AppRepository>();
    final profile = repository.profile;
    final nickname = _nickname.text.trim();
    final birthYear = int.tryParse(_birthYear.text.trim());
    final height = double.tryParse(_height.text.trim().replaceAll(',', '.'));
    final startDisplay =
        double.tryParse(_startWeight.text.trim().replaceAll(',', '.'));
    final startKg = startDisplay == null
        ? null
        : displayToKg(startDisplay, profile.weightUnit);

    if (nickname.isEmpty) {
      showAppSnackBar(context, '昵称不能为空');
      return;
    }
    if (birthYear == null ||
        birthYear < 1940 ||
        birthYear > DateTime.now().year) {
      showAppSnackBar(context, '出生年份看起来不太对');
      return;
    }
    if (height == null || height < 100 || height > 230) {
      showAppSnackBar(context, '身高请填写 100–230 cm');
      return;
    }
    if (startKg == null || startKg < 20 || startKg > 300) {
      showAppSnackBar(context, '初始体重超出范围');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    await repository.updateProfile(
      profile.copyWith(
        nickname: nickname,
        gender: _gender,
        birthYear: birthYear,
        heightCm: height,
        activityLevel: _activity,
        startWeightKg: startKg,
      ),
    );
    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('个人资料已更新')));
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppRepository>().profile;
    return Scaffold(
      appBar: AppBar(title: const Text('个人资料')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          TextField(
            controller: _nickname,
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
          DropdownButtonFormField<String>(
            initialValue: _activity,
            items: [
              for (final activity in _activities)
                DropdownMenuItem(
                  value: activity.$1,
                  child: Text('${activity.$2} · ${activity.$3}'),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _activity = value);
            },
            decoration: const InputDecoration(
              labelText: '活动量',
              prefixIcon: Icon(Icons.directions_walk_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _startWeight,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: '初始体重',
              suffixText: weightUnitLabel(profile.weightUnit),
              prefixIcon: const Icon(Icons.flag_outlined),
              helperText: '用于计算「累计变化」，不影响每日体重记录',
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
          const SizedBox(height: 12),
          Text(
            '修改身高、体重或活动量后，每日热量预算会自动重新计算。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
