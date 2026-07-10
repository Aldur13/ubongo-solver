/// An integer (row, col) grid coordinate, used both for board cells and
/// for piece-shape offsets.
class CellCoord {
  final int row;
  final int col;

  const CellCoord(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is CellCoord && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}
