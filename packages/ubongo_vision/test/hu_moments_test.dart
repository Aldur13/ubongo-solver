import 'package:flutter_test/flutter_test.dart';
import 'package:ubongo_core/ubongo_core.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

void main() {
  group('Hu moments are rotation/reflection invariant', () {
    test('every orientation of an asymmetric piece has near-identical moments', () {
      // P10 is the placeholder L-pentomino — fully asymmetric, so it has
      // all 8 dihedral orientations, giving real rotated/reflected shapes
      // to compare (rendered via the same pipeline recognition uses, not
      // a hand-rolled pixel rotation that would introduce its own error).
      final piece = UbongoCatalog.classic.firstWhere((p) => p.id == 'P10');
      expect(piece.orientations.length, 8);

      final moments = piece.orientations
          .map((o) => computeHuMoments(renderCells(o.offsets.toSet())))
          .toList();

      for (var i = 1; i < moments.length; i++) {
        final distance = moments[0].distanceTo(moments[i]);
        expect(
          distance,
          lessThan(0.05),
          reason: 'orientation $i diverged from orientation 0 by $distance',
        );
      }
    });
  });

  group('Hu moments are scale invariant', () {
    test('the same shape rendered at different resolutions matches closely', () {
      final piece = UbongoCatalog.classic.firstWhere((p) => p.id == 'P11');
      final small = computeHuMoments(renderCells(piece.cells, pixelsPerCell: 8));
      final large = computeHuMoments(renderCells(piece.cells, pixelsPerCell: 40));

      expect(small.distanceTo(large), lessThan(0.05));
    });
  });

  group('Hu moments distinguish different shapes', () {
    test('two visually different pentominoes are far apart', () {
      final t = UbongoCatalog.classic.firstWhere((p) => p.id == 'P11'); // Y-ish
      final z = UbongoCatalog.classic.firstWhere((p) => p.id == 'P12'); // Z-ish
      final tMoments = computeHuMoments(renderCells(t.cells));
      final zMoments = computeHuMoments(renderCells(z.cells));

      expect(tMoments.distanceTo(zMoments), greaterThan(0.1));
    });

    test('an empty silhouette has all-zero moments and matches nothing well', () {
      final empty = Silhouette.filled(10, 10, false);
      final moments = computeHuMoments(empty);
      expect(moments.values, everyElement(0.0));
    });
  });
}
