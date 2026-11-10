import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyier/core/fold_layout.dart';

void main() {
  test('cover screen stays a single column', () {
    final layout = DuoLayout.resolve(
      size: const Size(390, 844),
      features: const [],
    );

    expect(layout.isPhone, isTrue);
    expect(layout.hinge, isNull);
  });

  test('inner screen infers a vertical crease', () {
    final layout = DuoLayout.resolve(
      size: const Size(768, 1024),
      features: const [],
    );

    expect(layout.isPhone, isFalse);
    expect(layout.sideBySide, isTrue);
    expect(layout.hinge, isNotNull);
    expect(layout.hinge!.center.dx, closeTo(384, 1));
  });

  test('sideways inner screen infers a horizontal crease', () {
    final layout = DuoLayout.resolve(
      size: const Size(1024, 768),
      features: const [],
    );

    expect(layout.topBottom, isTrue);
    expect(layout.hinge!.center.dy, closeTo(384, 1));
  });

  test('system hinge is kept and half-open becomes tabletop', () {
    final layout = DuoLayout.resolve(
      size: const Size(820, 980),
      features: [
        const DisplayFeature(
          bounds: Rect.fromLTWH(404, 0, 12, 980),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ],
    );

    expect(layout.hingeFromSystem, isTrue);
    expect(layout.sideBySide, isTrue);
    expect(layout.isTabletop, isFalse);

    final flat = DuoLayout.resolve(
      size: const Size(980, 820),
      features: [
        const DisplayFeature(
          bounds: Rect.fromLTWH(0, 404, 980, 12),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ],
    );
    expect(flat.isTabletop, isTrue);
    expect(flat.topBottom, isTrue);
  });

  test('panes stay off the crease', () {
    const layout = DuoLayout(
      posture: DuoPosture.unfolded,
      split: Axis.horizontal,
      hinge: Rect.fromLTWH(394, 0, 12, 1000),
      hingeFromSystem: true,
    );
    final geometry = DuoGeometry.compute(
      layout: layout,
      origin: const Offset(84, 0),
      size: const Size(700, 1000),
    );

    expect(geometry.splitActive, isTrue);
    expect(geometry.hasCrease, isTrue);
    final hingeRight = layout.hinge!.right - 84;
    expect(geometry.leading, lessThanOrEqualTo(layout.hinge!.left - 84));
    expect(geometry.leading + geometry.gutter, greaterThanOrEqualTo(hingeRight));
    expect(geometry.leading + geometry.gutter + geometry.trailing, closeTo(700, 1));
    expect(geometry.leading, greaterThanOrEqualTo(150));
    expect(geometry.trailing, greaterThanOrEqualTo(150));
  });
}
