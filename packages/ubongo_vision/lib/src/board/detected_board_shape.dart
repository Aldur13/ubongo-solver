import 'package:ubongo_core/ubongo_core.dart';

/// An axis-aligned rectangle in normalized (0-1) fractions of some image's
/// dimensions — resolution-independent (detection runs on a downscaled
/// copy, the app displays the full-resolution photo) and isolate-safe
/// (plain doubles, no dart:ui dependency in this pure-Dart package).
class NormalizedRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const NormalizedRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// The whole image.
  static const full = NormalizedRect(left: 0, top: 0, width: 1, height: 1);
}

/// The outcome of automatically detecting a puzzle board's outline from a
/// photo: its grid dimensions, which cells are inside the outline, and
/// where the detected grid sits within the photo.
///
/// This is deliberately a separate type from `ubongo_core`'s
/// `BoardShapeSource` rather than an implementation of it —
/// `BoardShapeSource` resolves cells given *already-known* dimensions
/// (what the manual tap-correction UI does), whereas detection solves the
/// inverse problem: dimensions are an output here, not an input.
class DetectedBoardShape {
  final int width;
  final int height;
  final Set<CellCoord> cells;

  /// Where the detected `width x height` grid sits within the source
  /// photo, as fractions of the photo's dimensions — exactly the lattice
  /// area cell classification sampled, so a UI that crops the photo to
  /// this rect and overlays a `width x height` grid on the crop shows
  /// each cell of [cells] over the printed square it was judged from.
  /// Defaults to the whole photo for compatibility with callers that
  /// don't know it (e.g. hand-built test fixtures).
  final NormalizedRect boardRegion;

  const DetectedBoardShape({
    required this.width,
    required this.height,
    required this.cells,
    this.boardRegion = NormalizedRect.full,
  });
}
