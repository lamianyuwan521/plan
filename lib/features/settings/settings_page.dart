import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../services/export_service.dart';
import 'goal_edit_page.dart';
import 'profile_edit_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final profile = repository.profile;
    final theme = Theme.of(context);
    final target = profile.targetWeightKg;
    final genderLabel = switch (profile.gender) {
      'male' => '男',
      'female' => '女',
      _ => '不透露',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
        children: [
          _SettingsSection(
            title: '个人信息',
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14),
                leading: const Icon(Icons.person_outline),
                title: const Text('个人资料'),
                subtitle: Text(
                  '${profile.nickname} · $genderLabel · '
                  '${profile.heightCm.toStringAsFixed(0)} cm',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileEditPage(),
                  ),
                ),
              ),
              const Divider(indent: 14, endIndent: 14),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14),
                leading: const Icon(Icons.flag_outlined),
                title: const Text('目标与预算'),
                subtitle: Text(
                  '预算 ${repository.dailyBudget} kcal · '
                  '${target == null ? '未设目标' : '目标 ${weightText(target, profile.weightUnit)}'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GoalEditPage(),
                  ),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: '偏好',
            children: [
              _SegmentedSetting<String>(
                title: '体重单位',
                subtitle: '只影响显示，历史数据不变',
                value: profile.weightUnit,
                options: const [('kg', '公斤'), ('jin', '斤')],
                onChanged: (value) => repository.updateProfile(
                  profile.copyWith(weightUnit: value),
                ),
              ),
              const Divider(indent: 14, endIndent: 14),
              _SegmentedSetting<String>(
                title: '主题',
                value: profile.themeMode,
                options: const [
                  ('system', '系统'),
                  ('light', '浅色'),
                  ('dark', '深色'),
                ],
                onChanged: (value) => repository.updateProfile(
                  profile.copyWith(themeMode: value),
                ),
              ),
              const Divider(indent: 14, endIndent: 14),
              _SegmentedSetting<int>(
                title: '每周起始',
                value: profile.weekStart,
                options: const [(1, '周一'), (7, '周日')],
                onChanged: (value) => repository.updateProfile(
                  profile.copyWith(weekStart: value),
                ),
              ),
              const Divider(indent: 14, endIndent: 14),
              _SegmentedSetting<String>(
                title: '启动页',
                subtitle: '下次打开 App 时生效',
                value: profile.startPage,
                options: const [('today', '今日'), ('recipes', '食谱')],
                onChanged: (value) => repository.updateProfile(
                  profile.copyWith(startPage: value),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: '数据',
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14),
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('导出数据'),
                subtitle: Text(
                  '${repository.weightRecords.length} 条体重 · '
                  '${repository.mealEntries.length} 条饮食 · '
                  '${repository.waterLogs.length} 条喝水',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showExportSheet(context, repository),
              ),
              const Divider(indent: 14, endIndent: 14),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14),
                leading: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  '清空业务数据',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: const Text('保留个人资料、食谱与设置'),
                onTap: () => _clearData(context, repository),
              ),
            ],
          ),
          _SettingsSection(
            title: '关于',
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14),
                leading: const Icon(Icons.info_outline),
                title: const Text('关于小一二减肥记'),
                subtitle: const Text('版本 1.0.0 · 数据仅存本机'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAbout(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '小一二减肥记 v1.0.0',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExportSheet(
    BuildContext context,
    AppRepository repository,
  ) async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('完整备份（JSON）'),
              subtitle: const Text('包含全部记录与设置，用于备份和迁移'),
              onTap: () => Navigator.pop(sheetContext, 'json'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('体重记录（CSV）'),
              onTap: () => Navigator.pop(sheetContext, 'weights'),
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_outlined),
              title: const Text('饮食记录（CSV）'),
              onTap: () => Navigator.pop(sheetContext, 'meals'),
            ),
            ListTile(
              leading: const Icon(Icons.water_drop_outlined),
              title: const Text('喝水记录（CSV）'),
              onTap: () => Navigator.pop(sheetContext, 'water'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (kind == null || !context.mounted) return;

    final (content, extension, mime) = switch (kind) {
      'json' => (repository.exportJson(), 'json', 'application/json'),
      'weights' => (repository.exportWeightsCsv(), 'csv', 'text/csv'),
      'meals' => (repository.exportMealsCsv(), 'csv', 'text/csv'),
      _ => (repository.exportWaterCsv(), 'csv', 'text/csv'),
    };
    final base = 'xiaoyier-$kind-${AppDate.todayKey()}';
    try {
      final path = await saveTextFile(
        fileName: base,
        extension: extension,
        content: content,
        mimeType: mime,
      );
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        path == null ? '已取消导出' : '已导出：$path',
      );
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(context, '导出失败：$error');
    }
  }

  Future<void> _clearData(
    BuildContext context,
    AppRepository repository,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ClearDataDialog(),
    );
    if (confirmed != true || !context.mounted) return;
    await repository.clearBusinessData();
    if (!context.mounted) return;
    showAppSnackBar(context, '已清空业务数据');
  }

  Future<void> _showAbout(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('关于小一二减肥记'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本 1.0.0'),
            SizedBox(height: 10),
            Text('把今天吃了什么、喝了多少、体重有没有降，收进一张不用动脑子的日历。'),
            SizedBox(height: 12),
            Text('数据只保存在本机，不注册、不联网、不上传。建议定期在「导出数据」里做一次备份。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedSetting<T> extends StatelessWidget {
  const _SegmentedSetting({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodyMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [
              for (final option in options)
                ButtonSegment<T>(
                  value: option.$1,
                  label: Text(option.$2),
                ),
            ],
            selected: {value},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

class _ClearDataDialog extends StatefulWidget {
  const _ClearDataDialog();

  @override
  State<_ClearDataDialog> createState() => _ClearDataDialogState();
}

class _ClearDataDialogState extends State<_ClearDataDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canClear = _controller.text.trim() == '删除';
    return AlertDialog(
      title: const Text('清空业务数据？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '将删除全部体重、饮食、喝水记录，个人资料、食谱与设置会保留。此操作不可撤销。',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '输入「删除」确认',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          onPressed:
              canClear ? () => Navigator.pop(context, true) : null,
          child: const Text('清空'),
        ),
      ],
    );
  }
}
