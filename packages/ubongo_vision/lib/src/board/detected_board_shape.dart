import 'package:ubongo_core/ubongo_core.dart';

/// The outcome of automatically detecting a puzzle board's outline from a
/// photo: its grid dimensions and which cells are inside the outline.
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

  const DetectedBoardShape({
    required this.width,
    required this.height,
    required this.cells,
  });
}
