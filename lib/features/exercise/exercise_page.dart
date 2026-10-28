import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_date.dart';
import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../data/seed_exercises.dart';
import '../../models/exercise.dart';

/// 打开 B 站视频。手机上会尝试唤起 B 站 App 或系统浏览器。
Future<void> openBilibiliVideo(
  BuildContext context,
  ExerciseVideo video,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final launched = await launchUrl(
      Uri.parse(video.url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('没能打开 B 站，请检查是否安装了浏览器。')));
    }
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('没能打开 B 站，请稍后再试。')));
  }
}

class ExercisePage extends StatefulWidget {
  const ExercisePage({super.key});

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  int _tab = 0;
  String _category = 'all';
  DateTime _planDate = AppDate.today();

  Future<void> _addToPlan(ExerciseVideo video) async {
    final date = await showAddExercisePlanSheet(context, video);
    if (date == null || !mounted) return;
    showAppSnackBar(
      context,
      '已加入 ${date.month} 月 ${date.day} 日的运动计划',
      actionLabel: '查看',
      onAction: () => setState(() {
        _tab = 2;
        _planDate = date;
      }),
    );
  }

  void _openPlan(DateTime date) {
    setState(() {
      _tab = 2;
      _planDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: PageHeader(title: '运动', subtitle: 'B 站热门跟练，按方向挑一个，点开就能跳转'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ExerciseTabs(
            value: _tab,
            labels: const ['推荐', '收藏', '计划'],
            onChanged: (value) => setState(() => _tab = value),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              _RecommendationsView(
                category: _category,
                onCategoryChanged: (value) => setState(() => _category = value),
                onAddToPlan: _addToPlan,
                onOpenPlan: _openPlan,
              ),
              _FavoritesView(onAddToPlan: _addToPlan),
              _ExercisePlanView(
                date: _planDate,
                onDateChanged: (value) => setState(() => _planDate = value),
                onGoRecommend: () => setState(() => _tab = 0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseTabs extends StatelessWidget {
  const _ExerciseTabs({
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

class _RecommendationsView extends StatelessWidget {
  const _RecommendationsView({
    required this.category,
    required this.onCategoryChanged,
    required this.onAddToPlan,
    required this.onOpenPlan,
  });

  final String category;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<ExerciseVideo> onAddToPlan;
  final ValueChanged<DateTime> onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final today = AppDate.today();
    final todayKey = AppDate.key(today);
    final todayEntries = repository.exerciseEntriesFor(todayKey);
    final categories = category == 'all'
        ? exerciseCategories
        : exerciseCategories.where((item) => item.id == category).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('全部'),
              selected: category == 'all',
              onSelected: (_) => onCategoryChanged('all'),
            ),
            for (final item in exerciseCategories)
              ChoiceChip(
                label: Text(item.name),
                selected: category == item.id,
                onSelected: (_) => onCategoryChanged(item.id),
              ),
          ],
        ),
        if (todayEntries.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            onTap: () => onOpenPlan(today),
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.32),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.fitness_center,
                  size: 20,
                  color: AppColors.mint,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '今天已安排 ${todayEntries.length} 项运动 · '
                    '完成 ${todayEntries.where((e) => e.completed).length} 项',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '查看计划 ›',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (final item in categories) ...[
          _CategorySection(
            category: item,
            videos: seedExercises
                .where((video) => video.category == item.id)
                .toList(growable: false),
            onAddToPlan: onAddToPlan,
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.videos,
    required this.onAddToPlan,
  });

  final ExerciseCategory category;
  final List<ExerciseVideo> videos;
  final ValueChanged<ExerciseVideo> onAddToPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = categoryColor(category.id, theme.colorScheme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(categoryIcon(category.id), size: 19, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    category.subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TagChip(label: '${videos.length} 个热门'),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 760) {
              final columns = constraints.maxWidth >= 1060 ? 3 : 2;
              const spacing = 12.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final video in videos)
                    SizedBox(
                      width: width,
                      height: width * 9 / 16 + 130,
                      child: _VideoCard(
                        video: video,
                        onAddToPlan: () => onAddToPlan(video),
                      ),
                    ),
                ],
              );
            }
            return SizedBox(
              height: 274,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: videos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => SizedBox(
                  width: 252,
                  child: _VideoCard(
                    video: videos[index],
                    onAddToPlan: () => onAddToPlan(videos[index]),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.onAddToPlan});

  final ExerciseVideo video;
  final VoidCallback onAddToPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repository = context.watch<AppRepository>();
    final favorite = repository.isExerciseFavorite(video.id);
    return SectionCard(
      padding: EdgeInsets.zero,
      onTap: () => openBilibiliVideo(context, video),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _VideoCover(video: video),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.42),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.32),
                    shape: const CircleBorder(),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: favorite ? '取消收藏' : '收藏',
                      onPressed: () =>
                          repository.toggleExerciseFavorite(video.id),
                      icon: Icon(
                        favorite ? Icons.star : Icons.star_border,
                        size: 20,
                        color: favorite ? AppColors.peach : Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: _OverlayChip(label: video.durationLabel),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 38,
                    child: Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.uploader} · ${video.playLabel}播放',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: onAddToPlan,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.playlist_add, size: 17),
                          label: const Text('加入计划'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: '在 B 站打开',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => openBilibiliVideo(context, video),
                        icon: const Icon(Icons.open_in_new, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCover extends StatelessWidget {
  const _VideoCover({required this.video, this.radius = 0});

  final ExerciseVideo video;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final child = video.coverAsset == null || video.coverAsset!.isEmpty
        ? _CoverFallback(category: video.category)
        : Image.asset(
            video.coverAsset!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) =>
                _CoverFallback(category: video.category),
          );
    if (radius <= 0) return child;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category, Theme.of(context).colorScheme);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.75),
            color.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          categoryIcon(category),
          size: 34,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FavoritesView extends StatelessWidget {
  const _FavoritesView({required this.onAddToPlan});

  final ValueChanged<ExerciseVideo> onAddToPlan;

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final favorites = repository.favoriteExercises;
    if (favorites.isEmpty) {
      return const EmptyState(
        icon: Icons.star_border,
        title: '还没有收藏的运动',
        message: '在推荐里点视频封面右上角的星星，先存几个常练的。',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: favorites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final video = favorites[index];
        return _FavoriteTile(
          video: video,
          onAddToPlan: () => onAddToPlan(video),
        );
      },
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.video, required this.onAddToPlan});

  final ExerciseVideo video;
  final VoidCallback onAddToPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repository = context.watch<AppRepository>();
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      onTap: () => openBilibiliVideo(context, video),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            height: 61,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _VideoCover(video: video, radius: 10),
                Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: _OverlayChip(label: video.durationLabel),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${video.uploader} · ${video.playLabel}播放',
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
            tooltip: '取消收藏',
            onPressed: () => repository.toggleExerciseFavorite(video.id),
            icon: const Icon(Icons.star, color: AppColors.peach, size: 20),
          ),
          IconButton(
            tooltip: '加入计划',
            onPressed: onAddToPlan,
            icon: Icon(
              Icons.playlist_add,
              size: 21,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExercisePlanView extends StatelessWidget {
  const _ExercisePlanView({
    required this.date,
    required this.onDateChanged,
    required this.onGoRecommend,
  });

  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onGoRecommend;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '查看哪一天的运动计划',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null) onDateChanged(AppDate.dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final theme = Theme.of(context);
    final key = AppDate.key(date);
    final entries = repository.exerciseEntriesFor(key);
    final completed = entries.where((entry) => entry.completed).length;
    final totalSeconds = entries.fold<int>(0, (sum, entry) {
      final video = repository.exerciseById(entry.exerciseId);
      return sum + (video?.durationSeconds ?? 0);
    });
    final completedSeconds = entries
        .where((entry) => entry.completed)
        .fold<int>(0, (sum, entry) {
          final video = repository.exerciseById(entry.exerciseId);
          return sum + (video?.durationSeconds ?? 0);
        });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        SectionCard(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '前一天',
                    onPressed: () =>
                        onDateChanged(date.subtract(const Duration(days: 1))),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _pickDate(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            Text(
                              AppDate.dateLabel(date),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              AppDate.isToday(date) ? '今天' : '点这里换一天',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '后一天',
                    onPressed: () =>
                        onDateChanged(date.add(const Duration(days: 1))),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  TextButton(
                    onPressed: () => onDateChanged(AppDate.today()),
                    child: const Text('今天'),
                  ),
                ],
              ),
              if (entries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _PlanStat(
                            label: '安排',
                            value: '${entries.length}',
                            unit: '项',
                          ),
                          _PlanStat(
                            label: '完成',
                            value: '$completed/${entries.length}',
                          ),
                          _PlanStat(
                            label: '总时长',
                            value: '${(totalSeconds / 60).round()}',
                            unit: '分钟',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: entries.isEmpty
                              ? 0
                              : completed / entries.length,
                          minHeight: 7,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.13,
                          ),
                        ),
                      ),
                      if (completedSeconds > 0) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '已完成约 ${(completedSeconds / 60).round()} 分钟',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          EmptyState(
            icon: Icons.event_note_outlined,
            title: AppDate.isToday(date) ? '今天还没有运动安排' : '这一天还没有运动安排',
            message: '去推荐里挑一个跟练，点「加入计划」就会出现在这里。',
            actionLabel: '去挑一个',
            onAction: onGoRecommend,
          )
        else
          for (var index = 0; index < entries.length; index++) ...[
            _PlanEntryTile(entry: entries[index]),
            if (index < entries.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _PlanStat extends StatelessWidget {
  const _PlanStat({required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanEntryTile extends StatelessWidget {
  const _PlanEntryTile({required this.entry});

  final ExercisePlanEntry entry;

  Future<void> _delete(BuildContext context) async {
    final repository = context.read<AppRepository>();
    final confirmed = await showConfirmDialog(
      context,
      title: '从运动计划里移除？',
      message: '只会移除这一天的安排，收藏和视频都还在。',
      confirmLabel: '移除',
      destructive: true,
    );
    if (!confirmed) return;
    await repository.deleteExerciseEntry(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final theme = Theme.of(context);
    final video = repository.exerciseById(entry.exerciseId);
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(8, 10, 6, 10),
      onTap: video == null ? null : () => openBilibiliVideo(context, video),
      child: Row(
        children: [
          Checkbox(
            value: entry.completed,
            onChanged: (value) =>
                repository.setExerciseCompleted(entry.id, value ?? false),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 2),
          if (video != null) ...[
            SizedBox(
              width: 84,
              height: 47,
              child: _VideoCover(video: video, radius: 8),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video?.title ?? '视频已下架',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    decoration: entry.completed
                        ? TextDecoration.lineThrough
                        : null,
                    color: entry.completed
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  video == null
                      ? '可以从计划里移除'
                      : '${video.uploader} · ${video.durationLabel}',
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
            tooltip: '移除',
            onPressed: () => _delete(context),
            icon: Icon(
              Icons.remove_circle_outline,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 选择日期后把视频安排进运动计划；返回选中的日期，取消时返回 null。
Future<DateTime?> showAddExercisePlanSheet(
  BuildContext context,
  ExerciseVideo video,
) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddExercisePlanSheet(video: video),
  );
}

class _AddExercisePlanSheet extends StatefulWidget {
  const _AddExercisePlanSheet({required this.video});

  final ExerciseVideo video;

  @override
  State<_AddExercisePlanSheet> createState() => _AddExercisePlanSheetState();
}

class _AddExercisePlanSheetState extends State<_AddExercisePlanSheet> {
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = AppDate.today();
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
    if (picked == null || !mounted) return;
    setState(() => _date = AppDate.dateOnly(picked));
  }

  Future<void> _save() async {
    if (_saving) return;
    final repository = context.read<AppRepository>();
    final navigator = Navigator.of(context);
    final dateKey = AppDate.key(_date);
    if (repository.hasExerciseOnDate(widget.video.id, dateKey)) {
      showAppSnackBar(context, '这个视频已经在当天的计划里了。');
      return;
    }
    setState(() => _saving = true);
    await repository.addExerciseEntry(
      ExercisePlanEntry(
        id: repository.newId(),
        exerciseId: widget.video.id,
        date: dateKey,
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    navigator.pop(_date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = AppDate.today();
    final quickDates = [
      today,
      today.add(const Duration(days: 1)),
      today.add(const Duration(days: 2)),
    ];
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '加入运动计划',
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
              '${widget.video.title} · ${widget.video.durationLabel}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in quickDates)
                  ChoiceChip(
                    label: Text(
                      AppDate.isToday(item)
                          ? '今天'
                          : item == quickDates[1]
                          ? '明天'
                          : '后天',
                    ),
                    selected: AppDate.sameDay(item, _date),
                    onSelected: (_) => setState(() => _date = item),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _pickDate,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppDate.fullDateLabel(_date),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add),
              label: Text('加入 ${_date.month} 月 ${_date.day} 日计划'),
            ),
            const SizedBox(height: 10),
            Text(
              '加入后可以在「计划」里打勾完成，也能随时移除。',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData categoryIcon(String id) {
  return switch (id) {
    'dumbbell' => Icons.fitness_center,
    'cardio' => Icons.directions_run,
    'shoulder' => Icons.self_improvement,
    'arms' => Icons.sports_martial_arts,
    'waist' => Icons.accessibility_new,
    'calves' => Icons.directions_walk,
    'stretch' => Icons.spa,
    _ => Icons.sports_gymnastics,
  };
}

Color categoryColor(String id, ColorScheme scheme) {
  return switch (id) {
    'dumbbell' => AppColors.peach,
    'cardio' => AppColors.danger,
    'shoulder' => AppColors.warning,
    'arms' => const Color(0xFF8E7CC3),
    'waist' => scheme.primary,
    'calves' => AppColors.water,
    'stretch' => const Color(0xFF6FAE8A),
    _ => scheme.primary,
  };
}
