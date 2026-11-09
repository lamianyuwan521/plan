import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../data/food_catalog.dart';
import '../../models/basket.dart';
import '../../services/basket_planner.dart';
import 'basket_plan_page.dart';

class BasketView extends StatefulWidget {
  const BasketView({super.key, this.onOpenPlans});

  final VoidCallback? onOpenPlans;

  @override
  State<BasketView> createState() => _BasketViewState();
}

class _BasketViewState extends State<BasketView> {
  final _cap = TextEditingController();
  var _capReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_capReady) return;
    _cap.text = '${context.read<AppRepository>().dailyBudget}';
    _capReady = true;
  }

  @override
  void dispose() {
    _cap.dispose();
    super.dispose();
  }

  int? _readCap() {
    final value = int.tryParse(_cap.text.trim());
    if (value == null || value < 500 || value > 4000) return null;
    return value;
  }

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
    final cap = _readCap();
    if (cap == null) {
      showAppSnackBar(context, '一天的热量请填 500–4000 kcal');
      return;
    }
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => BasketPlanPage(calorieCap: cap)),
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
    final cap = _readCap() ?? repository.dailyBudget;
    final preview = items.isEmpty ? null : buildLocalBasketPlan(items, cap);
    final totalKcal = items.fold<int>(
      0,
      (sum, item) => sum + item.estimatedKcal,
    );
    final groups = <String, List<BasketItem>>{};
    for (final item in items) {
      groups.putIfAbsent(item.categoryId, () => []).add(item);
    }

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
                    ? '把家里的菜、水果、肉和主食记下来，再按余量生成食谱。'
                    : preview == null
                    ? ''
                    : preview.supportedDays <= 0
                    ? '按每天 $cap kcal，这些食材还凑不齐完整的一天。'
                    : '按每天不超过 $cap kcal，大约能安排 ${preview.supportedDays} 天。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cap,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: '每天热量不超过',
                        suffixText: 'kcal',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: items.isEmpty ? null : () => _generate(items),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('生成食谱'),
                  ),
                ],
              ),
              if (cap < 1000) ...[
                const SizedBox(height: 8),
                Text(
                  '低于 1000 kcal 只适合短时间，不适合长期执行。',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
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
            message: '记下鸡蛋、蔬菜、水果这些余量，生成食谱时会按还剩多少来排天数。',
          )
        else
          for (final entry in groups.entries) ...[
            const SizedBox(height: 8),
            Text(
              foodCategoryName(entry.key),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (final item in entry.value) ...[
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
    final knownCategory =
        category == 'other' ||
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
