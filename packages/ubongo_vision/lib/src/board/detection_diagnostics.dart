import 'package:ubongo_core/ubongo_core.dart';

import '../recognition/silhouette.dart';
import '../rgb_image.dart';
import 'detected_board_shape.dart';
import 'grid_geometry.dart';

/// Every intermediate value produced by `detectBoardShapeDebug` while
/// processing one photo, so a failed or wrong detection can be inspected
/// stage by stage (e.g. via `tool/inspect_card.dart`) instead of only ever
/// seeing the final null/wrong result.
///
/// Real cards print the puzzle outline as a light-colored region on a
/// plain (non-light) background, with no grid drawn outside it — so
/// [blob] (the largest connected light region) *is* the outline
/// directly, and [geometry] is expressed in [blob]'s own local pixel
/// coordinates (blob is already cropped to its own bounding box), not
/// [downscaled]'s.
class BoardDetectionDiagnostics {
  final RgbImage downscaled;

  /// Otsu-thresholded, light-pixels-as-foreground mask of the full
  /// [downscaled] photo (before isolating the largest component).
  final Silhouette lightMask;

  /// The largest connected component of [lightMask], cropped to its own
  /// bounding box — null if [lightMask] had no foreground pixels at all.
  final Silhouette? blob;

  final GridGeometry? geometry;

  /// Fill fraction (foreground / sampled pixels) for every candidate grid
  /// cell, not just the ones that ended up classified "inside" — lets a
  /// borderline cell right at the fill threshold be seen, not just the
  /// final yes/no.
  final Map<CellCoord, double> cellFillFractions;

  /// Set (non-null) at whichever stage caused detection to bail out with
  /// no shape; null when a shape was produced.
  final String? rejectionReason;

  const BoardDetectionDiagnostics({
    required this.downscaled,
    required this.lightMask,
    required this.blob,
    required this.geometry,
    required this.cellFillFractions,
    required this.rejectionReason,
  });
}

/// Pairs a `detectBoardShapeDebug` run's final output with every
/// intermediate value that produced it.
class BoardDetectionResult {
  final DetectedBoardShape? shape;
  final BoardDetectionDiagnostics diagnostics;

  const BoardDetectionResult({required this.shape, required this.diagnostics});
}
