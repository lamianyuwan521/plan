import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/models.dart';
import 'recipe_detail_page.dart';
import 'recipe_edit_page.dart';

class RecipeLibraryView extends StatefulWidget {
  const RecipeLibraryView({super.key});

  @override
  State<RecipeLibraryView> createState() => _RecipeLibraryViewState();
}

class _RecipeLibraryViewState extends State<RecipeLibraryView> {
  final _search = TextEditingController();
  String _mealFilter = 'all';
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final query = _search.text.trim();
    final recipes = repository.recipes.where((recipe) {
      if (_favoritesOnly && !recipe.isFavorite) return false;
      if (_mealFilter != 'all' &&
          recipe.mealType != _mealFilter &&
          recipe.mealType != 'any') {
        return false;
      }
      if (query.isEmpty) return true;
      return recipe.name.contains(query) ||
          recipe.tags.any((tag) => tag.contains(query));
    }).toList()
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        final orderA = _mealOrder(a.mealType);
        final orderB = _mealOrder(b.mealType);
        if (orderA != orderB) return orderA.compareTo(orderB);
        return a.name.compareTo(b.name);
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '搜索食谱或标签',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除',
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _FilterChip(
                label: '全部',
                selected: _mealFilter == 'all',
                onTap: () => setState(() => _mealFilter = 'all'),
              ),
              for (final type in allMealTypes) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: mealLabel(type),
                  selected: _mealFilter == type,
                  onTap: () => setState(() => _mealFilter = type),
                ),
              ],
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('只看收藏'),
                selected: _favoritesOnly,
                onSelected: (value) =>
                    setState(() => _favoritesOnly = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: recipes.isEmpty
              ? EmptyState(
                  icon: Icons.search_off,
                  title: repository.recipes.isEmpty
                      ? '还没有食谱'
                      : '没有找到相关食谱',
                  message: repository.recipes.isEmpty
                      ? '添加第一道自己的食谱，或从内置食谱开始。'
                      : '换个关键词，或清除筛选再看看。',
                  actionLabel: '添加食谱',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RecipeEditPage(),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 760) {
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 420,
                          mainAxisExtent: 150,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: recipes.length,
                        itemBuilder: (context, index) => _RecipeGridCard(
                          recipe: recipes[index],
                          onTap: () => _openDetail(recipes[index]),
                          onFavorite: () =>
                              repository.toggleFavorite(recipes[index].id),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: recipes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _RecipeListCard(
                        recipe: recipes[index],
                        onTap: () => _openDetail(recipes[index]),
                        onFavorite: () =>
                            repository.toggleFavorite(recipes[index].id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  int _mealOrder(String mealType) {
    return switch (mealType) {
      'breakfast' => 0,
      'lunch' => 1,
      'dinner' => 2,
      'snack' => 3,
      _ => 4,
    };
  }

  void _openDetail(Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailPage(recipeId: recipe.id),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _RecipeGridCard extends StatelessWidget {
  const _RecipeGridCard({
    required this.recipe,
    required this.onTap,
    required this.onFavorite,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  recipe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
              IconButton(
                onPressed: onFavorite,
                visualDensity: VisualDensity.compact,
                tooltip: recipe.isFavorite ? '取消收藏' : '收藏',
                icon: Icon(
                  recipe.isFavorite ? Icons.star : Icons.star_border,
                  size: 19,
                  color: recipe.isFavorite
                      ? AppColors.peach
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                '${recipe.calories} kcal',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              TagChip(label: mealLabel(recipe.mealType)),
              const Spacer(),
              if (recipe.isBuiltin) const TagChip(label: '内置'),
            ],
          ),
          const Spacer(),
          if (recipe.tags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in recipe.tags.take(3)) TagChip(label: tag),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecipeListCard extends StatelessWidget {
  const _RecipeListCard({
    required this.recipe,
    required this.onTap,
    required this.onFavorite,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor:
                theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
            child: Icon(
              _mealIcon(recipe.mealType),
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        recipe.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (recipe.isBuiltin) const TagChip(label: '内置'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${mealLabel(recipe.mealType)} · ${recipe.calories} kcal'
                  '${recipe.tags.isEmpty ? '' : ' · ${recipe.tags.join(' / ')}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onFavorite,
            tooltip: recipe.isFavorite ? '取消收藏' : '收藏',
            icon: Icon(
              recipe.isFavorite ? Icons.star : Icons.star_border,
              size: 20,
              color: recipe.isFavorite
                  ? AppColors.peach
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
