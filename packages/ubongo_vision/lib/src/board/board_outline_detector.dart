import 'package:ubongo_core/ubongo_core.dart';

import '../recognition/silhouette.dart';
import '../rgb_image.dart';
import 'detected_board_shape.dart';
import 'detection_diagnostics.dart';
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
/// rather than guessing — the caller's fallback is simply to leave the
/// board-outline UI in its existing fully-manual state.
///
/// Real Ubongo cards print the puzzle outline as a light-colored
/// polyomino region directly on a plain (non-light) background, with the
/// grid lines dividing its cells drawn only inside that region — there's
/// no separately-printed full-card grid to isolate a "bold outline" from
/// (an earlier version of this pipeline assumed one; real card photos
/// gathered during testing showed that assumption was simply wrong).
/// Pipeline: downscale -> Otsu-threshold light pixels as foreground ->
/// take the largest connected light region (the outline itself) ->
/// derive the grid lattice from that region's own boundary shape -> for
/// each candidate cell, classify inside/outside by how much of its
/// (boundary-inset) interior the region covers.
///
/// This is a thin wrapper around `detectBoardShapeDebug` — kept as its own
/// function (rather than inlining `.shape` at every call site) so the
/// production/`compute()` contract (this exact signature, `RgbImage` in,
/// `DetectedBoardShape?` out) can never drift from what the debug path
/// actually computes.
Future<DetectedBoardShape?> detectBoardShape(
  RgbImage image, {
  DetectionParams params = const DetectionParams(),
}) async => (await detectBoardShapeDebug(image, params: params)).shape;

/// Same detection pipeline as [detectBoardShape], but returns every
/// intermediate value alongside the result (see
/// [BoardDetectionDiagnostics]) and a human-readable reason at whichever
/// stage caused a null result, instead of just null. Used by
/// `tool/inspect_card.dart` and `tool/tune_params.dart` — production code
/// should keep using [detectBoardShape].
Future<BoardDetectionResult> detectBoardShapeDebug(
  RgbImage image, {
  DetectionParams params = const DetectionParams(),
}) async {
  final downscaled = image.downscaled(maxDimension: maxBoardAnalysisDimension);
  // Light AND near-neutral -- rejects the saturated orange background and
  // colored piece icons that plain luminance thresholding can (on some
  // photos) misclassify alongside the actual light-gray board cells; see
  // Silhouette.lightNeutralRegion's doc comment for what real-photo
  // evidence drove this.
  final lightMask = Silhouette.lightNeutralRegion(downscaled);
  final (mask: blob, offsetX: blobOffsetX, offsetY: blobOffsetY) =
      lightMask.largestComponentWithOffset();

  BoardDetectionResult reject(
    String reason, {
    Silhouette? blob,
    GridGeometry? geometry,
    Map<CellCoord, double> cellFillFractions = const {},
  }) => BoardDetectionResult(
    shape: null,
    diagnostics: BoardDetectionDiagnostics(
      downscaled: downscaled,
      lightMask: lightMask,
      blob: blob,
      geometry: geometry,
      cellFillFractions: cellFillFractions,
      rejectionReason: reason,
    ),
  );

  if (blob.foregroundCount == 0) {
    return reject('no light-colored board region found in the photo');
  }

  final geometry = detectGridGeometryFromMask(blob);
  if (geometry == null) {
    return reject('no reliable grid lattice found on one or both axes', blob: blob);
  }
  if (geometry.cols < _minGridCells ||
      geometry.cols > _maxGridCells ||
      geometry.rows < _minGridCells ||
      geometry.rows > _maxGridCells) {
    return reject(
      'detected grid ${geometry.cols}x${geometry.rows} outside trusted '
      'range [$_minGridCells, $_maxGridCells] cells per axis',
      blob: blob,
      geometry: geometry,
    );
  }

  final cells = <CellCoord>{};
  final fillFractions = <CellCoord, double>{};
  for (var row = 0; row < geometry.rows; row++) {
    for (var col = 0; col < geometry.cols; col++) {
      final left = geometry.originX + col * geometry.pitchX;
      final top = geometry.originY + row * geometry.pitchY;
      final fraction = _cellFillFraction(blob, left, top, geometry.pitchX, geometry.pitchY);
      final coord = CellCoord(row, col);
      fillFractions[coord] = fraction;
      if (fraction > params.fillThreshold) cells.add(coord);
    }
  }

  if (cells.isEmpty) {
    return reject(
      'no candidate cell exceeded the fill threshold (${params.fillThreshold})',
      blob: blob,
      geometry: geometry,
      cellFillFractions: fillFractions,
    );
  }

  // The lattice's coordinates are local to the cropped blob; add the
  // blob's offset within the (downscaled) photo, then normalize by the
  // photo's dimensions so the region is resolution-independent — the app
  // applies it to the full-resolution photo.
  final boardRegion = NormalizedRect(
    left: ((blobOffsetX + geometry.originX) / downscaled.width).clamp(0.0, 1.0),
    top: ((blobOffsetY + geometry.originY) / downscaled.height).clamp(0.0, 1.0),
    width: (geometry.cols * geometry.pitchX / downscaled.width).clamp(0.0, 1.0),
    height: (geometry.rows * geometry.pitchY / downscaled.height).clamp(0.0, 1.0),
  );

  return BoardDetectionResult(
    shape: DetectedBoardShape(
      width: geometry.cols,
      height: geometry.rows,
      cells: cells,
      boardRegion: boardRegion,
    ),
    diagnostics: BoardDetectionDiagnostics(
      downscaled: downscaled,
      lightMask: lightMask,
      blob: blob,
      geometry: geometry,
      cellFillFractions: fillFractions,
      rejectionReason: null,
    ),
  );
}

/// Samples only the central 60% of a cell's pixel rectangle (inset ~20%
/// per side), away from the boundary line itself — the outline region's
/// own edge sits *on* cell boundaries, so sampling right up to the edge
/// would let a neighboring cell's status bias this cell's fraction.
/// Returns the raw foreground fraction (0 if nothing was in-bounds to
/// sample) rather than a yes/no, so callers can both threshold it and
/// report it as a diagnostic.
double _cellFillFraction(
  Silhouette mask,
  double left,
  double top,
  double pitchX,
  double pitchY,
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
  if (total == 0) return 0;
  return foreground / total;
}
