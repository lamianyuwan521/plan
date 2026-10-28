import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import 'calendar_view.dart';
import 'plan_view.dart';
import 'recipe_edit_page.dart';
import 'recipe_library_view.dart';

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: PageHeader(
            title: '食谱',
            subtitle: '在日历里查看每天的体重、三餐和喝水',
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RecipeEditPage(),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加食谱'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SegmentedTabs(
            value: _tab,
            labels: const ['日历', '食谱库', '计划'],
            onChanged: (value) => setState(() => _tab = value),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _RecipesBody(tab: _tab)),
      ],
    );
  }
}

class _RecipesBody extends StatelessWidget {
  const _RecipesBody({required this.tab});

  final int tab;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: tab,
      children: const [
        CalendarView(),
        RecipeLibraryView(),
        PlanView(),
      ],
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  final int value;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < labels.length - 1 ? 4 : 0,
                ),
                child: Material(
                  color: value == index ? scheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Center(
                        child: Text(
                          labels[index],
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: value == index
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: value == index
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
