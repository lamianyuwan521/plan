import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../data/food_catalog.dart';
import '../../models/basket.dart';
import 'basket_plan_page.dart';

class BasketView extends StatefulWidget {
  const BasketView({super.key, this.onOpenPlans});

  final VoidCallback? onOpenPlans;

  @override
  State<BasketView> createState() => _BasketViewState();
}

class _BasketViewState extends State<BasketView> {
  Future<void> _openEditor({BasketItem? item}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BasketEditor(initial: item),
    );
  }

  Future<void> _delete(BasketItem item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '从菜篮子拿走「${item.name}」？',
      message: '只删除这份余量记录，已经生成的食谱不会变。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<AppRepository>().deleteBasketItem(item.id);
  }

  Future<void> _generate(List<BasketItem> items) async {
    if (items.isEmpty) {
      showAppSnackBar(context, '先记下家里有的食材');
      return;
    }
    final request = await showDialog<_PlanRequest>(
      context: context,
      builder: (_) => _GenerateDialog(
        initialCalories: context.read<AppRepository>().dailyBudget,
      ),
    );
    if (request == null || !mounted) return;
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BasketPlanPage(
          calorieCap: request.calories,
          dayCount: request.days,
          note: request.note,
        ),
      ),
    );
    if (added != true || !mounted) return;
    showAppSnackBar(
      context,
      '已加入长期计划',
      actionLabel: widget.onOpenPlans == null ? null : '查看',
      onAction: widget.onOpenPlans,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final theme = Theme.of(context);
    final items = repository.basketItems;
    final totalKcal = items.fold<int>(
      0,
      (sum, item) => sum + item.estimatedKcal,
    );
    final groups = <String, List<BasketItem>>{};
    for (final item in items) {
      groups.putIfAbsent(item.categoryId, () => []).add(item);
    }
    final categoryIds = groups.keys.toList()
      ..sort((a, b) => foodCategoryOrder(a).compareTo(foodCategoryOrder(b)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                items.isEmpty ? '还没有记下食材' : '大约 $totalKcal kcal',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                items.isEmpty
                    ? '按主食、蔬菜、水果、调料这些分类把家里的食材记下来，再生成食谱。'
                    : '可以按主食、蔬菜、水果、调料来整理。生成时填写每天热量和天数，不写备注也会按营养均衡来排。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: items.isEmpty ? null : () => _generate(items),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('生成食谱'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '家里有的',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加食材'),
            ),
          ],
        ),
        if (items.isEmpty)
          const EmptyState(
            icon: Icons.shopping_basket_outlined,
            title: '菜篮子是空的',
            message: '记下鸡蛋、蔬菜、水果、调料和主食。生成时可以填每天热量、天数，也可以写一句要求。',
          )
        else
          for (final categoryId in categoryIds) ...[
            const SizedBox(height: 8),
            Text(
              foodCategoryName(categoryId),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (final item in groups[categoryId]!) ...[
              SectionCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.amountLabel}'
                            '${item.estimatedKcal > 0 ? ' · 约 ${item.estimatedKcal} kcal' : ' · 还没填热量'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '编辑',
                      onPressed: () => _openEditor(item: item),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip: '删除',
                      onPressed: () => _delete(item),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
      ],
    );
  }
}

class _BasketEditor extends StatefulWidget {
  const _BasketEditor({this.initial});

  final BasketItem? initial;

  @override
  State<_BasketEditor> createState() => _BasketEditorState();
}

class _BasketEditorState extends State<_BasketEditor> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _kcal;
  late String _category;
  late String _unit;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final category = initial?.categoryId;
    final knownCategory = category == 'other' ||
        foodCategories.any((item) => item.id == category);
    _name = TextEditingController(text: initial?.name ?? '');
    _amount = TextEditingController(
      text: initial == null ? '' : formatAmount(initial.amount),
    );
    _kcal = TextEditingController(
      text: initial?.kcal == null ? '' : '${initial!.kcal}',
    );
    _category = knownCategory ? category! : 'vegetable';
    _unit = basketUnits.contains(initial?.unit) ? initial!.unit : 'g';
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _kcal.dispose();
    super.dispose();
  }

  void _applyFood(FoodRef food) {
    setState(() {
      _name.text = food.name;
      _category = food.categoryId;
      _unit = food.unit;
      _kcal.text = '${food.kcal}';
      if (_amount.text.trim().isEmpty) {
        _amount.text = food.per100 ? '100' : '1';
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final amount = double.tryParse(_amount.text.trim());
    final kcalText = _kcal.text.trim();
    final kcal = kcalText.isEmpty ? null : int.tryParse(kcalText);
    if (name.isEmpty || name.length > 20) {
      showAppSnackBar(context, '食材名称请填 1–20 个字');
      return;
    }
    if (amount == null || amount <= 0 || amount > 100000) {
      showAppSnackBar(context, '余量请填一个大于 0 的数');
      return;
    }
    if (kcalText.isNotEmpty && (kcal == null || kcal < 0 || kcal > 2000)) {
      showAppSnackBar(context, '热量请填 0–2000，或留空');
      return;
    }
    final repository = context.read<AppRepository>();
    final navigator = Navigator.of(context);
    final initial = widget.initial;
    final item = BasketItem(
      id: initial?.id ?? repository.newId(),
      name: name,
      categoryId: _category,
      amount: amount,
      unit: _unit,
      kcal: kcal,
    );
    setState(() => _saving = true);
    if (initial == null) {
      await repository.addBasketItem(item);
    } else {
      await repository.updateBasketItem(item);
    }
    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = foodSuggestions(_name.text);
    final per100 = kcalIsPer100(_unit);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null ? '添加食材' : '编辑食材',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例如：鸡蛋、苹果、鸡胸肉',
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final food in suggestions)
                    ActionChip(
                      label: Text(food.name),
                      onPressed: () => _applyFood(food),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: '分类'),
              items: [
                for (final category in foodCategories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
                const DropdownMenuItem(value: 'other', child: Text('其他')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _category = value);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    decoration: const InputDecoration(labelText: '余量'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: '单位'),
                    items: [
                      for (final unit in basketUnits)
                        DropdownMenuItem(value: unit, child: Text(unit)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _unit = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kcal,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                labelText: per100 ? '每 100$_unit 热量' : '每 1$_unit 热量',
                suffixText: 'kcal',
                hintText: '可以留空，但留空不会参与排天数',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(widget.initial == null ? '放入菜篮子' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanRequest {
  const _PlanRequest({
    required this.calories,
    required this.days,
    required this.note,
  });

  final int calories;
  final int days;
  final String note;
}

class _GenerateDialog extends StatefulWidget {
  const _GenerateDialog({required this.initialCalories});

  final int initialCalories;

  @override
  State<_GenerateDialog> createState() => _GenerateDialogState();
}

class _GenerateDialogState extends State<_GenerateDialog> {
  late final TextEditingController _calories;
  late final TextEditingController _days;
  late final TextEditingController _note;
  String? _error;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialCalories.clamp(500, 4000);
    _calories = TextEditingController(text: '$seed');
    _days = TextEditingController(text: '3');
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _calories.dispose();
    _days.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final calories = int.tryParse(_calories.text.trim());
    final days = int.tryParse(_days.text.trim());
    if (calories == null || calories < 500 || calories > 4000) {
      setState(() => _error = '每日热量请填 500–4000 kcal');
      return;
    }
    if (days == null || days < 1 || days > 14) {
      setState(() => _error = '天数请填 1–14');
      return;
    }
    final note = _note.text.trim();
    if (note.length > 200) {
      setState(() => _error = '备注请控制在 200 字以内');
      return;
    }
    Navigator.of(context).pop(
      _PlanRequest(calories: calories, days: days, note: note),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AlertDialog(
      title: const Text('生成食谱'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _calories,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                labelText: '每日热量',
                suffixText: 'kcal',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _days,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              decoration: const InputDecoration(
                labelText: '生成几天',
                suffixText: '天',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: '其他要求',
                hintText: '例如：少油、不吃牛肉、午餐要能带饭。可以留空',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '不填备注时，会按菜篮子自动生成营养均衡的食谱。每天热量与目标相差不超过 100 kcal，每一餐都会写做法、用量、生重和热量。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (bottom > 0) SizedBox(height: bottom),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('生成')),
      ],
    );
  }
}
