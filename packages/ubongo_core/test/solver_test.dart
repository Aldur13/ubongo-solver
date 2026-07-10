import 'package:test/test.dart';
import 'package:ubongo_core/ubongo_core.dart';

CellCoord c(int r, int col) => CellCoord(r, col);

Piece _byId(String id) => UbongoCatalog.classic.firstWhere((p) => p.id == id);

void main() {
  group('known solvable puzzles', () {
    test('a 2x2 board is solved by the square tetromino alone', () {
      final square = _byId('P4'); // 2x2 square, cells (0,0)(0,1)(1,0)(1,1)
      final board = Board(
        width: 2,
        height: 2,
        cells: {c(0, 0), c(0, 1), c(1, 0), c(1, 1)},
      );
      final puzzle = Puzzle(
        board: board,
        slots: [SolidSlot(square)],
        catalog: UbongoCatalog.classic,
      );

      final solution = ExactCoverSolver(puzzle).solveFirst();

      expect(solution, isNotNull);
      expect(validateSolution(puzzle, solution!), isTrue);
    });

    test('an L-shaped 5-cell board is solved by a domino + corner triomino', () {
      // Built by translating (not rotating) each piece's own base shape, so
      // the expected board is hand-verifiable without rotation math:
      //   domino (P1, base {(0,0),(0,1)}) placed at (0,2) -> (0,2),(0,3)
      //   triomino (P3, base {(0,0),(0,1),(1,0)}) placed at (0,0) -> (0,0),(0,1),(1,0)
      final domino = _byId('P1');
      final triomino = _byId('P3');
      final board = Board(
        width: 4,
        height: 2,
        cells: {c(0, 0), c(0, 1), c(0, 2), c(0, 3), c(1, 0)},
      );
      final puzzle = Puzzle(
        board: board,
        slots: [SolidSlot(domino), SolidSlot(triomino)],
        catalog: UbongoCatalog.classic,
      );

      final solution = ExactCoverSolver(puzzle).solveFirst();

      expect(solution, isNotNull);
      expect(validateSolution(puzzle, solution!), isTrue);
    });

    test('a gray slot accepts any catalog piece with a matching cell count', () {
      // Board is exactly the corner triomino's own shape; the only 3-cell
      // catalog pieces are the straight and corner triominoes (P2, P3), and
      // only the corner shape actually fits this board.
      final board = Board(
        width: 2,
        height: 2,
        cells: {c(0, 0), c(0, 1), c(1, 0)},
      );
      final puzzle = Puzzle(
        board: board,
        slots: [GraySlot(3)],
        catalog: UbongoCatalog.classic,
      );

      final solution = ExactCoverSolver(puzzle).solveFirst();

      expect(solution, isNotNull);
      expect(validateSolution(puzzle, solution!), isTrue);
      expect(solution.placements.single.piece.id, 'P3');
    });
  });

  group('known unsolvable puzzles', () {
    test('total slot cell count less than board cell count is unsolvable', () {
      final board = Board(
        width: 4,
        height: 2,
        cells: {c(0, 0), c(0, 1), c(0, 2), c(0, 3), c(1, 0)}, // 5 cells
      );
      final puzzle = Puzzle(
        board: board,
        slots: [SolidSlot(_byId('P1'))], // only 2 cells
        catalog: UbongoCatalog.classic,
      );

      expect(ExactCoverSolver(puzzle).solveFirst(), isNull);
    });

    test('matching cell count but incompatible shape is unsolvable', () {
      // A 1x4 straight line can never contain a 2x2 square, regardless of
      // orientation (the square has only one orientation: itself).
      final board = Board(
        width: 4,
        height: 1,
        cells: {c(0, 0), c(0, 1), c(0, 2), c(0, 3)},
      );
      final puzzle = Puzzle(
        board: board,
        slots: [SolidSlot(_byId('P4'))],
        catalog: UbongoCatalog.classic,
      );

      expect(ExactCoverSolver(puzzle).solveFirst(), isNull);
    });
  });

  group('multiple solutions', () {
    test('a 2x2 board filled by two dominoes has more than one valid tiling', () {
      final board = Board(
        width: 2,
        height: 2,
        cells: {c(0, 0), c(0, 1), c(1, 0), c(1, 1)},
      );
      final puzzle = Puzzle(
        board: board,
        slots: [GraySlot(2), GraySlot(2)],
        catalog: UbongoCatalog.classic,
      );

      final solutions = ExactCoverSolver(puzzle).solveAll();

      expect(solutions.length, greaterThanOrEqualTo(2));
      for (final solution in solutions) {
        expect(validateSolution(puzzle, solution), isTrue);
      }
    });
  });

  group('solveAll respects maxSolutions', () {
    test('stops as soon as the cap is reached', () {
      final board = Board(
        width: 2,
        height: 2,
        cells: {c(0, 0), c(0, 1), c(1, 0), c(1, 1)},
      );
      final puzzle = Puzzle(
        board: board,
        slots: [GraySlot(2), GraySlot(2)],
        catalog: UbongoCatalog.classic,
      );

      final solutions = ExactCoverSolver(puzzle).solveAll(maxSolutions: 1);

      expect(solutions.length, 1);
    });
  });
}
