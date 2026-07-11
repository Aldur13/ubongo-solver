import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ubongo_core/ubongo_core.dart';
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

  /// Debug-only export of exactly what `NativeScannerImpl` produced, so a
  /// real device's scan can be pulled off the phone and inspected with
  /// `tool/inspect_card.dart` — see the project plan's board-outline
  /// scanning fix, Phase 1b: this is the only way to tell whether the
  /// native document scanner's crop/perspective correction (not this
  /// screen's own board-outline detection) is the source of a bad scan.
  Future<void> _shareCorrectedPhoto() async {
    final bytes = encodePngFromRgbImage(widget.corrected.image);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'ubongo_scan.png')],
        text: 'Ubongo Solver debug scan export',
      ),
    );
  }

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
    final notifier = ref.read(puzzleSessionProvider.notifier);
    // Watch so the piece counts below rebuild as the user taps +/-.
    ref.watch(puzzleSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Pieces'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Share corrected scan (debug)',
              onPressed: _shareCorrectedPhoto,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              encodePngFromRgbImage(widget.corrected.image),
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.touch_app, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('Tap the pieces this puzzle requires.')),
            ],
          ),
          const SizedBox(height: 16),
          PieceSelector(
            catalog: UbongoCatalog.classic,
            solidCountOf: notifier.solidCountOf,
            onSetSolidCount: notifier.setSolidCount,
            grayCountOf: notifier.grayCountOf,
            onSetGrayCount: notifier.setGrayCount,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _detecting ? null : _continue,
            icon: _detecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward),
            label: Text(_detecting ? 'Analyzing photo…' : 'Continue to board outline'),
          ),
        ],
      ),
    );
  }
}
