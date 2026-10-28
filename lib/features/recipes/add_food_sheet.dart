import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/models.dart';

Future<void> showAddFoodSheet(
  BuildContext context, {
  required String date,
  required String initialMeal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddFoodSheet(date: date, initialMeal: initialMeal),
  );
}

class AddFoodSheet extends StatefulWidget {
  const AddFoodSheet({
    super.key,
    required this.date,
    required this.initialMeal,
  });

  final String date;
  final String initialMeal;

  @override
  State<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<AddFoodSheet> {
  late String _mealType;
  late bool _markEaten;
  int _mode = 0;
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _calories = TextEditingController();
  bool _saving = false;

  bool get _isFuture => AppDate.parse(widget.date).isAfter(AppDate.today());

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMeal;
    _markEaten = AppDate.parse(widget.date).isBefore(AppDate.today());
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _calories.dispose();
    super.dispose();
  }

  Future<void> _addRecipe(Recipe recipe) async {
    if (_saving) return;
    final repository = context.read<AppRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final eaten = _markEaten && !_isFuture;
    setState(() => _saving = true);
    await repository.addMealEntry(
      MealEntry(
        id: repository.newId(),
        date: widget.date,
        mealType: _mealType,
        recipeId: recipe.id,
        name: recipe.name,
        calories: recipe.calories,
        status: eaten ? 'completed' : 'planned',
        completedAt: eaten ? DateTime.now() : null,
        sortOrder: repository
            .entriesFor(widget.date, mealType: _mealType)
            .length,
      ),
    );
    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '已添加到${mealLabel(_mealType)}：${recipe.name}'
            '${eaten ? '（已吃）' : ''}',
          ),
        ),
      );
  }

  Future<void> _addQuickLog() async {
    if (_saving) return;
    final name = _name.text.trim();
    final calories = int.tryParse(_calories.text.trim());
    if (name.isEmpty) {
      showAppSnackBar(context, '给这顿饭起个名字吧');
      return;
    }
    if (calories == null || calories < 0 || calories > 3000) {
      showAppSnackBar(context, '热量请填写 0–3000 kcal');
      return;
    }
    final repository = context.read<AppRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final eaten = _markEaten && !_isFuture;
    setState(() => _saving = true);
    await repository.addMealEntry(
      MealEntry(
        id: repository.newId(),
        date: widget.date,
        mealType: _mealType,
        name: name,
        calories: calories,
        status: eaten ? 'completed' : 'planned',
        completedAt: eaten ? DateTime.now() : null,
        sortOrder: repository
            .entriesFor(widget.date, mealType: _mealType)
            .length,
      ),
    );
    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '已添加到${mealLabel(_mealType)}：$name'
            '${eaten ? '（已吃）' : ''}',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repository = context.watch<AppRepository>();
    final query = _search.text.trim();
    final recipes = repository.recipes.where((recipe) {
      if (query.isEmpty) return true;
      return recipe.name.contains(query) ||
          recipe.tags.any((tag) => tag.contains(query));
    }).toList()
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.84,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '添加饮食',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppDate.dateLabel(AppDate.parse(widget.date)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final type in allMealTypes)
                  ChoiceChip(
                    label: Text(mealLabel(type)),
                    selected: _mealType == type,
                    onSelected: (_) => setState(() => _mealType = type),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                _isFuture ? '未来日期不能提前打卡' : '已吃过',
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                _isFuture
                    ? '可以先安排进计划，到那天再打勾。'
                    : '打开后直接计入今天的已吃热量。',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: _markEaten && !_isFuture,
              onChanged: _isFuture
                  ? null
                  : (value) => setState(() => _markEaten = value),
            ),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.menu_book_outlined, size: 18),
                  label: Text('食谱库'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.edit_note_outlined, size: 18),
                  label: Text('快速记录'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) =>
                  setState(() => _mode = value.first),
            ),
            const SizedBox(height: 12),
            if (_mode == 0) ...[
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '搜索食谱或标签',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: recipes.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: '没有找到相关食谱',
                        message: '换个关键词，或切到「快速记录」直接记一笔。',
                      )
                    : ListView.separated(
                        itemCount: recipes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final recipe = recipes[index];
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            title: Text(
                              recipe.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${mealLabel(recipe.mealType)} · '
                              '${recipe.calories} kcal'
                              '${recipe.tags.isEmpty ? '' : ' · ${recipe.tags.join(' / ')}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: theme
                                  .colorScheme.primaryContainer
                                  .withValues(alpha: 0.6),
                              child: Icon(
                                _mealIcon(recipe.mealType),
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            trailing: recipe.isFavorite
                                ? const Icon(Icons.star,
                                    size: 18, color: Color(0xFFF2A65A))
                                : const Icon(Icons.add_circle_outline, size: 20),
                            onTap: _saving ? null : () => _addRecipe(recipe),
                          );
                        },
                      ),
              ),
            ] else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '吃了什么',
                          hintText: '例如：楼下便利店的饭团',
                          prefixIcon: Icon(Icons.restaurant_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _calories,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: const InputDecoration(
                          labelText: '热量',
                          suffixText: 'kcal',
                          hintText: '估算即可',
                          prefixIcon: Icon(Icons.local_fire_department_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '不用纠结精确数字，按包装或外卖页面的热量填就好。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _addQuickLog,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _markEaten && !_isFuture
                                    ? '记为已吃'
                                    : '加入计划',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _mealIcon(String mealType) {
    return switch (mealType) {
      'breakfast' => Icons.free_breakfast_outlined,
      'lunch' => Icons.lunch_dining_outlined,
      'dinner' => Icons.dinner_dining_outlined,
      'snack' => Icons.cookie_outlined,
      _ => Icons.restaurant_outlined,
    };
  }
}
