// Standalone diagnostic CLI for the board-outline detection pipeline.
//
// Runs `detectBoardShapeDebug` against a real (or synthetic) card photo
// and dumps every intermediate pipeline stage as a numbered PNG, plus a
// JSON summary, so a bad detection can be inspected stage-by-stage
// instead of only seeing the final null/wrong result. Pure-Dart — no
// Flutter widget/runtime involved, so it runs the exact same detection
// code the app uses (via `compute()`) without needing a device/emulator.
//
// Usage:
//   dart run tool/inspect_card.dart <input.jpg> <output_dir> \
//       [--fill-threshold=0.5]
//
// If package resolution fails, run `flutter pub get` in this package
// first — `dart run` reuses whatever `.dart_tool/package_config.json`
// Flutter's pub already produced.
//
// Deliberately imports specific `src/` files rather than the public
// `ubongo_vision.dart` barrel: the barrel also re-exports
// `perspective/native_scanner_impl.dart`, which pulls in
// `cunning_document_scanner` -> `package:flutter` -> `dart:ui` — a
// library the plain (non-Flutter) Dart VM this CLI runs under doesn't
// have. The detection pipeline itself has no such dependency, so
// importing it directly keeps this a true plain-`dart run` tool.

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:ubongo_vision/src/board/board_outline_detector.dart';
import 'package:ubongo_vision/src/board/detection_diagnostics.dart';
import 'package:ubongo_vision/src/board/detection_params.dart';
import 'package:ubongo_vision/src/debug/debug_render.dart';
import 'package:ubongo_vision/src/rgb_image.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length < 2) {
    stderr.writeln(
      'Usage: dart run tool/inspect_card.dart <input.jpg> <output_dir> '
      '[--fill-threshold=0.5]',
    );
    exitCode = 64;
    return;
  }

  final inputPath = arguments[0];
  final outputDir = arguments[1];
  var fillThreshold = const DetectionParams().fillThreshold;

  for (final arg in arguments.skip(2)) {
    if (arg.startsWith('--fill-threshold=')) {
      fillThreshold = double.parse(arg.substring('--fill-threshold='.length));
    } else {
      stderr.writeln('Unknown argument: $arg');
      exitCode = 64;
      return;
    }
  }

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('No such file: $inputPath');
    exitCode = 66;
    return;
  }

  final bytes = await inputFile.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    stderr.writeln('Could not decode image: $inputPath');
    exitCode = 1;
    return;
  }
  // Mirrors NativeScannerImpl.scanCard()'s decode path exactly, so this
  // tool sees what the app's detection code actually sees.
  final rgbaImage = decoded.numChannels == 4 ? decoded : decoded.convert(numChannels: 4);
  final image = RgbImage(
    width: rgbaImage.width,
    height: rgbaImage.height,
    rgba: rgbaImage.getBytes(order: img.ChannelOrder.rgba),
  );

  final outDir = Directory(outputDir);
  await outDir.create(recursive: true);

  final params = DetectionParams(fillThreshold: fillThreshold);
  final stopwatch = Stopwatch()..start();
  final result = await detectBoardShapeDebug(image, params: params);
  stopwatch.stop();
  final diagnostics = result.diagnostics;
  final geometry = diagnostics.geometry;
  final blob = diagnostics.blob;

  await _writePng(diagnostics.downscaled, outDir, '01_downscaled.png');
  await _writePng(renderSilhouette(diagnostics.lightMask, invert: true), outDir, '02_light_mask.png');
  if (blob != null) {
    final blobImage = renderSilhouette(blob, invert: true);
    await _writePng(blobImage, outDir, '03_blob.png');
    if (geometry != null) {
      await _writePng(overlayGridLattice(blobImage, geometry), outDir, '04_lattice_overlay.png');
      if (diagnostics.cellFillFractions.isNotEmpty) {
        await _writePng(
          overlayCellClassification(blobImage, geometry, diagnostics.cellFillFractions, params.fillThreshold),
          outDir,
          '05_cell_classification.png',
        );
      }
    }
  }

  final summaryPath = '${outDir.path}${Platform.pathSeparator}summary.json';
  await File(summaryPath).writeAsString(_summaryJson(
    inputPath: inputPath,
    sourceImage: image,
    params: params,
    elapsed: stopwatch.elapsed,
    result: result,
  ));

  stdout.writeln('Wrote diagnostics to ${outDir.path}');
  if (diagnostics.rejectionReason != null) {
    stdout.writeln('REJECTED: ${diagnostics.rejectionReason}');
  } else {
    stdout.writeln('Detected ${result.shape!.width}x${result.shape!.height}, '
        '${result.shape!.cells.length} outline cells');
  }
}

Future<void> _writePng(RgbImage image, Directory dir, String filename) async {
  final encoded = img.Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: image.rgba.buffer,
    order: img.ChannelOrder.rgba,
  );
  await File('${dir.path}${Platform.pathSeparator}$filename').writeAsBytes(img.encodePng(encoded));
}

String _summaryJson({
  required String inputPath,
  required RgbImage sourceImage,
  required DetectionParams params,
  required Duration elapsed,
  required BoardDetectionResult result,
}) {
  final diagnostics = result.diagnostics;
  final geometry = diagnostics.geometry;
  final shape = result.shape;

  final sortedCells = diagnostics.cellFillFractions.keys.toList()
    ..sort((a, b) {
      final rowCmp = a.row.compareTo(b.row);
      return rowCmp != 0 ? rowCmp : a.col.compareTo(b.col);
    });

  final summary = {
    'input': inputPath,
    'sourceSize': '${sourceImage.width}x${sourceImage.height}',
    'downscaledSize': '${diagnostics.downscaled.width}x${diagnostics.downscaled.height}',
    'blobSize': diagnostics.blob == null ? null : '${diagnostics.blob!.width}x${diagnostics.blob!.height}',
    'params': {
      'fillThreshold': params.fillThreshold,
    },
    'elapsedMs': elapsed.inMilliseconds,
    'geometry': geometry == null
        ? null
        : {
            'cols': geometry.cols,
            'rows': geometry.rows,
            'originX': geometry.originX,
            'originY': geometry.originY,
            'pitchX': geometry.pitchX,
            'pitchY': geometry.pitchY,
          },
    'rejectionReason': diagnostics.rejectionReason,
    'shape': shape == null
        ? null
        : {
            'width': shape.width,
            'height': shape.height,
            'cells': (shape.cells.toList()
                  ..sort((a, b) {
                    final rowCmp = a.row.compareTo(b.row);
                    return rowCmp != 0 ? rowCmp : a.col.compareTo(b.col);
                  }))
                .map((c) => [c.row, c.col])
                .toList(),
          },
    'cellFillFractions': {
      for (final coord in sortedCells)
        '${coord.row},${coord.col}': double.parse(diagnostics.cellFillFractions[coord]!.toStringAsFixed(3)),
    },
  };

  return const JsonEncoder.withIndent('  ').convert(summary);
}
