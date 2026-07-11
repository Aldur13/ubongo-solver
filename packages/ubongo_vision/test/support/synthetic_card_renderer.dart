import 'package:ubongo_core/ubongo_core.dart';
import 'package:ubongo_vision/src/rgb_image.dart';

/// Renders a synthetic "photo" of a puzzle card matching how real Ubongo
/// cards are actually printed and how board-outline detection actually
/// reads them: a plain, non-light background, with the puzzle outline
/// shown as a solid light-colored region — no grid is drawn outside the
/// outline, and (confirmed against real card photos: internal cell-
/// divider lines are printed too faint to survive binary light/dark
/// thresholding, merging into one solid connected region either way) no
/// internal lines are drawn between cells within the outline either.
/// Detection derives the grid pitch entirely from the outline region's
/// own boundary shape (its notches/steps), not from a separately-printed
/// grid — see `board_outline_detector.dart` and
/// `grid_geometry.dart#detectGridGeometryFromMask`. Test-only.
RgbImage renderSyntheticCard({
  required int gridWidth,
  required int gridHeight,
  required Set<CellCoord> outlineCells,
  int cellPixels = 40,
  int canvasMargin = 40,
  int? gridOffsetX,
  int? gridOffsetY,
  /// Extra light-colored rectangles elsewhere on the canvas, unconnected
  /// to the outline — tests that the largest-connected-component step
  /// correctly ignores a smaller stray light region.
  List<(int x, int y, int width, int height)> decoyLightPatches = const [],
}) {
  final offsetX = gridOffsetX ?? canvasMargin;
  final offsetY = gridOffsetY ?? canvasMargin;
  final canvasWidth = offsetX + gridWidth * cellPixels + canvasMargin;
  final canvasHeight = offsetY + gridHeight * cellPixels + canvasMargin;

  // A mid-tone, unambiguously non-light background -- distinct from the
  // light cell fill by more than any reasonable Otsu split point.
  final image = RgbImage.blank(canvasWidth, canvasHeight, r: 150, g: 90, b: 40);

  void fillRect(int left, int top, int width, int height) {
    for (var y = top; y < top + height; y++) {
      if (y < 0 || y >= canvasHeight) continue;
      for (var x = left; x < left + width; x++) {
        if (x < 0 || x >= canvasWidth) continue;
        image.setPixel(x, y, 235, 235, 235);
      }
    }
  }

  for (final cell in outlineCells) {
    fillRect(offsetX + cell.col * cellPixels, offsetY + cell.row * cellPixels, cellPixels, cellPixels);
  }

  for (final (x, y, width, height) in decoyLightPatches) {
    fillRect(x, y, width, height);
  }

  return image;
}
