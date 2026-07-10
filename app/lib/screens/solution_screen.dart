import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubongo_core/ubongo_core.dart';

import '../state/puzzle_session.dart';
import '../widgets/grid_overlay_widget.dart';
import '../widgets/piece_placement_overlay.dart';
import '../widgets/piece_shape_thumbnail.dart';

class SolutionScreen extends ConsumerWidget {
  const SolutionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(puzzleSessionProvider);
    final solution = session.solution;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Solution')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (session.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.errorMessage!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              )
            else if (solution != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Solved!', style: Theme.of(context).textTheme.titleLarge),
                  ],
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
            FilledButton.icon(
              onPressed: () {
                ref.read(puzzleSessionProvider.notifier).reset();
                context.go('/');
              },
              icon: const Icon(Icons.refresh),
              label: const Text('New Puzzle'),
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
            avatar: PieceShapeThumbnail(
              cells: placed.piece.cells,
              color: PiecePlacementOverlay.colorForSlot(placed.slotIndex),
              cellSize: 8,
            ),
            label: Text('${placed.piece.id} — ${placed.piece.name}'),
          ),
      ],
    );
  }
}
