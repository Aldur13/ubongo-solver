import 'package:test/test.dart';
import 'package:ubongo_core/ubongo_core.dart';

CellCoord c(int r, int col) => CellCoord(r, col);

/// The 12 standard pentominoes (public-domain polyomino math, independent
/// of Ubongo's own card graphics) used here purely as known-symmetry test
/// fixtures — their orientation counts under rotation+reflection are a
/// well-documented reference table, which makes them a strong regression
/// check for [generateOrientations].
final Map<String, Set<CellCoord>> _pentominoes = {
  'F': {c(0, 1), c(0, 2), c(1, 0), c(1, 1), c(2, 1)},
  'I': {c(0, 0), c(0, 1), c(0, 2), c(0, 3), c(0, 4)},
  'L': {c(0, 0), c(1, 0), c(2, 0), c(3, 0), c(3, 1)},
  'N': {c(0, 1), c(1, 1), c(2, 0), c(2, 1), c(3, 0)},
  'P': {c(0, 0), c(0, 1), c(1, 0), c(1, 1), c(2, 0)},
  'T': {c(0, 0), c(0, 1), c(0, 2), c(1, 1), c(2, 1)},
  'U': {c(0, 0), c(0, 2), c(1, 0), c(1, 1), c(1, 2)},
  'V': {c(0, 0), c(1, 0), c(2, 0), c(2, 1), c(2, 2)},
  'W': {c(0, 0), c(1, 0), c(1, 1), c(2, 1), c(2, 2)},
  'X': {c(0, 1), c(1, 0), c(1, 1), c(1, 2), c(2, 1)},
  'Y': {c(0, 1), c(1, 0), c(1, 1), c(2, 1), c(3, 1)},
  'Z': {c(0, 0), c(0, 1), c(1, 1), c(2, 1), c(2, 2)},
};

void main() {
  group('generateOrientations dedup counts', () {
    // Standard reference table for pentomino orientation counts (out of a
    // possible 8 = 4 rotations x 2 reflections).
    const expectedCounts = {
      'F': 8, 'I': 2, 'L': 8, 'N': 8, 'P': 8,
      'T': 4, 'U': 4, 'V': 4, 'W': 4, 'X': 1, 'Y': 8, 'Z': 4,
    };

    for (final entry in expectedCounts.entries) {
      test('${entry.key}-pentomino has ${entry.value} orientations', () {
        final orientations = generateOrientations(_pentominoes[entry.key]!);
        expect(orientations.length, entry.value);
      });
    }

    test('a monomino has exactly 1 orientation', () {
      expect(generateOrientations({c(0, 0)}).length, 1);
    });

    test('a domino has exactly 2 orientations (horizontal, vertical)', () {
      expect(generateOrientations({c(0, 0), c(0, 1)}).length, 2);
    });

    test('reflection disabled halves an asymmetric piece\'s orientations', () {
      final withReflection =
          generateOrientations(_pentominoes['F']!, allowReflection: true);
      final withoutReflection =
          generateOrientations(_pentominoes['F']!, allowReflection: false);
      expect(withReflection.length, 8);
      expect(withoutReflection.length, 4);
    });
  });

  group('generateOrientations correctness', () {
    test('every orientation is normalized to a zero origin', () {
      for (final orientation in generateOrientations(_pentominoes['N']!)) {
        final minRow = orientation.offsets.map((o) => o.row).reduce((a, b) => a < b ? a : b);
        final minCol = orientation.offsets.map((o) => o.col).reduce((a, b) => a < b ? a : b);
        expect(minRow, 0);
        expect(minCol, 0);
      }
    });

    test('every orientation preserves the original cell count', () {
      for (final orientation in generateOrientations(_pentominoes['W']!)) {
        expect(orientation.offsets.length, 5);
      }
    });

    test('height/width match the orientation\'s actual bounding box', () {
      for (final orientation in generateOrientations(_pentominoes['V']!)) {
        final maxRow = orientation.offsets.map((o) => o.row).reduce((a, b) => a > b ? a : b);
        final maxCol = orientation.offsets.map((o) => o.col).reduce((a, b) => a > b ? a : b);
        expect(orientation.height, maxRow + 1);
        expect(orientation.width, maxCol + 1);
      }
    });
  });
}
