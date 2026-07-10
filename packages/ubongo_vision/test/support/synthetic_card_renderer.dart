import 'package:ubongo_core/ubongo_core.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

/// Renders a synthetic "photo" of a puzzle card: a light canvas, a thin
/// grid of lines at a known pitch/offset spanning `gridWidth x
/// gridHeight` cells, and a bold outline traced around [outlineCells]'
/// edges. Test-only — the mirror image of
/// `piece_catalog_renderer.dart`'s synthetic piece rendering (production
/// code), but for a whole board/card instead of a single piece.
RgbImage renderSyntheticCard({
  required int gridWidth,
  required int gridHeight,
  required Set<CellCoord> outlineCells,
  int cellPixels = 30,
  int canvasMargin = 40,
  int thinLineWidth = 1,
  int boldLineWidth = 5,
  int? gridOffsetX,
  int? gridOffsetY,
  List<(int x, int y, int size)> decoyBlobs = const [],
}) {
  final offsetX = gridOffsetX ?? canvasMargin;
  final offsetY = gridOffsetY ?? canvasMargin;
  final canvasWidth = offsetX + gridWidth * cellPixels + canvasMargin;
  final canvasHeight = offsetY + gridHeight * cellPixels + canvasMargin;

  final image = RgbImage.blank(canvasWidth, canvasHeight);

  void drawThickLine(int x0, int y0, int x1, int y1, int lineWidth) {
    final half = lineWidth ~/ 2;
    if (y0 == y1) {
      for (var x = x0; x <= x1; x++) {
        for (var dy = -half; dy <= half; dy++) {
          final y = y0 + dy;
          if (x >= 0 && x < canvasWidth && y >= 0 && y < canvasHeight) {
            image.setPixel(x, y, 0, 0, 0);
          }
        }
      }
    } else {
      for (var y = y0; y <= y1; y++) {
        for (var dx = -half; dx <= half; dx++) {
          final x = x0 + dx;
          if (x >= 0 && x < canvasWidth && y >= 0 && y < canvasHeight) {
            image.setPixel(x, y, 0, 0, 0);
          }
        }
      }
    }
  }

  for (var col = 0; col <= gridWidth; col++) {
    final x = offsetX + col * cellPixels;
    drawThickLine(x, offsetY, x, offsetY + gridHeight * cellPixels, thinLineWidth);
  }
  for (var row = 0; row <= gridHeight; row++) {
    final y = offsetY + row * cellPixels;
    drawThickLine(offsetX, y, offsetX + gridWidth * cellPixels, y, thinLineWidth);
  }

  // Bold outline: for each outline cell, draw a bold edge on every side
  // whose neighbor isn't also part of the outline (or is off-grid) — this
  // traces exactly the polyomino's boundary as one connected loop.
  for (final cell in outlineCells) {
    final left = offsetX + cell.col * cellPixels;
    final top = offsetY + cell.row * cellPixels;
    final right = left + cellPixels;
    final bottom = top + cellPixels;

    if (!outlineCells.contains(CellCoord(cell.row, cell.col - 1))) {
      drawThickLine(left, top, left, bottom, boldLineWidth);
    }
    if (!outlineCells.contains(CellCoord(cell.row, cell.col + 1))) {
      drawThickLine(right, top, right, bottom, boldLineWidth);
    }
    if (!outlineCells.contains(CellCoord(cell.row - 1, cell.col))) {
      drawThickLine(left, top, right, top, boldLineWidth);
    }
    if (!outlineCells.contains(CellCoord(cell.row + 1, cell.col))) {
      drawThickLine(left, bottom, right, bottom, boldLineWidth);
    }
  }

  for (final (x, y, size) in decoyBlobs) {
    for (var dy = 0; dy < size; dy++) {
      for (var dx = 0; dx < size; dx++) {
        final px = x + dx;
        final py = y + dy;
        if (px >= 0 && px < canvasWidth && py >= 0 && py < canvasHeight) {
          image.setPixel(px, py, 0, 0, 0);
        }
      }
    }
  }

  return image;
}
