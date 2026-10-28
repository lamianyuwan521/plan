import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/models.dart';
import 'recipe_edit_page.dart';

class RecipeDetailPage extends StatelessWidget {
  const RecipeDetailPage({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final recipe = repository.recipeById(recipeId);

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('食谱')),
        body: const EmptyState(
          icon: Icons.restaurant_outlined,
          title: '食谱已删除',
          message: '这条食谱不存在，可能已经在其他页面被删除。',
        ),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          recipe.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: recipe.isFavorite ? '取消收藏' : '收藏',
            onPressed: () => repository.toggleFavorite(recipe.id),
            icon: Icon(
              recipe.isFavorite ? Icons.star : Icons.star_border,
              color: recipe.isFavorite ? AppColors.peach : null,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RecipeEditPage(recipe: recipe),
                  ),
                );
              } else if (value == 'delete') {
                _delete(context, repository, recipe);
              } else if (value == 'copy') {
                _saveAsCopy(context, repository, recipe);
              }
            },
            itemBuilder: (context) => recipe.isBuiltin
                ? const [
                    PopupMenuItem(value: 'copy', child: Text('另存为我的食谱')),
                  ]
                : const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${recipe.calories}',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          'kcal / 份',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TagChip(label: mealLabel(recipe.mealType)),
                        if (recipe.isBuiltin) ...[
                          const SizedBox(height: 4),
                          const TagChip(label: '内置食谱'),
                        ],
                      ],
                    ),
                  ],
                ),
                if (recipe.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in recipe.tags) TagChip(label: tag),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  '${recipe.ingredients.length} 种食材 · ${recipe.steps.length} 个步骤',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (recipe.ingredients.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(icon: Icons.shopping_basket_outlined, title: '食材'),
                  const SizedBox(height: 10),
                  for (var index = 0; index < recipe.ingredients.length; index++) ...[
                    _IngredientRow(
                      ingredient: recipe.ingredients[index],
                    ),
                    if (index < recipe.ingredients.length - 1)
                      const Divider(height: 16),
                  ],
                ],
              ),
            ),
          ],
          if (recipe.steps.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(icon: Icons.soup_kitchen_outlined, title: '做法'),
                  const SizedBox(height: 10),
                  for (var index = 0; index < recipe.steps.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              recipe.steps[index],
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: () => _showAddToPlan(context, recipe),
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('加入计划'),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    AppRepository repository,
    Recipe recipe,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除「${recipe.name}」？',
      message: '已经安排到日历里的记录会保留名称和热量，但无法再查看详情。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await repository.deleteRecipe(recipe.id);
    if (!context.mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('已删除食谱'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => repository.addRecipe(recipe),
          ),
        ),
      );
  }

  Future<void> _saveAsCopy(
    BuildContext context,
    AppRepository repository,
    Recipe recipe,
  ) async {
    var name = '${recipe.name}（我的）';
    if (name.length > 30) {
      name = name.substring(0, 30);
    }
    final copy = Recipe(
      id: repository.newId(),
      name: name,
      mealType: recipe.mealType,
      calories: recipe.calories,
      ingredients: recipe.ingredients,
      steps: recipe.steps,
      tags: recipe.tags,
    );
    await repository.addRecipe(copy);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailPage(recipeId: copy.id),
      ),
    );
    showAppSnackBar(context, '已另存为我的食谱，可以自由修改了');
  }

  Future<void> _showAddToPlan(BuildContext context, Recipe recipe) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddToPlanSheet(recipe: recipe),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient});

  final Ingredient ingredient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = ingredient.amount == 0
        ? ''
        : (ingredient.amount % 1 == 0
            ? ingredient.amount.toInt().toString()
            : ingredient.amount.toStringAsFixed(1));
    return Row(
      children: [
        Expanded(
          child: Text(
            ingredient.name,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        if (amount.isNotEmpty)
          Text(
            '$amount ${ingredient.unit}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (ingredient.kcal != null) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text(
              '${ingredient.kcal} kcal',
              textAlign: TextAlign.right,
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

class _AddToPlanSheet extends StatefulWidget {
  const _AddToPlanSheet({required this.recipe});

  final Recipe recipe;

  @override
  State<_AddToPlanSheet> createState() => _AddToPlanSheetState();
}

class _AddToPlanSheetState extends State<_AddToPlanSheet> {
  late DateTime _date;
  late String _mealType;
  bool _eaten = false;
  bool _saving = false;

  bool get _isFuture => _date.isAfter(AppDate.today());

  @override
  void initState() {
    super.initState();
    _date = AppDate.today();
    _mealType = widget.recipe.mealType == 'any'
        ? _mealFromTime(DateTime.now().hour)
        : widget.recipe.mealType;
  }

  String _mealFromTime(int hour) {
    if (hour >= 5 && hour < 10) return 'breakfast';
    if (hour >= 10 && hour < 15) return 'lunch';
    if (hour >= 15 && hour < 17) return 'snack';
    if (hour >= 17 && hour < 22) return 'dinner';
    return 'snack';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '安排到哪一天',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() {
        _date = AppDate.dateOnly(picked);
        if (_eaten && _isFuture) _eaten = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final repository = context.read<AppRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final dateKey = AppDate.key(_date);
    final eaten = _eaten && !_isFuture;
    setState(() => _saving = true);
    await repository.addMealEntry(
      MealEntry(
        id: repository.newId(),
        date: dateKey,
        mealType: _mealType,
        recipeId: widget.recipe.id,
        name: widget.recipe.name,
        calories: widget.recipe.calories,
        status: eaten ? 'completed' : 'planned',
        completedAt: eaten ? DateTime.now() : null,
        sortOrder:
            repository.entriesFor(dateKey, mealType: _mealType).length,
      ),
    );
    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '已加入 ${AppDate.dateLabel(_date)} ${mealLabel(_mealType)}',
          ),
        ),
      );
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
              Expanded(
                child: Text(
                  '加入计划',
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
            '${widget.recipe.name} · ${widget.recipe.calories} kcal',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(AppDate.dateLabel(_date)),
          ),
          const SizedBox(height: 14),
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
            title: Text(_isFuture ? '未来日期不能提前打卡' : '已经吃过'),
            subtitle: Text(
              _isFuture ? '先加入计划，到当天再打勾。' : '打开后直接计入已吃热量。',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            value: _eaten && !_isFuture,
            onChanged: _isFuture
                ? null
                : (value) => setState(() => _eaten = value),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _eaten && !_isFuture
                        ? '记为${mealLabel(_mealType)}已吃'
                        : '加入${mealLabel(_mealType)}计划',
                  ),
          ),
        ],
      ),
    );
  }
}
