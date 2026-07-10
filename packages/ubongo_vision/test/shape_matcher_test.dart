import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ubongo_core/ubongo_core.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

void main() {
  final matcher = ShapeMatcher(catalog: UbongoCatalog.classic);

  test('matches every catalog piece to itself, in a random orientation', () {
    final rng = Random(7);
    for (final piece in UbongoCatalog.classic) {
      final orientation = piece.orientations[rng.nextInt(piece.orientations.length)];
      final candidate = renderCells(orientation.offsets.toSet());

      final best = matcher.bestMatch(candidate);

      expect(
        best.piece.id,
        piece.id,
        reason: '${piece.id} (${piece.name}) misrecognized as ${best.piece.id}',
      );
    }
  });

  test('ranks the true match strictly ahead of every other catalog piece', () {
    final p9 = UbongoCatalog.classic.firstWhere((p) => p.id == 'P9');
    final ranked = matcher.rankMatches(renderCells(p9.cells));

    expect(ranked.first.piece.id, 'P9');
    expect(ranked.first.distance, lessThan(ranked[1].distance));
  });

  test('a slightly noisy candidate (stray specks) still matches correctly '
      'once the largest component is isolated', () {
    final p12 = UbongoCatalog.classic.firstWhere((p) => p.id == 'P12');
    final mask = renderCells(p12.cells, pixelsPerCell: 20);

    // Simulate a photo artifact: a few stray foreground pixels far from
    // the real shape, disconnected from it.
    final noisy = Silhouette.filled(mask.width + 10, mask.height + 10, false);
    for (var y = 0; y < mask.height; y++) {
      for (var x = 0; x < mask.width; x++) {
        if (mask.at(x, y)) noisy.set(x, y, true);
      }
    }
    noisy.set(noisy.width - 1, noisy.height - 1, true);
    noisy.set(noisy.width - 2, noisy.height - 1, true);

    final cleaned = noisy.largestComponentCropped();
    expect(matcher.bestMatch(cleaned).piece.id, 'P12');
  });
}
