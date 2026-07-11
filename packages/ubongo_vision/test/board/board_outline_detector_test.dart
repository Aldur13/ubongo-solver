import 'package:flutter_test/flutter_test.dart';
import 'package:ubongo_core/ubongo_core.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

import '../support/synthetic_card_renderer.dart';

CellCoord c(int r, int col) => CellCoord(r, col);

/// Detection derives grid geometry from the outline blob's own (tightly
/// cropped) bounding box, so its output is always the outline's tight
/// bounding-box size with cells re-indexed to start at (0,0) — not
/// whatever nominal canvas grid size the outline happened to be drawn
/// within. Tests build their expected result from the same absolute
/// [outlineCells] passed to the renderer via this helper, rather than
/// hand-computing the tight/local form (and risking an arithmetic slip).
({int width, int height, Set<CellCoord> cells}) _tightBoundingBox(Set<CellCoord> outlineCells) {
  final minRow = outlineCells.map((c) => c.row).reduce((a, b) => a < b ? a : b);
  final minCol = outlineCells.map((c) => c.col).reduce((a, b) => a < b ? a : b);
  final maxRow = outlineCells.map((c) => c.row).reduce((a, b) => a > b ? a : b);
  final maxCol = outlineCells.map((c) => c.col).reduce((a, b) => a > b ? a : b);
  return (
    width: maxCol - minCol + 1,
    height: maxRow - minRow + 1,
    cells: outlineCells.map((c) => CellCoord(c.row - minRow, c.col - minCol)).toSet(),
  );
}

void main() {
  group('detectBoardShape', () {
    test('recovers the outline shape from a clean synthetic card', () async {
      final outline = {c(1, 1), c(2, 1), c(3, 1), c(3, 2), c(3, 3)}; // L-shape
      final image = renderSyntheticCard(gridWidth: 6, gridHeight: 6, outlineCells: outline);
      final expected = _tightBoundingBox(outline);

      final result = await detectBoardShape(image);

      expect(result, isNotNull);
      expect(result!.width, expected.width);
      expect(result.height, expected.height);
      expect(result.cells, expected.cells);
    });

    test('is robust to the outline being off-center on the card', () async {
      final outline = {c(0, 0), c(0, 1), c(1, 0)};
      final image = renderSyntheticCard(
        gridWidth: 4,
        gridHeight: 4,
        outlineCells: outline,
        gridOffsetX: 120,
        gridOffsetY: 200,
        canvasMargin: 60,
      );
      final expected = _tightBoundingBox(outline);

      final result = await detectBoardShape(image);

      expect(result, isNotNull);
      expect(result!.width, expected.width);
      expect(result.height, expected.height);
      expect(result.cells, expected.cells);
    });

    test('ignores a smaller disconnected decoy light patch elsewhere on the card', () async {
      final outline = {c(1, 1), c(1, 2), c(2, 1), c(2, 2), c(1, 3)}; // P-ish shape, 5 cells
      final image = renderSyntheticCard(
        gridWidth: 6,
        gridHeight: 6,
        outlineCells: outline,
        // A small stray light rectangle far from the outline -- smaller
        // than the outline's own connected region, so it must lose the
        // largest-component selection.
        decoyLightPatches: const [(5, 5, 20, 20)],
      );
      final expected = _tightBoundingBox(outline);

      final result = await detectBoardShape(image);

      expect(result, isNotNull);
      expect(result!.width, expected.width);
      expect(result.height, expected.height);
      expect(result.cells, expected.cells);
    });

    test('returns null for a photo with no light-colored board region at all', () async {
      final image = RgbImage.blank(300, 300, r: 150, g: 90, b: 40);

      final result = await detectBoardShape(image);

      expect(result, isNull);
    });

    test('returns null for a solid rectangular outline with no boundary notches', () async {
      // A plain filled rectangle has no internal step/notch structure for
      // detectGridGeometryFromMask to derive a pitch from -- a known
      // limitation of deriving the lattice purely from the outline's own
      // boundary shape (see grid_geometry.dart#detectGridGeometryFromMask).
      final outline = {for (var r = 0; r < 3; r++) for (var col = 0; col < 3; col++) c(r, col)};
      final image = renderSyntheticCard(gridWidth: 3, gridHeight: 3, outlineCells: outline);

      final result = await detectBoardShape(image);

      expect(result, isNull);
    });
  });
}
