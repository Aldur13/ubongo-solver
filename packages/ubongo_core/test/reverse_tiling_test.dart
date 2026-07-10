import 'dart:math';

import 'package:test/test.dart';
import 'package:ubongo_core/ubongo_core.dart';

void main() {
  test(
    'boards built by reverse-tiling known pieces are always solvable',
    () {
      final rng = Random(42); // fixed seed: deterministic, non-flaky
      const gridSize = 6;
      const trials = 25;

      for (var trial = 0; trial < trials; trial++) {
        final piecesToPlace = (List.of(UbongoCatalog.classic)..shuffle(rng))
            .take(3)
            .toList();
        final occupied = <CellCoord>{};
        final slots = <PieceSlot>[];

        for (final piece in piecesToPlace) {
          final orientation =
              piece.orientations[rng.nextInt(piece.orientations.length)];

          for (var attempt = 0; attempt < 30; attempt++) {
            final dr = rng.nextInt(gridSize - orientation.height + 1);
            final dc = rng.nextInt(gridSize - orientation.width + 1);
            final cells = orientation.offsets
                .map((o) => CellCoord(dr + o.row, dc + o.col))
                .toSet();
            if (cells.every((cell) => !occupied.contains(cell))) {
              occupied.addAll(cells);
              slots.add(SolidSlot(piece));
              break;
            }
          }
        }

        if (slots.isEmpty) continue; // pathological trial, nothing placed

        final board = Board(width: gridSize, height: gridSize, cells: occupied);
        final puzzle = Puzzle(
          board: board,
          slots: slots,
          catalog: UbongoCatalog.classic,
        );

        final solution = ExactCoverSolver(puzzle).solveFirst();

        expect(
          solution,
          isNotNull,
          reason: 'trial $trial: a board built from ${slots.length} known '
              'placements should always have at least one valid solution',
        );
        expect(
          validateSolution(puzzle, solution!),
          isTrue,
          reason: 'trial $trial: solver returned a solution that fails '
              'independent validation',
        );
      }
    },
  );
}
