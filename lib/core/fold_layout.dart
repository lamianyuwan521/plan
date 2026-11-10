import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';

import 'widgets.dart';

/// How an iPhone Duo is being held.
///
/// The cover screen stays a one-hand phone. The inner screen is a book:
/// a vertical crease when held upright, a horizontal crease when turned
/// sideways or set down half-open.
enum DuoPosture { folded, unfolded, tabletop }

class DuoLayout {
  const DuoLayout({
    required this.posture,
    required this.split,
    required this.hinge,
    required this.hingeFromSystem,
  });

  final DuoPosture posture;

  /// [Axis.horizontal] places panes left and right.
  /// [Axis.vertical] places panes above and below the crease.
  final Axis split;
  final Rect? hinge;
  final bool hingeFromSystem;

  bool get isPhone => posture == DuoPosture.folded;
  bool get isTabletop => posture == DuoPosture.tabletop;
  bool get sideBySide => !isPhone && split == Axis.horizontal;
  bool get topBottom => !isPhone && split == Axis.vertical;

  static DuoLayout of(BuildContext context) {
    return resolve(
      size: MediaQuery.sizeOf(context),
      features: MediaQuery.displayFeaturesOf(context),
    );
  }

  static DuoLayout resolve({
    required Size size,
    required List<DisplayFeature> features,
  }) {
    final folds = features
        .where(
          (feature) =>
              feature.type == DisplayFeatureType.fold ||
              feature.type == DisplayFeatureType.hinge,
        )
        .toList();

    if (folds.isNotEmpty && size.width >= 520) {
      final fold = folds.first;
      final verticalCrease = fold.bounds.width <= fold.bounds.height;
      final halfOpen = fold.state == DisplayFeatureState.postureHalfOpened;
      if (halfOpen && !verticalCrease) {
        return DuoLayout(
          posture: DuoPosture.tabletop,
          split: Axis.vertical,
          hinge: fold.bounds,
          hingeFromSystem: true,
        );
      }
      return DuoLayout(
        posture: DuoPosture.unfolded,
        split: verticalCrease ? Axis.horizontal : Axis.vertical,
        hinge: fold.bounds,
        hingeFromSystem: true,
      );
    }

    if (size.width < 600) {
      return const DuoLayout(
        posture: DuoPosture.folded,
        split: Axis.vertical,
        hinge: null,
        hingeFromSystem: false,
      );
    }

    final shortest = math.min(size.width, size.height);
    final longest = math.max(size.width, size.height);
    final ratio = shortest == 0 ? 99.0 : longest / shortest;
    final looksLikeInnerScreen =
        shortest >= 600 &&
        shortest <= 980 &&
        longest <= 1400 &&
        ratio <= 1.7;

    if (looksLikeInnerScreen) {
      final portrait = size.height >= size.width;
      const thickness = 12.0;
      final hinge = portrait
          ? Rect.fromLTWH(
              size.width / 2 - thickness / 2,
              0,
              thickness,
              size.height,
            )
          : Rect.fromLTWH(
              0,
              size.height / 2 - thickness / 2,
              size.width,
              thickness,
            );
      return DuoLayout(
        posture: DuoPosture.unfolded,
        split: portrait ? Axis.horizontal : Axis.vertical,
        hinge: hinge,
        hingeFromSystem: false,
      );
    }

    return DuoLayout(
      posture: DuoPosture.unfolded,
      split: size.width >= size.height ? Axis.horizontal : Axis.vertical,
      hinge: null,
      hingeFromSystem: false,
    );
  }
}

class DuoGeometry {
  const DuoGeometry({
    required this.splitActive,
    required this.sideBySide,
    required this.topBottom,
    required this.hasCrease,
    required this.leading,
    required this.gutter,
    required this.trailing,
    required this.width,
    required this.height,
  });

  final bool splitActive;
  final bool sideBySide;
  final bool topBottom;

  /// A real or inferred crease cuts this box. Panes must stay off it.
  final bool hasCrease;
  final double leading;
  final double gutter;
  final double trailing;
  final double width;
  final double height;

  static const empty = DuoGeometry(
    splitActive: false,
    sideBySide: false,
    topBottom: false,
    hasCrease: false,
    leading: 0,
    gutter: 0,
    trailing: 0,
    width: 0,
    height: 0,
  );

  static DuoGeometry compute({
    required DuoLayout layout,
    required Offset origin,
    required Size size,
  }) {
    if (layout.isPhone || size.width < 1 || size.height < 1) {
      return DuoGeometry(
        splitActive: false,
        sideBySide: false,
        topBottom: false,
        hasCrease: false,
        leading: size.width,
        gutter: 0,
        trailing: 0,
        width: _q(size.width),
        height: _q(size.height),
      );
    }

    if (layout.sideBySide) {
      final hinged = _cut(
        start: layout.hinge == null
            ? null
            : layout.hinge!.left - origin.dx,
        end: layout.hinge == null ? null : layout.hinge!.right - origin.dx,
        extent: size.width,
        minPane: 150,
      );
      if (hinged != null) {
        return DuoGeometry(
          splitActive: true,
          sideBySide: true,
          topBottom: false,
          hasCrease: true,
          leading: hinged.$1,
          gutter: hinged.$2,
          trailing: hinged.$3,
          width: _q(size.width),
          height: _q(size.height),
        );
      }
      if (size.width >= 760) {
        const gutter = 20.0;
        final pane = (size.width - gutter) / 2;
        return DuoGeometry(
          splitActive: pane >= 220,
          sideBySide: true,
          topBottom: false,
          hasCrease: false,
          leading: _q(pane),
          gutter: gutter,
          trailing: _q(pane),
          width: _q(size.width),
          height: _q(size.height),
        );
      }
    }

    if (layout.topBottom) {
      final hinged = _cut(
        start: layout.hinge == null
            ? null
            : layout.hinge!.top - origin.dy,
        end: layout.hinge == null ? null : layout.hinge!.bottom - origin.dy,
        extent: size.height,
        minPane: 140,
      );
      if (hinged != null) {
        return DuoGeometry(
          splitActive: true,
          sideBySide: false,
          topBottom: true,
          hasCrease: true,
          leading: hinged.$1,
          gutter: hinged.$2,
          trailing: hinged.$3,
          width: _q(size.width),
          height: _q(size.height),
        );
      }
      if (size.height >= 640 && size.width >= 600) {
        const gutter = 16.0;
        final pane = (size.height - gutter) / 2;
        return DuoGeometry(
          splitActive: true,
          sideBySide: false,
          topBottom: true,
          hasCrease: false,
          leading: _q(pane),
          gutter: gutter,
          trailing: _q(pane),
          width: _q(size.width),
          height: _q(size.height),
        );
      }
    }

    return DuoGeometry(
      splitActive: false,
      sideBySide: layout.sideBySide,
      topBottom: layout.topBottom,
      hasCrease: false,
      leading: _q(size.width),
      gutter: 0,
      trailing: 0,
      width: _q(size.width),
      height: _q(size.height),
    );
  }

  /// Scales pane sizes when a child is slightly narrower than the scope.
  DuoGeometry fit(double width, double height) {
    if (!splitActive || width <= 0 || height <= 0) return this;
    final sx = this.width == 0 ? 1.0 : width / this.width;
    final sy = this.height == 0 ? 1.0 : height / this.height;
    final scale = sideBySide ? sx : sy;
    if ((scale - 1).abs() < 0.01 && (width - this.width).abs() < 1) {
      return this;
    }
    final leading = _q(this.leading * scale);
    final gutter = _q(this.gutter * scale);
    final trailing = _q((sideBySide ? width : height) - leading - gutter);
    return DuoGeometry(
      splitActive: splitActive && leading >= 120 && trailing >= 120,
      sideBySide: sideBySide,
      topBottom: topBottom,
      hasCrease: hasCrease,
      leading: leading,
      gutter: gutter,
      trailing: math.max(0, trailing),
      width: _q(width),
      height: _q(height),
    );
  }

  static (double, double, double)? _cut({
    required double? start,
    required double? end,
    required double extent,
    required double minPane,
  }) {
    if (start == null || end == null) return null;
    final gutterStart = start - 10;
    final gutterEnd = math.max(end + 10, gutterStart + 24);
    if (gutterEnd <= 32 || gutterStart >= extent - 32) return null;
    final leading = _q(gutterStart.clamp(0.0, extent));
    final trailingStart = _q(gutterEnd.clamp(0.0, extent));
    final gutter = _q(math.max(0, trailingStart - leading));
    final trailing = _q(math.max(0, extent - leading - gutter));
    if (leading < minPane || trailing < minPane) return null;
    return (leading, gutter, trailing);
  }

  static double _q(double value) => (value * 2).roundToDouble() / 2;

  @override
  bool operator ==(Object other) {
    return other is DuoGeometry &&
        splitActive == other.splitActive &&
        sideBySide == other.sideBySide &&
        topBottom == other.topBottom &&
        hasCrease == other.hasCrease &&
        leading == other.leading &&
        gutter == other.gutter &&
        trailing == other.trailing &&
        width == other.width &&
        height == other.height;
  }

  @override
  int get hashCode => Object.hash(
    splitActive,
    sideBySide,
    topBottom,
    hasCrease,
    leading,
    gutter,
    trailing,
    width,
    height,
  );
}

class DuoScope extends StatefulWidget {
  const DuoScope({super.key, required this.child});

  final Widget child;

  static DuoGeometry of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DuoInherited>();
    return scope?.geometry ?? DuoGeometry.empty;
  }

  static DuoGeometry? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_DuoInherited>()
        ?.geometry;
  }

  @override
  State<DuoScope> createState() => _DuoScopeState();
}

class _DuoScopeState extends State<DuoScope> {
  final GlobalKey _key = GlobalKey();
  DuoGeometry? _measured;

  @override
  Widget build(BuildContext context) {
    final layout = DuoLayout.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final geometry =
            _measured ??
            DuoGeometry.compute(
              layout: layout,
              origin: Offset.zero,
              size: size,
            );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _capture(layout);
        });
        return _DuoInherited(
          geometry: geometry,
          child: KeyedSubtree(key: _key, child: widget.child),
        );
      },
    );
  }

  void _capture(DuoLayout layout) {
    if (!mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;
    final next = DuoGeometry.compute(
      layout: layout,
      origin: box.localToGlobal(Offset.zero),
      size: box.size,
    );
    if (_measured == next) return;
    setState(() => _measured = next);
  }
}

class _DuoInherited extends InheritedWidget {
  const _DuoInherited({required this.geometry, required super.child});

  final DuoGeometry geometry;

  @override
  bool updateShouldNotify(_DuoInherited oldWidget) {
    return geometry != oldWidget.geometry;
  }
}

/// One scroll on the cover screen. Two panes, kept off the crease, when open.
class DuoSplit extends StatelessWidget {
  const DuoSplit({
    super.key,
    required this.first,
    required this.second,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 28),
    this.gap = 14,
  });

  final Widget first;
  final Widget second;
  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final geo = DuoScope.maybeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fitted = geo?.fit(constraints.maxWidth, constraints.maxHeight);
        final split =
            fitted != null &&
            fitted.splitActive &&
            constraints.hasBoundedHeight &&
            constraints.hasBoundedWidth;
        if (!split) {
          return ListView(
            padding: padding,
            children: [
              first,
              SizedBox(height: gap),
              second,
            ],
          );
        }
        if (fitted.sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: fitted.leading,
                child: _pane(
                  first,
                  EdgeInsets.fromLTRB(
                    padding.left,
                    padding.top,
                    8,
                    padding.bottom,
                  ),
                ),
              ),
              SizedBox(width: fitted.gutter),
              SizedBox(
                width: fitted.trailing,
                child: _pane(
                  second,
                  EdgeInsets.fromLTRB(
                    8,
                    padding.top,
                    padding.right,
                    padding.bottom,
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(
              height: fitted.leading,
              child: _pane(
                first,
                EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 8),
              ),
            ),
            SizedBox(height: fitted.gutter),
            SizedBox(
              height: fitted.trailing,
              child: _pane(
                second,
                EdgeInsets.fromLTRB(
                  padding.left,
                  8,
                  padding.right,
                  padding.bottom,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pane(Widget child, EdgeInsets padding) {
    return SingleChildScrollView(padding: padding, child: child);
  }
}

/// Keeps a heading on the leaf that does not cross a vertical crease.
class DuoBlock extends StatelessWidget {
  const DuoBlock({super.key, required this.child, this.trailing});

  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final geo = DuoScope.maybeOf(context);
    if (geo == null || !geo.hasCrease || !geo.sideBySide || !geo.splitActive) {
      return child;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: geo.leading, child: child),
        SizedBox(width: geo.gutter),
        SizedBox(
          width: geo.trailing,
          child: trailing ?? const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Secondary routes sit on one leaf. The other leaf is a quiet title card.
class DuoStage extends StatelessWidget {
  const DuoStage({
    super.key,
    required this.child,
    required this.title,
    required this.message,
  });

  final Widget child;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DuoScope(
      child: Builder(
        builder: (context) {
          final geo = DuoScope.of(context);
          if (!geo.splitActive) return child;
          final companion = _DuoCompanion(title: title, message: message);
          if (geo.sideBySide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: geo.leading, child: companion),
                SizedBox(width: geo.gutter),
                SizedBox(width: geo.trailing, child: child),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(height: geo.leading, child: companion),
              SizedBox(height: geo.gutter),
              SizedBox(height: geo.trailing, child: child),
            ],
          );
        },
      ),
    );
  }
}

class _DuoCompanion extends StatelessWidget {
  const _DuoCompanion({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ColoredBox(
      color: scheme.primaryContainer.withValues(alpha: 0.28),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MascotAvatar(size: 72),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
