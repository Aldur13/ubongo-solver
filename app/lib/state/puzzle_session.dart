import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubongo_core/ubongo_core.dart';

/// Everything needed to describe one puzzle-in-progress, plus its solved
/// result once `solve()` has run.
class PuzzleSessionState {
  final int gridWidth;
  final int gridHeight;
  final Set<CellCoord> boardCells;
  final List<PieceSlot> slots;
  final Solution? solution;
  final String? errorMessage;

  const PuzzleSessionState({
    this.gridWidth = 6,
    this.gridHeight = 6,
    this.boardCells = const {},
    this.slots = const [],
    this.solution,
    this.errorMessage,
  });

  PuzzleSessionState copyWith({
    int? gridWidth,
    int? gridHeight,
    Set<CellCoord>? boardCells,
    List<PieceSlot>? slots,
    Solution? solution,
    bool clearSolution = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PuzzleSessionState(
      gridWidth: gridWidth ?? this.gridWidth,
      gridHeight: gridHeight ?? this.gridHeight,
      boardCells: boardCells ?? this.boardCells,
      slots: slots ?? this.slots,
      solution: clearSolution ? null : (solution ?? this.solution),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PuzzleSessionNotifier extends Notifier<PuzzleSessionState> {
  @override
  PuzzleSessionState build() => const PuzzleSessionState();

  void reset() => state = const PuzzleSessionState();

  void setGridSize(int width, int height) {
    // Shrinking the grid can leave stale board cells out of bounds; drop
    // anything that no longer fits rather than crashing the Board model.
    final trimmed = state.boardCells
        .where((c) => c.row < height && c.col < width)
        .toSet();
    state = state.copyWith(
      gridWidth: width,
      gridHeight: height,
      boardCells: trimmed,
      clearSolution: true,
      clearError: true,
    );
  }

  void toggleCell(CellCoord cell) {
    final cells = Set<CellCoord>.from(state.boardCells);
    if (!cells.remove(cell)) cells.add(cell);
    state = state.copyWith(boardCells: cells, clearSolution: true, clearError: true);
  }

  void setBoardCells(Set<CellCoord> cells) {
    state = state.copyWith(boardCells: cells, clearSolution: true, clearError: true);
  }

  void clearBoard() {
    state = state.copyWith(boardCells: const {}, clearSolution: true, clearError: true);
  }

  void addSlot(PieceSlot slot) {
    state = state.copyWith(
      slots: [...state.slots, slot],
      clearSolution: true,
      clearError: true,
    );
  }

  void setSlots(List<PieceSlot> slots) {
    state = state.copyWith(slots: slots, clearSolution: true, clearError: true);
  }

  void removeSlotAt(int index) {
    final slots = List<PieceSlot>.from(state.slots)..removeAt(index);
    state = state.copyWith(slots: slots, clearSolution: true, clearError: true);
  }

  void solve() {
    if (state.boardCells.isEmpty) {
      state = state.copyWith(
        clearSolution: true,
        errorMessage: 'Mark at least one board cell before solving.',
      );
      return;
    }
    if (state.slots.isEmpty) {
      state = state.copyWith(
        clearSolution: true,
        errorMessage: 'Add at least one required piece before solving.',
      );
      return;
    }

    try {
      final board = Board(
        width: state.gridWidth,
        height: state.gridHeight,
        cells: state.boardCells,
      );
      final puzzle = Puzzle(
        board: board,
        slots: state.slots,
        catalog: UbongoCatalog.classic,
      );
      final solution = ExactCoverSolver(puzzle).solveFirst();
      if (solution == null) {
        state = state.copyWith(
          clearSolution: true,
          errorMessage: 'No solution found for this board and piece set.',
        );
      } else {
        state = state.copyWith(solution: solution, clearError: true);
      }
    } catch (e) {
      state = state.copyWith(clearSolution: true, errorMessage: e.toString());
    }
  }
}

final puzzleSessionProvider =
    NotifierProvider<PuzzleSessionNotifier, PuzzleSessionState>(
  PuzzleSessionNotifier.new,
);
