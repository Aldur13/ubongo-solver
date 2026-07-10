import 'package:ubongo_core/ubongo_core.dart';

import 'silhouette.dart';

/// Renders each catalog piece's canonical (unrotated, unreflected) shape
/// into a [Silhouette] at a fixed pixels-per-cell resolution.
///
/// Only one orientation per piece is needed here: Hu moments (see
/// `hu_moments.dart`) are rotation-invariant, so a candidate icon at any
/// angle should match its piece's single reference silhouette without
/// enumerating all 8 dihedral orientations the way the solver's placement
/// search needs to.
class PieceCatalogRenderer {
  final int pixelsPerCell;
  final Map<String, Silhouette> _cache = {};

  PieceCatalogRenderer({this.pixelsPerCell = 20});

  Silhouette render(Piece piece) => _cache.putIfAbsent(
      piece.id, () => renderCells(piece.cells, pixelsPerCell: pixelsPerCell));

  Map<String, Silhouette> renderAll(List<Piece> pieces) => {
        for (final piece in pieces) piece.id: render(piece),
      };
}

/// Rasterizes an arbitrary cell-offset shape (e.g. one specific
/// [Orientation] of a piece, not just a piece's own canonical shape) into
/// a [Silhouette] at [pixelsPerCell] resolution. Exposed separately from
/// [PieceCatalogRenderer.render] so tests (and any future code needing a
/// specific orientation rendered) don't have to reconstruct a whole
/// [Piece] just to rasterize a shape.
Silhouette renderCells(Set<CellCoord> cells, {int pixelsPerCell = 20}) =>
    _renderShape(cells, pixelsPerCell);

Silhouette _renderShape(Set<CellCoord> cells, int pixelsPerCell) {
  final minRow = cells.map((c) => c.row).reduce((a, b) => a < b ? a : b);
  final minCol = cells.map((c) => c.col).reduce((a, b) => a < b ? a : b);
  final maxRow = cells.map((c) => c.row).reduce((a, b) => a > b ? a : b);
  final maxCol = cells.map((c) => c.col).reduce((a, b) => a > b ? a : b);

  final rows = maxRow - minRow + 1;
  final cols = maxCol - minCol + 1;
  final mask = Silhouette.filled(cols * pixelsPerCell, rows * pixelsPerCell, false);

  for (final cell in cells) {
    final r = cell.row - minRow;
    final c = cell.col - minCol;
    for (var y = r * pixelsPerCell; y < (r + 1) * pixelsPerCell; y++) {
      for (var x = c * pixelsPerCell; x < (c + 1) * pixelsPerCell; x++) {
        mask.set(x, y, true);
      }
    }
  }
  return mask;
}
