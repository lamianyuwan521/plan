import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/models.dart';

/// 新建或编辑长期食谱方案。
///
/// 传入 [initialPlan] 表示从已有方案开始：默认编辑该自定义方案；
/// [saveAsCopy] 为 true 时（内置方案「复制并编辑」）保存会新建一份自定义方案。
class PlanEditPage extends StatefulWidget {
  const PlanEditPage({super.key, this.initialPlan, this.saveAsCopy = false});

  final DietPlan? initialPlan;
  final bool saveAsCopy;

  @override
  State<PlanEditPage> createState() => _PlanEditPageState();
}

class _PlanEditPageState extends State<PlanEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _tags;
  late final List<_DayDraft> _days;
  bool _saving = false;

  bool get _isEditing =>
      widget.initialPlan != null &&
      widget.initialPlan!.isCustom &&
      !widget.saveAsCopy;

  @override
  void initState() {
    super.initState();
    final plan = widget.initialPlan;
    _name = TextEditingController(text: plan?.name ?? '');
    _description = TextEditingController(text: plan?.description ?? '');
    _tags = TextEditingController(text: plan?.tags.join('，') ?? '');
    _days = plan == null || plan.days.isEmpty
        ? [_DayDraft.empty()]
        : plan.days.map(_DayDraft.fromPlanDay).toList();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _tags.dispose();
    for (final day in _days) {
      day.dispose();
    }
    super.dispose();
  }

  Future<void> _addDay() async {
    setState(() => _days.add(_DayDraft.empty()));
  }

  void _duplicateDay(int index) {
    setState(() => _days.insert(index + 1, _days[index].copy()));
  }

  Future<void> _deleteDay(int index) async {
    if (_days.length <= 1) {
      showAppSnackBar(context, '至少保留一天，可以直接清空这一天的内容。');
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: '删除第 ${index + 1} 天？',
      message: '这一天的三餐安排会被移除，其他天不受影响。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _days.removeAt(index).dispose());
  }

  Future<void> _editDay(int index) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DayEditSheet(draft: _days[index], index: index),
    );
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(context, '先给这套长期食谱起个名字吧。');
      return;
    }
    final days = _days.map((day) => day.toPlanDay()).toList(growable: false);
    final mealTotal = days.fold<int>(0, (sum, day) => sum + day.meals.length);
    if (mealTotal == 0) {
      showAppSnackBar(context, '至少给一天安排一餐，保存后才方便铺进日历。');
      return;
    }
    final tags = _tags.text
        .split(RegExp(r'[,，、;；\s]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);

    final repository = context.read<AppRepository>();
    final navigator = Navigator.of(context);
    final plan = DietPlan(
      id: _isEditing ? widget.initialPlan!.id : repository.newId(),
      name: name,
      description: _description.text.trim(),
      tags: tags,
      days: days,
      isCustom: true,
    );

    setState(() => _saving = true);
    if (_isEditing) {
      await repository.updateDietPlan(plan);
    } else {
      await repository.addDietPlan(plan);
    }
    if (!mounted) return;
    navigator.pop();
    showAppSnackBar(context, _isEditing ? '已保存「$name」' : '已创建「$name」');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isEditing
        ? '编辑长期食谱'
        : widget.saveAsCopy
        ? '复制为自定义方案'
        : '新建长期食谱';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (widget.saveAsCopy)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.content_copy_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '内置方案不会被修改。保存后会生成一份属于自己的副本，'
                        '名字和三餐都可以继续调整。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: '方案名称',
                    hintText: '例如：我的 14 天轻断食',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '简介（可选）',
                    hintText: '写一句这套方案的节奏或适合谁',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tags,
                  decoration: const InputDecoration(
                    labelText: '标签（可选）',
                    hintText: '用逗号分隔，例如：长期，控卡，7 天',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '每日安排',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '共 ${_days.length} 天，点某一天可以编辑三餐和参考体重。',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _addDay,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加一天'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < _days.length; index++) ...[
            _DayCard(
              index: index,
              draft: _days[index],
              onEdit: () => _editDay(index),
              onDuplicate: () => _duplicateDay(index),
              onDelete: () => _deleteDay(index),
            ),
            if (index < _days.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_isEditing ? '保存修改' : '创建长期食谱'),
          ),
          const SizedBox(height: 12),
          Text(
            '热量为估算值，只会用于计划统计。极低热量方案不适合长期执行，'
            '身体不适时请暂停并咨询医生。',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.index,
    required this.draft,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final int index;
  final _DayDraft draft;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = draft.preview;
    final weight = draft.weightValue;
    final meals = day.meals;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      onTap: onEdit,
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
              const SizedBox(width: 8),
              if (weight != null)
                TagChip(label: '${weight.toStringAsFixed(1)} 斤'),
              const Spacer(),
              Text(
                meals.isEmpty ? '未安排' : '${day.calories} kcal',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: meals.isEmpty
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '更多',
                icon: const Icon(Icons.more_vert, size: 18),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'copy') onDuplicate();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'copy', child: Text('复制这一天')),
                  PopupMenuItem(value: 'delete', child: Text('删除这一天')),
                ],
              ),
            ],
          ),
          if (draft.noteText.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              draft.noteText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 6),
          if (meals.isEmpty)
            Row(
              children: [
                Icon(
                  Icons.restaurant_outlined,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '还没有安排，点这里添加三餐',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            )
          else
            for (final type in mainMealTypes)
              if (day.mealOf(type) != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          mealLabel(type),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          day.mealOf(type)!.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${day.mealOf(type)!.calories} kcal',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

class _DayDraft {
  _DayDraft({
    required this.weight,
    required this.note,
    required this.mealName,
    required this.mealKcal,
  });

  factory _DayDraft.empty() {
    return _DayDraft(
      weight: TextEditingController(),
      note: TextEditingController(),
      mealName: {
        for (final type in mainMealTypes) type: TextEditingController(),
      },
      mealKcal: {
        for (final type in mainMealTypes) type: TextEditingController(),
      },
    );
  }

  factory _DayDraft.fromPlanDay(PlanDay day) {
    return _DayDraft(
      weight: TextEditingController(
        text: day.weightJin == null ? '' : day.weightJin!.toStringAsFixed(1),
      ),
      note: TextEditingController(text: day.note ?? ''),
      mealName: {
        for (final type in mainMealTypes)
          type: TextEditingController(text: day.mealOf(type)?.name ?? ''),
      },
      mealKcal: {
        for (final type in mainMealTypes)
          type: TextEditingController(
            text: day.mealOf(type) == null
                ? ''
                : '${day.mealOf(type)!.calories}',
          ),
      },
    );
  }

  final TextEditingController weight;
  final TextEditingController note;
  final Map<String, TextEditingController> mealName;
  final Map<String, TextEditingController> mealKcal;

  double? get weightValue {
    final value = double.tryParse(weight.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  String get noteText => note.text.trim();

  PlanDay get preview => toPlanDay();

  PlanDay toPlanDay() {
    final meals = <PlanMeal>[];
    for (final type in mainMealTypes) {
      final name = mealName[type]!.text.trim();
      if (name.isEmpty) continue;
      final kcal = int.tryParse(mealKcal[type]!.text.trim()) ?? 0;
      meals.add(PlanMeal(mealType: type, name: name, calories: kcal));
    }
    return PlanDay(
      meals: meals,
      weightJin: weightValue,
      note: noteText.isEmpty ? null : noteText,
    );
  }

  _DayDraft copy() {
    return _DayDraft(
      weight: TextEditingController(text: weight.text),
      note: TextEditingController(text: note.text),
      mealName: {
        for (final type in mainMealTypes)
          type: TextEditingController(text: mealName[type]!.text),
      },
      mealKcal: {
        for (final type in mainMealTypes)
          type: TextEditingController(text: mealKcal[type]!.text),
      },
    );
  }

  void dispose() {
    weight.dispose();
    note.dispose();
    for (final controller in mealName.values) {
      controller.dispose();
    }
    for (final controller in mealKcal.values) {
      controller.dispose();
    }
  }
}

class _DayEditSheet extends StatelessWidget {
  const _DayEditSheet({required this.draft, required this.index});

  final _DayDraft draft;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    '第 ${index + 1} 天',
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
              '只填有安排的餐次，留空的餐次不会写进方案。',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(labelText: '参考体重（斤，可选）'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.note,
              decoration: const InputDecoration(
                labelText: '当天备注（可选）',
                hintText: '例如：早午餐合并 / 外食',
              ),
            ),
            const SizedBox(height: 16),
            for (final type in mainMealTypes) ...[
              Text(
                mealLabel(type),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: draft.mealName[type],
                      decoration: InputDecoration(
                        hintText: '吃点什么',
                        labelText: '${mealLabel(type)}内容',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 112,
                    child: TextField(
                      controller: draft.mealKcal[type],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '热量',
                        suffixText: 'kcal',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }
}
