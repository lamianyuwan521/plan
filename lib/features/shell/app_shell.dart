import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../ai/ai_page.dart';
import '../recipes/recipes_page.dart';
import '../settings/settings_page.dart';
import '../today/today_page.dart';
import '../water/water_page.dart';
import '../weight/weight_page.dart';

enum ShellSection { today, recipes, weight, water, ai }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late ShellSection _section;
  bool? _expandedOverride;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppRepository>().profile;
    _section = profile.startPage == 'recipes'
        ? ShellSection.recipes
        : ShellSection.today;
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  void _select(ShellSection section) {
    setState(() => _section = section);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  void _toggleSidebar(bool current) {
    final repository = context.read<AppRepository>();
    setState(() => _expandedOverride = !current);
    repository.updateProfile(
      repository.profile.copyWith(sidebarExpanded: !current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isWide = constraints.maxWidth >= 1024;
        final expanded = _expandedOverride ??
            (isWide ? repository.profile.sidebarExpanded : false);

        final pages = <Widget>[
          TodayPage(
            onOpenRecipes: () => _select(ShellSection.recipes),
            onOpenWater: () => _select(ShellSection.water),
          ),
          const RecipesPage(),
          const WeightPage(),
          const WaterPage(),
          const AiPage(),
        ];
        final content = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: IndexedStack(index: _section.index, children: pages),
          ),
        );

        if (isMobile) {
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MascotAvatar(size: 28),
                  SizedBox(width: 8),
                  Text('小一二减肥记'),
                ],
              ),
            ),
            drawer: Drawer(
              width: 286,
              child: SafeArea(
                child: AppSidebar(
                  expanded: true,
                  showToggle: false,
                  selected: _section,
                  onSelect: _select,
                  onToggle: () {},
                  onSettings: () {
                    _scaffoldKey.currentState?.closeDrawer();
                    _openSettings();
                  },
                ),
              ),
            ),
            body: content,
          );
        }

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: expanded ? 240 : 76,
                  child: ClipRect(
                    child: AppSidebar(
                      expanded: expanded,
                      selected: _section,
                      onSelect: _select,
                      onToggle: () => _toggleSidebar(expanded),
                      onSettings: _openSettings,
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            ),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 76,
                    child: AppSidebar(
                      expanded: false,
                      selected: _section,
                      onSelect: _select,
                      onToggle: () => setState(() => _expandedOverride = true),
                      onSettings: _openSettings,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              ),
              if (expanded) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _expandedOverride = false),
                    child: Container(color: Colors.black.withValues(alpha: 0.28)),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 240,
                  child: Material(
                    elevation: 12,
                    color: Theme.of(context).colorScheme.surface,
                    child: SafeArea(
                      child: AppSidebar(
                        expanded: true,
                        selected: _section,
                        onSelect: (section) {
                          _select(section);
                          setState(() => _expandedOverride = false);
                        },
                        onToggle: () =>
                            setState(() => _expandedOverride = false),
                        onSettings: () {
                          setState(() => _expandedOverride = false);
                          _openSettings();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.expanded,
    required this.selected,
    required this.onSelect,
    required this.onToggle,
    required this.onSettings,
    this.showToggle = true,
  });

  final bool expanded;
  final ShellSection selected;
  final ValueChanged<ShellSection> onSelect;
  final VoidCallback onToggle;
  final VoidCallback onSettings;
  final bool showToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment:
            expanded ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
        children: [
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 8, 12),
              child: Row(
                children: [
                  const MascotAvatar(size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '小一二减肥记',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '减重日记',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showToggle)
                    IconButton(
                      tooltip: '收起侧栏',
                      onPressed: onToggle,
                      icon: const Icon(Icons.chevron_left, size: 20),
                    ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Column(
                children: [
                  const MascotAvatar(size: 36),
                  IconButton(
                    tooltip: '展开侧栏',
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggle,
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          _SidebarItem(
            icon: Icons.wb_sunny_outlined,
            label: '今日',
            expanded: expanded,
            selected: selected == ShellSection.today,
            onTap: () => onSelect(ShellSection.today),
          ),
          _SidebarItem(
            icon: Icons.restaurant_outlined,
            label: '食谱',
            expanded: expanded,
            selected: selected == ShellSection.recipes,
            onTap: () => onSelect(ShellSection.recipes),
          ),
          _SidebarItem(
            icon: Icons.monitor_weight_outlined,
            label: '体重',
            expanded: expanded,
            selected: selected == ShellSection.weight,
            onTap: () => onSelect(ShellSection.weight),
          ),
          _SidebarItem(
            icon: Icons.water_drop_outlined,
            label: '喝水',
            expanded: expanded,
            selected: selected == ShellSection.water,
            onTap: () => onSelect(ShellSection.water),
          ),
          _SidebarItem(
            icon: Icons.auto_awesome_outlined,
            label: 'AI 助手',
            expanded: expanded,
            selected: selected == ShellSection.ai,
            onTap: () => onSelect(ShellSection.ai),
          ),
          const Spacer(),
          const Divider(),
          _SidebarItem(
            icon: Icons.settings_outlined,
            label: '设置',
            expanded: expanded,
            selected: false,
            onTap: onSettings,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Text(
                'v1.0.0 · 记录保存在本机',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    final content = Container(
      height: 46,
      margin: EdgeInsets.symmetric(
        horizontal: expanded ? 10 : 8,
        vertical: 2,
      ),
      padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment:
            expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: foreground),
          if (expanded) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: TextStyle(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final tappable = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );

    return expanded
        ? tappable
        : Tooltip(message: label, child: tappable);
  }
}
