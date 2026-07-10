import '../board.dart';
import '../cell_coord.dart';
import '../orientation.dart';
import '../piece.dart';

/// One piece placed to satisfy a specific puzzle slot.
class PlacedPiece {
  final int slotIndex;
  final Piece piece;
  final Orientation orientation;
  final CellCoord anchor;
  final Set<CellCoord> cells;

  PlacedPiece({
    required this.slotIndex,
    required this.piece,
    required this.orientation,
    required this.anchor,
  }) : cells = orientation.offsets
            .map((o) => CellCoord(anchor.row + o.row, anchor.col + o.col))
            .toSet();
}

/// A complete, self-consistent placement of one piece per slot.
class Solution {
  final List<PlacedPiece> placements;
  const Solution(this.placements);
}

/// Independently re-checks a [Solution] against its [Puzzle] from scratch:
/// every board cell covered exactly once by exactly one placement, no
/// placement extends outside the board, and every placement satisfies its
/// slot (the exact piece for a [SolidSlot], the right cell count for a
/// [GraySlot]). Used so tests (and runtime callers) verify the solver
/// produced a *correct* answer, not just *an* answer.
bool validateSolution(Puzzle puzzle, Solution solution) {
  if (solution.placements.length != puzzle.slots.length) return false;

  final coveredBySlot = <int, PlacedPiece>{};
  final coveredCells = <CellCoord>{};

  for (final placed in solution.placements) {
    if (coveredBySlot.containsKey(placed.slotIndex)) return false;
    coveredBySlot[placed.slotIndex] = placed;

    if (placed.slotIndex < 0 || placed.slotIndex >= puzzle.slots.length) {
      return false;
    }
    final slot = puzzle.slots[placed.slotIndex];
    switch (slot) {
      case SolidSlot(:final piece):
        if (placed.piece.id != piece.id) return false;
      case GraySlot(:final cellCount):
        if (placed.piece.cellCount != cellCount) return false;
    }

    if (placed.cells.length != placed.piece.cellCount) return false;

    for (final cell in placed.cells) {
      if (!puzzle.board.contains(cell)) return false;
      if (!coveredCells.add(cell)) return false; // overlap
    }
  }

  if (coveredBySlot.length != puzzle.slots.length) return false;
  if (coveredCells.length != puzzle.board.cellCount) return false;
  return coveredCells.containsAll(puzzle.board.cells);
}
