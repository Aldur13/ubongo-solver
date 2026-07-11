import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/rgb_image_codec.dart';
import '../data/scanned_board_data.dart';
import '../state/board_calibration.dart';
import '../state/puzzle_session.dart';
import '../widgets/grid_overlay_widget.dart';
import '../widgets/size_stepper.dart';

/// The manual `BoardShapeSource` UI: the corrected card photo underneath,
/// a tappable grid on top.
///
/// When reached after a scan whose auto-detection succeeded
/// ([ScannedBoardData.detectedShape] non-null), the photo shown is
/// cropped to the detection's [DetectedBoardShape.boardRegion] — the
/// exact lattice area cell classification sampled — so the tap-grid's
/// cells sit over the printed squares they were judged from (the full
/// card photo also contains the piece-icon strip and margins, which made
/// an uncropped photo impossible to line a grid up with). The grid opens
/// pre-filled with the detected outline and shows a banner framing it as
/// a hypothesis to confirm or fix, not settled fact — tapping cells here
/// always works exactly the same way either way, so this doubles as the
/// full manual-entry experience when detection wasn't available/failed
/// (then showing the whole photo as before).
/// Whatever the user ends up submitting is diffed against the original
/// detection (if any) to nudge future detections — see
/// `state/board_calibration.dart`.
class GridMarkupScreen extends ConsumerStatefulWidget {
  final ScannedBoardData data;
  const GridMarkupScreen({super.key, required this.data});

  @override
  ConsumerState<GridMarkupScreen> createState() => _GridMarkupScreenState();
}

class _GridMarkupScreenState extends ConsumerState<GridMarkupScreen> {
  Uint8List? _pngBytes;

  @override
  void initState() {
    super.initState();
    // Cropped (when detection located the board) and downscaled to
    // display size off the UI isolate — synchronously PNG-encoding the
    // full-resolution photo here froze screen entry, and painting the
    // resulting full-size texture made every cell-toggle frame heavy.
    encodeDisplayPngAsync(DisplayPngArgs(
      widget.data.corrected.image,
      crop: widget.data.detectedShape?.boardRegion,
    )).then((bytes) {
      if (mounted) setState(() => _pngBytes = bytes);
    });
  }

  void _confirmAndSolve() {
    final detected = widget.data.detectedShape;
    if (detected != null) {
      final finalCells = ref.read(puzzleSessionProvider).boardCells;
      final added = finalCells.difference(detected.cells);
      final removed = detected.cells.difference(finalCells);
      ref.read(boardCalibrationProvider.notifier).recordCorrection(
            added: added.length,
            removed: removed.length,
          );
    }

    ref.read(puzzleSessionProvider.notifier).solve();
    context.push('/solution');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(puzzleSessionProvider);
    final notifier = ref.read(puzzleSessionProvider.notifier);
    final overlayColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.45);
    final wasDetected = widget.data.detectedShape != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Mark the Board Outline')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizeStepper(
                  label: 'Cols',
                  value: session.gridWidth,
                  onChanged: (v) => notifier.setGridSize(v, session.gridHeight),
                ),
                SizeStepper(
                  label: 'Rows',
                  value: session.gridHeight,
                  onChanged: (v) => notifier.setGridSize(session.gridWidth, v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (wasDetected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Auto-detected this outline — tap any wrong cells to fix, then Solve.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Icon(Icons.touch_app, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Tap the cells that make up the puzzle outline shown in the photo.'),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Expanded(
              // constrained: false + a fixed pixel size keeps every cell at
              // least kMinGridCellSize regardless of grid dimensions or
              // screen width — a grid that doesn't fit the viewport at that
              // size is pannable/zoomable instead of shrinking cells below
              // a tappable size (see kMinGridCellSize's doc comment).
              child: InteractiveViewer(
                constrained: false,
                minScale: 0.5,
                maxScale: 4,
                child: SizedBox(
                  width: session.gridWidth * kMinGridCellSize,
                  height: session.gridHeight * kMinGridCellSize,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_pngBytes == null)
                        const Center(child: CircularProgressIndicator())
                      else
                        Image.memory(_pngBytes!, fit: BoxFit.fill),
                      GridOverlayWidget(
                        width: session.gridWidth,
                        height: session.gridHeight,
                        useAspectRatio: false,
                        filledCells: session.boardCells,
                        cellColors: {for (final c in session.boardCells) c: overlayColor},
                        onCellTap: notifier.toggleCell,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _confirmAndSolve,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Solve'),
            ),
          ],
        ),
      ),
    );
  }
}
