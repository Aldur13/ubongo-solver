import '../board.dart';
import '../cell_coord.dart';
import '../orientation.dart';
import '../piece.dart';
import 'solution.dart';

/// One candidate way to fill a single slot: a specific piece, in a specific
/// orientation, anchored at a specific board offset.
class _Candidate {
  final int slotIndex;
  final Piece piece;
  final Orientation orientation;
  final CellCoord anchor;
  final Set<CellCoord> cells;
  final int columnMask;

  _Candidate({
    required this.slotIndex,
    required this.piece,
    required this.orientation,
    required this.anchor,
    required this.cells,
    required this.columnMask,
  });
}

/// Exact-cover solver for Ubongo-style puzzles: fill every board cell
/// exactly once, with exactly one piece placement per slot.
///
/// Implemented as Algorithm X (Knuth's "Dancing Links" search strategy —
/// always branch on the least-constrained remaining column, i.e. the one
/// with the fewest candidate rows, so unsolvable branches die fast) using
/// plain integer bitmasks for the covered-columns state rather than a
/// literal doubly-linked "dancing links" node structure. For the small
/// column counts an Ubongo card produces (a handful of slots plus at most a
/// few dozen board cells, always well under 64 bits) this is equivalent in
/// behavior and pruning power to classic DLX, and considerably simpler to
/// read and get right than hand-rolled quadruply-linked list bookkeeping.
class ExactCoverSolver {
  final Puzzle puzzle;

  late final List<CellCoord> _orderedCells;
  late final Map<CellCoord, int> _cellColumn;
  late final int _numColumns;
  late final int _fullColumnMask;
  late final List<_Candidate> _allCandidates;
  late final List<List<int>> _columnToCandidateIndices;

  ExactCoverSolver(this.puzzle) {
    _orderedCells = puzzle.board.cells.toList()
      ..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
    _cellColumn = {
      for (var i = 0; i < _orderedCells.length; i++)
        _orderedCells[i]: puzzle.slots.length + i,
    };
    _numColumns = puzzle.slots.length + _orderedCells.length;
    if (_numColumns > 62) {
      throw UnsupportedError(
        'Puzzle has $_numColumns columns; this solver assumes it fits in a '
        '64-bit bitmask (Ubongo cards never come close to this).',
      );
    }
    _fullColumnMask = _numColumns == 64
        ? ~0
        : (1 << _numColumns) - 1;

    _allCandidates = _buildCandidates();
    _columnToCandidateIndices = List.generate(_numColumns, (_) => <int>[]);
    for (var i = 0; i < _allCandidates.length; i++) {
      final mask = _allCandidates[i].columnMask;
      for (var col = 0; col < _numColumns; col++) {
        if ((mask >> col) & 1 == 1) {
          _columnToCandidateIndices[col].add(i);
        }
      }
    }
  }

  List<_Candidate> _buildCandidates() {
    final candidates = <_Candidate>[];
    for (var slotIndex = 0; slotIndex < puzzle.slots.length; slotIndex++) {
      final slot = puzzle.slots[slotIndex];
      for (final piece in puzzle.candidatesFor(slot)) {
        for (final orientation in piece.orientations) {
          for (var dr = 0; dr <= puzzle.board.height - orientation.height; dr++) {
            for (var dc = 0; dc <= puzzle.board.width - orientation.width; dc++) {
              final anchor = CellCoord(dr, dc);
              final cells = orientation.offsets
                  .map((o) => CellCoord(dr + o.row, dc + o.col))
                  .toSet();
              if (!cells.every(puzzle.board.contains)) continue;

              var mask = 1 << slotIndex;
              for (final cell in cells) {
                mask |= 1 << _cellColumn[cell]!;
              }
              candidates.add(_Candidate(
                slotIndex: slotIndex,
                piece: piece,
                orientation: orientation,
                anchor: anchor,
                cells: cells,
                columnMask: mask,
              ));
            }
          }
        }
      }
    }
    return candidates;
  }

  /// Finds every valid solution, stopping early once [maxSolutions] are
  /// found (pass null to find all of them).
  List<Solution> solveAll({int? maxSolutions}) {
    final solutions = <Solution>[];
    _search(0, [], solutions, maxSolutions);
    return solutions;
  }

  /// Finds one valid solution, or null if the puzzle is unsolvable.
  Solution? solveFirst() {
    final found = solveAll(maxSolutions: 1);
    return found.isEmpty ? null : found.first;
  }

  void _search(
    int coveredMask,
    List<_Candidate> chosen,
    List<Solution> solutions,
    int? maxSolutions,
  ) {
    if (maxSolutions != null && solutions.length >= maxSolutions) return;

    if (coveredMask == _fullColumnMask) {
      solutions.add(Solution(chosen
          .map((c) => PlacedPiece(
                slotIndex: c.slotIndex,
                piece: c.piece,
                orientation: c.orientation,
                anchor: c.anchor,
              ))
          .toList()));
      return;
    }

    final col = _chooseColumn(coveredMask);
    if (col == null) return;

    for (final idx in _columnToCandidateIndices[col]) {
      final candidate = _allCandidates[idx];
      if (candidate.columnMask & coveredMask != 0) continue;

      chosen.add(candidate);
      _search(coveredMask | candidate.columnMask, chosen, solutions, maxSolutions);
      chosen.removeLast();

      if (maxSolutions != null && solutions.length >= maxSolutions) return;
    }
  }

  /// Picks the uncovered column with the fewest still-valid candidates
  /// (Knuth's "S heuristic"). Returns null only when every column is
  /// already covered (the caller checks that case first).
  int? _chooseColumn(int coveredMask) {
    int? best;
    var bestCount = 1 << 30;
    for (var col = 0; col < _numColumns; col++) {
      if ((coveredMask >> col) & 1 == 1) continue;
      var count = 0;
      for (final idx in _columnToCandidateIndices[col]) {
        if (_allCandidates[idx].columnMask & coveredMask == 0) count++;
      }
      if (count == 0) return col; // dead end: forces immediate backtrack
      if (count < bestCount) {
        bestCount = count;
        best = col;
      }
    }
    return best;
  }
}
