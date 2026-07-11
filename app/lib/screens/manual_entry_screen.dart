import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubongo_core/ubongo_core.dart';

import '../state/puzzle_session.dart';
import '../widgets/grid_overlay_widget.dart';
import '../widgets/piece_selector.dart';
import '../widgets/size_stepper.dart';

class ManualEntryScreen extends ConsumerWidget {
  const ManualEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(puzzleSessionProvider);
    final notifier = ref.read(puzzleSessionProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Manual Entry')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: SizeStepper(
                  label: 'Cols',
                  value: session.gridWidth,
                  onChanged: (v) => notifier.setGridSize(v, session.gridHeight),
                ),
              ),
              Expanded(
                child: SizeStepper(
                  label: 'Rows',
                  value: session.gridHeight,
                  onChanged: (v) => notifier.setGridSize(session.gridWidth, v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.grid_on, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('Tap cells to mark the puzzle outline', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          // Same tap-target fix as GridMarkupScreen: a fixed pixel size of
          // at least kMinGridCellSize per cell, pannable/zoomable within a
          // bounded viewport, instead of shrinking cells to fit the width.
          SizedBox(
            height: 360,
            child: InteractiveViewer(
              constrained: false,
              minScale: 0.5,
              maxScale: 4,
              child: SizedBox(
                width: session.gridWidth * kMinGridCellSize,
                height: session.gridHeight * kMinGridCellSize,
                child: GridOverlayWidget(
                  width: session.gridWidth,
                  height: session.gridHeight,
                  useAspectRatio: false,
                  filledCells: session.boardCells,
                  onCellTap: notifier.toggleCell,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          PieceSelector(
            catalog: UbongoCatalog.classic,
            solidCountOf: notifier.solidCountOf,
            onSetSolidCount: notifier.setSolidCount,
            grayCountOf: notifier.grayCountOf,
            onSetGrayCount: notifier.setGrayCount,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              notifier.solve();
              context.push('/solution');
            },
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Solve'),
          ),
        ],
      ),
    );
  }
}
