import 'package:flutter_test/flutter_test.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

List<int> _spikesAt(int length, List<int> positions, {int spikeHeight = 20, int baseline = 1}) {
  final profile = List<int>.filled(length, baseline);
  for (final p in positions) {
    if (p >= 0 && p < length) profile[p] = spikeHeight;
  }
  return profile;
}

void main() {
  group('fitGridLines', () {
    test('resolves a clean evenly-spaced lattice', () {
      final profile = _spikesAt(100, [10, 30, 50, 70, 90]);
      final fit = fitGridLines(profile);
      expect(fit, isNotNull);
      expect(fit!.pitch, closeTo(20, 0.1));
      expect(fit.lineCount, 5);
      expect(fit.cellCount, 4);
    });

    test('reconstructs a missing (occluded) middle line from the others', () {
      final profile = _spikesAt(100, [10, 30, 70, 90]); // 50 is missing
      final fit = fitGridLines(profile);
      expect(fit, isNotNull);
      expect(fit!.pitch, closeTo(20, 0.1));
      expect(fit.lineCount, 5); // span/pitch reconstructs the missing line
      expect(fit.cellCount, 4);
    });

    test('returns null for a flat, featureless profile (no lines at all)', () {
      final profile = List<int>.filled(100, 5);
      expect(fitGridLines(profile), isNull);
    });

    test('returns null with fewer than 3 detected peaks', () {
      final profile = _spikesAt(100, [10, 30]);
      expect(fitGridLines(profile), isNull);
    });

    test('returns null for irregularly spaced peaks with no shared pitch', () {
      // A fixed-seed random point set (`Random(1).nextInt(500)` x15, deduped
      // and sorted) rather than a hand-picked one — hand-picked "irregular"
      // integers turned out to coincidentally satisfy some (pitch, origin)
      // lattice within tolerance surprisingly often (verified empirically:
      // several hand-picked attempts and even a few other random seeds
      // found spurious fits before the algorithm's line-density check was
      // added; this is the case that drove that fix).
      final profile = _spikesAt(
        500,
        [151, 169, 187, 204, 216, 234, 259, 263, 275, 281, 284, 295, 333, 337, 348],
      );
      expect(fitGridLines(profile), isNull);
    });
  });

  group('detectGridGeometry', () {
    test('detects rows and columns from a synthetic grid mask', () {
      const cellPitch = 15;
      const cols = 4;
      const rows = 3;
      const originX = 10;
      const originY = 10;
      final width = originX + cellPitch * cols + 10;
      final height = originY + cellPitch * rows + 10;

      final mask = Silhouette.filled(width, height, false);
      for (var i = 0; i <= cols; i++) {
        final x = originX + i * cellPitch;
        for (var y = originY; y <= originY + rows * cellPitch; y++) {
          mask.set(x, y, true);
        }
      }
      for (var i = 0; i <= rows; i++) {
        final y = originY + i * cellPitch;
        for (var x = originX; x <= originX + cols * cellPitch; x++) {
          mask.set(x, y, true);
        }
      }

      final geometry = detectGridGeometry(mask);

      expect(geometry, isNotNull);
      expect(geometry!.cols, cols);
      expect(geometry.rows, rows);
      expect(geometry.pitchX, closeTo(cellPitch, 0.5));
      expect(geometry.pitchY, closeTo(cellPitch, 0.5));
    });

    test('returns null for a mask with no grid-like structure', () {
      final mask = Silhouette.filled(50, 50, false);
      // A handful of scattered dots, not a grid.
      for (final (x, y) in [(5, 5), (40, 12), (22, 38)]) {
        mask.set(x, y, true);
      }
      expect(detectGridGeometry(mask), isNull);
    });
  });

  group('clusterBoundaryPositions', () {
    test('merges positions within tolerance into one cluster', () {
      final clusters = clusterBoundaryPositions([10.0, 10.5, 11.2, 50.0, 50.3], mergeTolerance: 3);

      expect(clusters, hasLength(2));
      expect(clusters[0].position, closeTo(10.57, 0.1));
      expect(clusters[0].weight, 3);
      expect(clusters[1].position, closeTo(50.15, 0.1));
      expect(clusters[1].weight, 2);
    });

    test('keeps positions farther apart than tolerance as separate clusters', () {
      final clusters = clusterBoundaryPositions([0.0, 10.0, 20.0], mergeTolerance: 3);
      expect(clusters.map((c) => c.position), [0.0, 10.0, 20.0]);
      expect(clusters.every((c) => c.weight == 1), isTrue);
    });

    test('empty input returns no clusters', () {
      expect(clusterBoundaryPositions(const []), isEmpty);
    });
  });

  group('detectGridGeometryFromMask', () {
    Silhouette maskOf(int width, int height, int cellPitch, int originX, int originY, Set<(int, int)> cells) {
      final mask = Silhouette.filled(width, height, false);
      for (final (row, col) in cells) {
        for (var y = originY + row * cellPitch; y < originY + (row + 1) * cellPitch; y++) {
          for (var x = originX + col * cellPitch; x < originX + (col + 1) * cellPitch; x++) {
            mask.set(x, y, true);
          }
        }
      }
      return mask;
    }

    test('recovers pitch and dimensions from an L-shaped filled region', () {
      const pitch = 20;
      const originX = 10;
      const originY = 10;
      // An L-shape within a 4x4 notional grid.
      final cells = {(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)};
      final mask = maskOf(120, 120, pitch, originX, originY, cells);

      final geometry = detectGridGeometryFromMask(mask);

      expect(geometry, isNotNull);
      expect(geometry!.pitchX, closeTo(pitch, 1));
      expect(geometry.pitchY, closeTo(pitch, 1));
    });

    test('returns null for a solid rectangle (no internal boundary structure to derive a pitch from)', () {
      const pitch = 20;
      final cells = {for (var r = 0; r < 3; r++) for (var col = 0; col < 3; col++) (r, col)};
      final mask = maskOf(120, 120, pitch, 10, 10, cells);

      expect(detectGridGeometryFromMask(mask), isNull);
    });

    test('returns null for an empty mask', () {
      expect(detectGridGeometryFromMask(Silhouette.filled(50, 50, false)), isNull);
    });
  });
}
