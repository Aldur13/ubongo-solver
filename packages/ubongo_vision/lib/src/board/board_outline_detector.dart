import 'package:ubongo_core/ubongo_core.dart';

import '../recognition/silhouette.dart';
import '../rgb_image.dart';
import 'detected_board_shape.dart';
import 'detection_params.dart';
import 'grid_geometry.dart';

/// Every later pass here is a pixel loop; downscaling first keeps the
/// whole pipeline fast on a real phone photo. Exact pixel precision isn't
/// needed for grid-line detection at this stage.
const maxBoardAnalysisDimension = 800;

/// Grid/board dimensions this small a detection is trusted for — outside
/// this range almost certainly means grid-geometry detection latched onto
/// something that isn't a real Ubongo-sized board.
const _minGridCells = 2;
const _maxGridCells = 12;

/// Detects a puzzle board's outline and grid dimensions from a
/// perspective-corrected card photo.
///
/// Top-level (not a closure) so it's callable via `compute()`/
/// `Isolate.run` from the app layer, keeping this function's pixel-loop
/// work off the UI isolate. Returns null when detection isn't reliable
/// (see `grid_geometry.dart`'s `fitGridLines`) rather than guessing — the
/// caller's fallback is simply to leave the board-outline UI in its
/// existing fully-manual state.
///
/// Pipeline: downscale -> threshold into an ink mask -> detect grid
/// geometry from row/column ink projections -> morphologically open the
/// ink mask to isolate the bold outline from thin grid lines -> fill the
/// outline's enclosed interior -> classify each candidate cell
/// inside/outside by sampling its (boundary-inset) interior against the
/// filled mask.
Future<DetectedBoardShape?> detectBoardShape(
  RgbImage image, {
  DetectionParams params = const DetectionParams(),
}) async {
  final downscaled = image.downscaled(maxDimension: maxBoardAnalysisDimension);
  final inkMask = Silhouette.threshold(downscaled);

  final geometry = detectGridGeometry(inkMask);
  if (geometry == null) return null;
  if (geometry.cols < _minGridCells ||
      geometry.cols > _maxGridCells ||
      geometry.rows < _minGridCells ||
      geometry.rows > _maxGridCells) {
    return null;
  }

  final averagePitch = (geometry.pitchX + geometry.pitchY) / 2;
  final erosionRadius = (averagePitch * params.erosionRadiusScale).round().clamp(1, 3);
  final outlineOnly = inkMask.opened(erosionRadius);
  final filled = outlineOnly.fillEnclosedHoles();

  final cells = <CellCoord>{};
  for (var row = 0; row < geometry.rows; row++) {
    for (var col = 0; col < geometry.cols; col++) {
      final left = geometry.originX + col * geometry.pitchX;
      final top = geometry.originY + row * geometry.pitchY;
      if (_isCellInside(filled, left, top, geometry.pitchX, geometry.pitchY, params.fillThreshold)) {
        cells.add(CellCoord(row, col));
      }
    }
  }

  if (cells.isEmpty) return null;
  return DetectedBoardShape(width: geometry.cols, height: geometry.rows, cells: cells);
}

/// Samples only the central 60% of a cell's pixel rectangle (inset ~20%
/// per side), away from the boundary line itself — the bold outline sits
/// *on* cell edges, so sampling right up to the edge would let a
/// neighboring cell's boundary ink bias this cell's fraction upward.
bool _isCellInside(
  Silhouette mask,
  double left,
  double top,
  double pitchX,
  double pitchY,
  double fillThreshold,
) {
  const inset = 0.2;
  final x0 = (left + pitchX * inset).round();
  final x1 = (left + pitchX * (1 - inset)).round();
  final y0 = (top + pitchY * inset).round();
  final y1 = (top + pitchY * (1 - inset)).round();

  var foreground = 0;
  var total = 0;
  for (var y = y0; y < y1; y++) {
    if (y < 0 || y >= mask.height) continue;
    for (var x = x0; x < x1; x++) {
      if (x < 0 || x >= mask.width) continue;
      total++;
      if (mask.at(x, y)) foreground++;
    }
  }
  if (total == 0) return false;
  return foreground / total > fillThreshold;
}
