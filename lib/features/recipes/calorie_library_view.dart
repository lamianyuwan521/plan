import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets.dart';
import '../../data/food_catalog.dart';
import '../../models/basket.dart';

/// 按分类挑选常见食物，或从菜篮子里选一份，算出热量后记一笔。
class CalorieLibraryView extends StatefulWidget {
  const CalorieLibraryView({
    super.key,
    required this.basket,
    required this.onAdd,
    this.saving = false,
  });

  final List<BasketItem> basket;
  final void Function(String name, int calories) onAdd;
  final bool saving;

  @override
  State<CalorieLibraryView> createState() => _CalorieLibraryViewState();
}

class _CalorieLibraryViewState extends State<CalorieLibraryView> {
  final _search = TextEditingController();
  final _amount = TextEditingController(text: '100');
  String _category = foodCategories.first.id;
  FoodRef? _food;
  BasketItem? _basketItem;

  @override
  void initState() {
    super.initState();
    if (widget.basket.isNotEmpty) _category = basketCategoryId;
  }

  @override
  void dispose() {
    _search.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _selectFood(FoodRef food) {
    setState(() {
      _food = food;
      _basketItem = null;
      _amount.text = food.per100 ? '100' : '1';
    });
  }

  void _selectBasket(BasketItem item) {
    final per100 = kcalIsPer100(item.unit);
    final fallback = per100 ? 100.0 : 1.0;
    final amount = item.amount < fallback ? item.amount : fallback;
    setState(() {
      _basketItem = item;
      _food = null;
      _amount.text = formatAmount(amount);
    });
  }

  int? _calories() {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) return null;
    final food = _food;
    if (food != null) return food.caloriesFor(amount);
    final item = _basketItem;
    if (item == null || item.kcal == null || item.kcal! <= 0) return null;
    if (kcalIsPer100(item.unit)) return (amount / 100 * item.kcal!).round();
    return (amount * item.kcal!).round();
  }

  String? get _selectedName => _food?.name ?? _basketItem?.name;

  String get _unit => _food?.unit ?? _basketItem?.unit ?? 'g';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _search.text.trim();
    final foods = query.isEmpty
        ? foodCatalog.where((food) => food.categoryId == _category).toList()
        : foodCatalog
              .where(
                (food) =>
                    food.name.contains(query) ||
                    foodCategoryName(food.categoryId).contains(query),
              )
              .toList();
    final basketItems = query.isEmpty
        ? (_category == basketCategoryId ? widget.basket : const <BasketItem>[])
        : widget.basket.where((item) => item.name.contains(query)).toList();
    final calories = _calories();
    final selectedName = _selectedName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: '搜索食物、分类或菜篮子',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('菜篮子'),
                  selected: _category == basketCategoryId && query.isEmpty,
                  onSelected: (_) => setState(() {
                    _category = basketCategoryId;
                    _search.clear();
                  }),
                ),
              ),
              for (final category in foodCategories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category.name),
                    selected: _category == category.id && query.isEmpty,
                    onSelected: (_) => setState(() {
                      _category = category.id;
                      _search.clear();
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: foods.isEmpty && basketItems.isEmpty
              ? EmptyState(
                  icon: Icons.kitchen_outlined,
                  title: _category == basketCategoryId && query.isEmpty
                      ? '菜篮子还是空的'
                      : '没有找到食物',
                  message: _category == basketCategoryId && query.isEmpty
                      ? '先到食谱页的「菜篮子」记下家里的食材。'
                      : '换个分类，或直接搜索名称。',
                )
              : ListView(
                  children: [
                    for (final item in basketItems)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        selected: _basketItem?.id == item.id,
                        title: Text(item.name),
                        subtitle: Text(
                          '${foodCategoryName(item.categoryId)} · ${item.amountLabel}'
                          '${item.estimatedKcal > 0 ? ' · 约 ${item.estimatedKcal} kcal' : ' · 未填热量'}',
                        ),
                        onTap: () => _selectBasket(item),
                      ),
                    for (final food in foods)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        selected: _food?.name == food.name,
                        title: Text(food.name),
                        subtitle: Text(
                          '${foodCategoryName(food.categoryId)} · ${food.kcalLabel}',
                        ),
                        onTap: () => _selectFood(food),
                      ),
                  ],
                ),
        ),
        if (selectedName != null) ...[
          const Divider(height: 1),
          const SizedBox(height: 8),
          Text(selectedName, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
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
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '份量',
                    suffixText: _unit,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: widget.saving || calories == null || calories <= 0
                    ? null
                    : () => widget.onAdd(selectedName, calories),
                child: Text(calories == null ? '填份量' : '记 $calories kcal'),
              ),
            ],
          ),
          if (_basketItem != null &&
              (_basketItem!.kcal == null || _basketItem!.kcal! <= 0))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '这份食材还没有热量，先在菜篮子里补上。',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
