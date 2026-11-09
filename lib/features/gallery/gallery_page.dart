import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/gallery.dart';

const String _all = 'all';
const String _none = 'none';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  String _filter = _all;
  String? _importLabel;

  String _effectiveFilter(AppRepository repository) {
    if (_filter == _all || _filter == _none) return _filter;
    final known = repository.galleryCategories.any(
      (category) => category.id == _filter,
    );
    return known ? _filter : _all;
  }

  List<GalleryPhoto> _visible(AppRepository repository, String filter) {
    final known = repository.galleryCategories.map((item) => item.id).toSet();
    return repository.galleryPhotos
        .where((photo) {
          final uncategorized =
              photo.categoryId == null || !known.contains(photo.categoryId);
          if (filter == _all) return true;
          if (filter == _none) return uncategorized;
          return photo.categoryId == filter;
        })
        .toList(growable: false);
  }

  Future<void> _createCategory() async {
    final repository = context.read<AppRepository>();
    final name = await _askCategoryName(
      context,
      title: '新分类',
      confirmLabel: '添加',
      existing: repository.galleryCategories.map((item) => item.name).toSet(),
    );
    if (name == null || !mounted) return;
    final created = await repository.addGalleryCategory(name);
    if (!mounted) return;
    if (created == null) {
      showAppSnackBar(context, '没能添加这个分类');
      return;
    }
    setState(() => _filter = created.id);
  }

  Future<void> _manageCategories() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _ManageSheet(),
    );
  }

  Future<void> _upload() async {
    if (_importLabel != null) return;
    final repository = context.read<AppRepository>();
    final filter = _effectiveFilter(repository);
    String? categoryId;
    if (filter == _all) {
      final choice = await showModalBottomSheet<_CategoryChoice>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => const _CategorySheet(
          title: '放到哪个分类',
          description: '先选分类再选图片。也可以先不分类，之后再改。',
          confirmLabel: '选择图片',
        ),
      );
      if (choice == null || !mounted) return;
      categoryId = choice.categoryId;
    } else if (filter != _none) {
      categoryId = filter;
    }

    List<XFile> files;
    try {
      files = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) showAppSnackBar(context, '没能打开相册，请稍后再试。');
      return;
    }
    if (files.isEmpty || !mounted) return;

    setState(() => _importLabel = '正在导入 0/${files.length}');
    final inputs = <GalleryPhotoInput>[];
    var failed = 0;
    for (var i = 0; i < files.length; i++) {
      if (!mounted) return;
      setState(() => _importLabel = '正在导入 ${i + 1}/${files.length}');
      try {
        final bytes = await files[i].readAsBytes();
        if (bytes.isEmpty) {
          failed++;
          continue;
        }
        final size = await _imageSize(bytes);
        inputs.add(
          GalleryPhotoInput(bytes: bytes, width: size.$1, height: size.$2),
        );
      } catch (_) {
        failed++;
      }
    }
    final saved = await repository.addGalleryPhotos(
      categoryId: categoryId,
      photos: inputs,
    );
    failed += inputs.length - saved;
    if (!mounted) return;
    setState(() => _importLabel = null);
    if (saved == 0) {
      showAppSnackBar(context, '没能导入这些图片');
    } else if (failed > 0) {
      showAppSnackBar(context, '已添加 $saved 张，另有 $failed 张没能导入');
    } else {
      showAppSnackBar(context, saved == 1 ? '已添加 1 张图片' : '已添加 $saved 张图片');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final theme = Theme.of(context);
    final categories = repository.galleryCategories;
    final known = categories.map((item) => item.id).toSet();
    final filter = _effectiveFilter(repository);
    final photos = _visible(repository, filter);
    final uncategorized = repository.galleryPhotos
        .where(
          (photo) =>
              photo.categoryId == null || !known.contains(photo.categoryId),
        )
        .length;
    final subtitle = repository.galleryPhotos.isEmpty
        ? '上传图片，再按自己的分类筛选'
        : '${repository.galleryPhotos.length} 张'
              '${categories.isEmpty ? '' : ' · ${categories.length} 个分类'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: PageHeader(
            title: '图集',
            subtitle: subtitle,
            actions: [
              FilledButton.icon(
                onPressed: _importLabel == null ? _upload : null,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('上传'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('全部 · ${repository.galleryPhotos.length}'),
                  selected: filter == _all,
                  onSelected: (_) => setState(() => _filter = _all),
                ),
                for (final category in categories) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      '${category.name} · ${repository.galleryPhotos.where((photo) => photo.categoryId == category.id).length}',
                    ),
                    selected: filter == category.id,
                    onSelected: (_) => setState(() => _filter = category.id),
                  ),
                ],
                if (uncategorized > 0 || filter == _none) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('未分类 · $uncategorized'),
                    selected: filter == _none,
                    onSelected: (_) => setState(() => _filter = _none),
                  ),
                ],
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('新分类'),
                  onPressed: _createCategory,
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.tune, size: 18),
                    label: const Text('管理'),
                    onPressed: _manageCategories,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_importLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _importLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: photos.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: filter == _all ? '还没有图片' : '这个分类还没有图片',
                    message: filter == _all ? '从相册上传后，会按瀑布流排开' : '上传的图片会归到当前分类',
                    actionLabel: '上传图片',
                    onAction: _upload,
                  ),
                )
              : _Masonry(
                  photos: photos,
                  showBadge: filter == _all,
                  badgeFor: (photo) =>
                      repository.galleryCategoryById(photo.categoryId)?.name ??
                      '未分类',
                  onTap: (photo) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _GalleryViewer(photoId: photo.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

double _tileHeight(GalleryPhoto photo, double width) {
  final photoWidth = photo.width <= 0 ? 1 : photo.width;
  final photoHeight = photo.height <= 0 ? 1 : photo.height;
  final ratio = (photoWidth / photoHeight).clamp(0.5, 1.85);
  return width / ratio;
}

class _Masonry extends StatelessWidget {
  const _Masonry({
    required this.photos,
    required this.showBadge,
    required this.badgeFor,
    required this.onTap,
  });

  final List<GalleryPhoto> photos;
  final bool showBadge;
  final String Function(GalleryPhoto photo) badgeFor;
  final ValueChanged<GalleryPhoto> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 4
            : width >= 760
            ? 3
            : 2;
        const gap = 10.0;
        const horizontal = 16.0;
        final itemWidth =
            (width - horizontal * 2 - gap * (columns - 1)) / columns;
        final heights = List<double>.filled(columns, 0);
        final buckets = List<List<GalleryPhoto>>.generate(
          columns,
          (_) => <GalleryPhoto>[],
        );
        for (final photo in photos) {
          var target = 0;
          for (var i = 1; i < columns; i++) {
            if (heights[i] < heights[target]) target = i;
          }
          buckets[target].add(photo);
          heights[target] += _tileHeight(photo, itemWidth) + gap;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                SizedBox(
                  width: itemWidth,
                  child: Column(
                    children: [
                      for (final photo in buckets[i])
                        Padding(
                          padding: const EdgeInsets.only(bottom: gap),
                          child: _PhotoTile(
                            key: ValueKey(photo.id),
                            photo: photo,
                            width: itemWidth,
                            badge: showBadge ? badgeFor(photo) : null,
                            onTap: () => onTap(photo),
                          ),
                        ),
                    ],
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

class _PhotoTile extends StatefulWidget {
  const _PhotoTile({
    super.key,
    required this.photo,
    required this.width,
    required this.onTap,
    this.badge,
  });

  final GalleryPhoto photo;
  final double width;
  final VoidCallback onTap;
  final String? badge;

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  Uint8List? _bytes;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _bytes = context.read<AppRepository>().peekGalleryPhoto(widget.photo.id);
    if (_bytes == null) _load();
  }

  Future<void> _load() async {
    final bytes = await context.read<AppRepository>().loadGalleryPhoto(
      widget.photo.id,
    );
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _missing = bytes == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = _tileHeight(widget.photo, widget.width);
    final bytes = _bytes;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget image;
    if (bytes != null) {
      image = Image.memory(
        bytes,
        width: widget.width,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: (widget.width * dpr).round().clamp(1, 1600),
      );
    } else if (_missing) {
      image = Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant);
    } else {
      image = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: SizedBox(
          height: height,
          width: widget.width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: image),
              if (widget.badge != null)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Text(
                          widget.badge!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryViewer extends StatefulWidget {
  const _GalleryViewer({required this.photoId});

  final String photoId;

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  Uint8List? _bytes;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _bytes = context.read<AppRepository>().peekGalleryPhoto(widget.photoId);
    if (_bytes == null) _load();
  }

  Future<void> _load() async {
    final bytes = await context.read<AppRepository>().loadGalleryPhoto(
      widget.photoId,
    );
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _missing = bytes == null;
    });
  }

  GalleryPhoto? _photo(AppRepository repository) {
    for (final photo in repository.galleryPhotos) {
      if (photo.id == widget.photoId) return photo;
    }
    return null;
  }

  Future<void> _move(GalleryPhoto photo) async {
    final repository = context.read<AppRepository>();
    final choice = await showModalBottomSheet<_CategoryChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _CategorySheet(
        title: '改到哪个分类',
        description: '图片还在，只是换一个分类。',
        confirmLabel: '保存',
        initialCategoryId: photo.categoryId,
      ),
    );
    if (choice == null || !mounted) return;
    await repository.setGalleryPhotoCategory(photo.id, choice.categoryId);
    if (!mounted) return;
    final name =
        repository.galleryCategoryById(choice.categoryId)?.name ?? '未分类';
    showAppSnackBar(context, '已改到$name');
  }

  Future<void> _delete(GalleryPhoto photo) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除这张图片？',
      message: '删除后不能恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<AppRepository>().deleteGalleryPhoto(photo.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final photo = _photo(repository);
    final category =
        repository.galleryCategoryById(photo?.categoryId)?.name ?? '未分类';
    final bytes = _bytes;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: photo == null
            ? const Text('图片')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${AppDate.fullDateLabel(photo.createdAt)} ${AppDate.timeLabel(photo.createdAt)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
        actions: [
          if (photo != null) ...[
            IconButton(
              tooltip: '改分类',
              onPressed: () => _move(photo),
              icon: const Icon(Icons.drive_file_move_outlined),
            ),
            IconButton(
              tooltip: '删除',
              onPressed: () => _delete(photo),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ],
      ),
      body: Center(
        child: bytes != null
            ? InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.memory(bytes, fit: BoxFit.contain),
              )
            : _missing || photo == null
            ? const Text('这张图片已经不在了', style: TextStyle(color: Colors.white70))
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

class _CategoryChoice {
  const _CategoryChoice(this.categoryId);

  final String? categoryId;
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.title,
    required this.description,
    required this.confirmLabel,
    this.initialCategoryId,
  });

  final String title;
  final String description;
  final String confirmLabel;
  final String? initialCategoryId;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialCategoryId;
  }

  Future<void> _create() async {
    final repository = context.read<AppRepository>();
    final name = await _askCategoryName(
      context,
      title: '新分类',
      confirmLabel: '添加',
      existing: repository.galleryCategories.map((item) => item.name).toSet(),
    );
    if (name == null || !mounted) return;
    final created = await repository.addGalleryCategory(name);
    if (!mounted || created == null) return;
    setState(() => _selectedId = created.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repository = context.watch<AppRepository>();
    final categories = repository.galleryCategories;
    final selected = categories.any((item) => item.id == _selectedId)
        ? _selectedId
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('未分类'),
                selected: selected == null,
                onSelected: (_) => setState(() => _selectedId = null),
              ),
              for (final category in categories)
                ChoiceChip(
                  label: Text(category.name),
                  selected: selected == category.id,
                  onSelected: (_) => setState(() => _selectedId = category.id),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建分类'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context, _CategoryChoice(selected)),
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _ManageSheet extends StatelessWidget {
  const _ManageSheet();

  Future<void> _rename(BuildContext context, GalleryCategory category) async {
    final repository = context.read<AppRepository>();
    final name = await _askCategoryName(
      context,
      title: '重命名',
      confirmLabel: '保存',
      initial: category.name,
      existing: repository.galleryCategories
          .where((item) => item.id != category.id)
          .map((item) => item.name)
          .toSet(),
    );
    if (name == null || !context.mounted) return;
    final ok = await repository.renameGalleryCategory(category.id, name);
    if (!context.mounted) return;
    if (!ok) showAppSnackBar(context, '没能改这个名字');
  }

  Future<void> _delete(BuildContext context, GalleryCategory category) async {
    final repository = context.read<AppRepository>();
    final count = repository.galleryPhotos
        .where((photo) => photo.categoryId == category.id)
        .length;
    final ok = await showConfirmDialog(
      context,
      title: '删除分类？',
      message: count == 0
          ? '删除「${category.name}」后不能恢复。'
          : '删除「${category.name}」后，里面的 $count 张图片会留在未分类。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await repository.deleteGalleryCategory(category.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repository = context.watch<AppRepository>();
    final categories = repository.galleryCategories;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '管理分类',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '分类只用来筛选。删掉分类不会删图片。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final name = await _askCategoryName(
                    context,
                    title: '新分类',
                    confirmLabel: '添加',
                    existing: repository.galleryCategories
                        .map((item) => item.name)
                        .toSet(),
                  );
                  if (name == null || !context.mounted) return;
                  await repository.addGalleryCategory(name);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新分类'),
              ),
            ),
            if (categories.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('还没有分类'),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final category in categories)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(category.name),
                        subtitle: Text(
                          '${repository.galleryPhotos.where((photo) => photo.categoryId == category.id).length} 张',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '重命名',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _rename(context, category),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                            IconButton(
                              tooltip: '删除',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _delete(context, category),
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _askCategoryName(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required Set<String> existing,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return _CategoryNameDialog(
        title: title,
        confirmLabel: confirmLabel,
        existing: existing,
        initial: initial,
      );
    },
  );
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.existing,
    required this.initial,
  });

  final String title;
  final String confirmLabel;
  final Set<String> existing;
  final String initial;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _controller;
  var _message = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _message = '先写个名字');
      return;
    }
    if (widget.existing.contains(trimmed)) {
      setState(() => _message = '已经有这个分类了');
      return;
    }
    Navigator.pop(context, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 20,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '例如饮食、身材、运动'),
            onSubmitted: (_) => _submit(),
          ),
          if (_message.isNotEmpty)
            Text(_message, style: TextStyle(color: scheme.error, fontSize: 13)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

Future<(int, int)> _imageSize(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = (image.width, image.height);
    image.dispose();
    codec.dispose();
    return size;
  } catch (_) {
    return (1, 1);
  }
}
