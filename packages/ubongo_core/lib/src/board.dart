import 'cell_coord.dart';
import 'piece.dart';

/// The playable region of a puzzle card: a bounding box (width x height)
/// plus the subset of cells actually inside the puzzle's outline.
class Board {
  final int width;
  final int height;
  final Set<CellCoord> cells;

  Board({required this.width, required this.height, required this.cells}) {
    for (final c in cells) {
      if (c.row < 0 || c.row >= height || c.col < 0 || c.col >= width) {
        throw ArgumentError(
          'Cell $c is outside the ${width}x$height bounding box',
        );
      }
    }
  }

  bool contains(CellCoord c) => cells.contains(c);

  int get cellCount => cells.length;
}

/// A puzzle-card requirement for one piece placement: either a specific
/// piece ("solid" on the card), or any catalog piece with a matching cell
/// count ("gray"/outline-only on the card).
sealed class PieceSlot {
  const PieceSlot();
}

class SolidSlot extends PieceSlot {
  final Piece piece;
  const SolidSlot(this.piece);
}

class GraySlot extends PieceSlot {
  final int cellCount;
  const GraySlot(this.cellCount);
}

/// A fully-specified puzzle: the board to fill, the slots that must each be
/// satisfied by exactly one piece placement, and the catalog of pieces
/// available to resolve [GraySlot] candidates against.
class Puzzle {
  final Board board;
  final List<PieceSlot> slots;
  final List<Piece> catalog;

  const Puzzle({
    required this.board,
    required this.slots,
    required this.catalog,
  });

  /// Candidate pieces for a given slot: the slot's own piece for a
  /// [SolidSlot], or every catalog piece matching [GraySlot.cellCount] that
  /// isn't already pinned to a [SolidSlot] elsewhere on the same card.
  List<Piece> candidatesFor(PieceSlot slot) {
    switch (slot) {
      case SolidSlot(:final piece):
        return [piece];
      case GraySlot(:final cellCount):
        final pinnedIds = slots
            .whereType<SolidSlot>()
            .map((s) => s.piece.id)
            .toSet();
        return catalog
            .where((p) => p.cellCount == cellCount && !pinnedIds.contains(p.id))
            .toList();
    }
  }
}
