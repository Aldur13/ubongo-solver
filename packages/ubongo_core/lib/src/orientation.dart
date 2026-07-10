import 'cell_coord.dart';

/// One rotation/reflection orientation of a piece: a normalized cell-offset
/// set (minRow == 0, minCol == 0), plus its bounding-box height/width.
class Orientation {
  final List<CellCoord> offsets;
  final int height;
  final int width;

  Orientation._(this.offsets, this.height, this.width);

  static Orientation _fromCells(Set<CellCoord> cells) {
    final normalized = _normalize(cells);
    final sorted = normalized.toList()
      ..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
    final h = normalized.map((c) => c.row).reduce((a, b) => a > b ? a : b) + 1;
    final w = normalized.map((c) => c.col).reduce((a, b) => a > b ? a : b) + 1;
    return Orientation._(sorted, h, w);
  }

  String get _canonicalKey =>
      offsets.map((c) => '${c.row},${c.col}').join(';');
}

Set<CellCoord> _normalize(Set<CellCoord> cells) {
  final minRow = cells.map((c) => c.row).reduce((a, b) => a < b ? a : b);
  final minCol = cells.map((c) => c.col).reduce((a, b) => a < b ? a : b);
  return cells.map((c) => CellCoord(c.row - minRow, c.col - minCol)).toSet();
}

Set<CellCoord> _rotate90(Set<CellCoord> cells) =>
    cells.map((c) => CellCoord(c.col, -c.row)).toSet();

Set<CellCoord> _reflect(Set<CellCoord> cells) =>
    cells.map((c) => CellCoord(c.row, -c.col)).toSet();

/// Generates every distinct rotation (and, if [allowReflection], reflection)
/// of [baseCells], deduplicated by shape. A fully symmetric piece (e.g. a
/// square) yields 1 orientation; a fully asymmetric piece yields up to 8
/// (4 rotations x 2 reflections).
///
/// Reflection defaults to allowed: these are flat pieces placed on a table,
/// so physically flipping one over is legal. Set [allowReflection] to false
/// for a piece the physical set doesn't allow flipping (e.g. if one face is
/// blank/unprinted) once that's confirmed against the real pieces.
List<Orientation> generateOrientations(
  Set<CellCoord> baseCells, {
  bool allowReflection = true,
}) {
  final seenKeys = <String>{};
  final result = <Orientation>[];

  for (var reflected = 0; reflected < (allowReflection ? 2 : 1); reflected++) {
    var shape = reflected == 0 ? baseCells : _reflect(baseCells);
    for (var rot = 0; rot < 4; rot++) {
      final orientation = Orientation._fromCells(shape);
      if (seenKeys.add(orientation._canonicalKey)) {
        result.add(orientation);
      }
      shape = _rotate90(shape);
    }
  }
  return result;
}
