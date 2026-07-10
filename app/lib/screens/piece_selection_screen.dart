import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

import '../data/rgb_image_codec.dart';
import '../data/scanned_board_data.dart';
import '../state/board_calibration.dart';
import '../state/puzzle_session.dart';
import '../widgets/piece_selector.dart';

class _DetectArgs {
  final RgbImage image;
  final DetectionParams params;
  const _DetectArgs(this.image, this.params);
}

Future<DetectedBoardShape?> _runDetection(_DetectArgs args) =>
    detectBoardShape(args.image, params: args.params);

/// Lets the user click which pieces the scanned puzzle requires — the
/// manual replacement for what used to be auto icon-recognition (see the
/// project plan's "Increment 2": icon recognition depended on card-layout
/// constants that were never calibrated against a real card, whereas
/// clicking a piece is just the same interaction `ManualEntryScreen`
/// already has, reused via `PieceSelector`).
///
/// "Continue" is also where board-outline detection actually runs (off
/// the UI isolate via `compute`), since it only needs the photo, not
/// anything the user does on this screen — running it here means it's
/// usually already done by the time the user reaches the board-outline
/// screen next.
class PieceSelectionScreen extends ConsumerStatefulWidget {
  final CorrectedCardImage corrected;
  const PieceSelectionScreen({super.key, required this.corrected});

  @override
  ConsumerState<PieceSelectionScreen> createState() => _PieceSelectionScreenState();
}

class _PieceSelectionScreenState extends ConsumerState<PieceSelectionScreen> {
  bool _detecting = false;

  Future<void> _continue() async {
    setState(() => _detecting = true);

    final params = ref.read(boardCalibrationProvider);
    DetectedBoardShape? detected;
    try {
      detected = await compute(_runDetection, _DetectArgs(widget.corrected.image, params));
    } catch (_) {
      detected = null; // detection is best-effort; fall through to manual markup
    }

    if (!mounted) return;

    final notifier = ref.read(puzzleSessionProvider.notifier);
    if (detected != null) {
      notifier.setGridSize(detected.width, detected.height);
      notifier.setBoardCells(detected.cells);
    }

    context.push(
      '/markup',
      extra: ScannedBoardData(corrected: widget.corrected, detectedShape: detected),
    );
    setState(() => _detecting = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(puzzleSessionProvider);
    final notifier = ref.read(puzzleSessionProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Pieces')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              encodePngFromRgbImage(widget.corrected.image),
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Tap the pieces this puzzle requires.'),
          const SizedBox(height: 16),
          PieceSelector(
            slots: session.slots,
            onAdd: notifier.addSlot,
            onRemove: notifier.removeSlotAt,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _detecting ? null : _continue,
            child: Text(_detecting ? 'Analyzing photo…' : 'Continue to board outline'),
          ),
        ],
      ),
    );
  }
}
