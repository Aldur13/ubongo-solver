import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubongo_core/ubongo_core.dart';

import '../state/puzzle_session.dart';
import '../widgets/grid_overlay_widget.dart';
import '../widgets/piece_placement_overlay.dart';

class SolutionScreen extends ConsumerWidget {
  const SolutionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(puzzleSessionProvider);
    final solution = session.solution;

    return Scaffold(
      appBar: AppBar(title: const Text('Solution')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (session.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  session.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: GridOverlayWidget(
                width: session.gridWidth,
                height: session.gridHeight,
                filledCells: session.boardCells,
                cellColors: solution == null ? null : PiecePlacementOverlay.colorsFor(solution),
                cellLabels: solution == null ? null : PiecePlacementOverlay.labelsFor(solution),
              ),
            ),
            const SizedBox(height: 16),
            if (solution != null) _Legend(solution: solution),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(puzzleSessionProvider.notifier).reset();
                context.go('/');
              },
              child: const Text('New Puzzle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Solution solution;
  const _Legend({required this.solution});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final placed in solution.placements)
          Chip(
            avatar: CircleAvatar(
              backgroundColor: PiecePlacementOverlay.colorForSlot(placed.slotIndex),
            ),
            label: Text('${placed.piece.id} — ${placed.piece.name}'),
          ),
      ],
    );
  }
}
