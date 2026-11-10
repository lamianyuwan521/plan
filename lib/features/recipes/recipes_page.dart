import 'package:flutter/material.dart';

import '../../core/fold_layout.dart';
import '../../core/widgets.dart';
import 'calendar_view.dart';
import 'plan_view.dart';
import 'recipe_edit_page.dart';
import 'recipe_library_view.dart';

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});

  static final ValueNotifier<int?> tabRequest = ValueNotifier<int?>(null);

  static void openPlans() {
    tabRequest.value = null;
    tabRequest.value = 2;
  }

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    RecipesPage.tabRequest.addListener(_applyRequestedTab);
  }

  @override
  void dispose() {
    RecipesPage.tabRequest.removeListener(_applyRequestedTab);
    super.dispose();
  }

  void _applyRequestedTab() {
    final value = RecipesPage.tabRequest.value;
    if (value == null || !mounted) return;
    setState(() => _tab = value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DuoBlock(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: PageHeader(
            title: '食谱',
            subtitle: switch (_tab) {
              0 => '在日历里查看每天的体重、三餐和喝水',
              1 => '按餐次查找和收藏每一道食谱',
              _ => '长期食谱和本周安排',
            },
            actions: [
              if (_tab == 0 || _tab == 1)
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
        ),
        const SizedBox(height: 12),
        DuoBlock(
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SegmentedTabs(
            value: _tab,
            labels: const ['日历', '食谱库', '计划'],
            onChanged: (value) => setState(() => _tab = value),
          ),
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
