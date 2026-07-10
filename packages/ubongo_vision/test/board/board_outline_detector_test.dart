import 'package:flutter_test/flutter_test.dart';
import 'package:ubongo_core/ubongo_core.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

import '../support/synthetic_card_renderer.dart';

CellCoord c(int r, int col) => CellCoord(r, col);

void main() {
  group('detectBoardShape', () {
    test('recovers grid size and outline cells from a clean synthetic card', () async {
      final outline = {c(1, 1), c(2, 1), c(3, 1), c(3, 2), c(3, 3)}; // L-shape
      final image = renderSyntheticCard(gridWidth: 6, gridHeight: 6, outlineCells: outline);

      final result = await detectBoardShape(image);

      expect(result, isNotNull);
      expect(result!.width, 6);
      expect(result.height, 6);
      expect(result.cells, outline);
    });

    test('is robust to the grid being off-center on the card', () async {
      final outline = {c(0, 0), c(0, 1), c(1, 0)};
      final image = renderSyntheticCard(
        gridWidth: 4,
        gridHeight: 4,
        outlineCells: outline,
        gridOffsetX: 120,
        gridOffsetY: 200,
        canvasMargin: 60,
      );

      final result = await detectBoardShape(image);

      expect(result, isNotNull);
      expect(result!.width, 4);
      expect(result.height, 4);
      expect(result.cells, outline);
    });

    test('ignores a decoy ink blob outside the grid area', () async {
      final outline = {c(1, 1), c(1, 2), c(2, 1), c(2, 2)}; // 2x2 square
      final image = renderSyntheticCard(
        gridWidth: 5,
        gridHeight: 5,
        outlineCells: outline,
        decoyBlobs: const [(5, 5, 15)], // a blob in the margin, outside the grid
      );

      final result = await detectBoardShape(image);

      expect(result, isNotNull);
      expect(result!.width, 5);
      expect(result.height, 5);
      expect(result.cells, outline);
    });

    test('returns null for a photo with no grid-like structure', () async {
      final image = RgbImage.blank(300, 300);
      // A few scattered marks, not a grid or outline.
      image.setPixel(50, 50, 0, 0, 0);
      image.setPixel(200, 120, 0, 0, 0);

      final result = await detectBoardShape(image);

      expect(result, isNull);
    });
  });
}
