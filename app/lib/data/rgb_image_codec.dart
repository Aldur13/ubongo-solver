import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:ubongo_vision/ubongo_vision.dart';

/// Encodes an [RgbImage] to PNG bytes so it can be shown via
/// `Image.memory`. Kept out of `ubongo_vision` since it's purely a
/// display-layer concern of this app, not part of the recognition
/// pipeline.
Uint8List encodePngFromRgbImage(RgbImage image) {
  final decoded = img.Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: image.rgba.buffer,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodePng(decoded));
}

/// Everything [encodeDisplayPng] needs, bundled so it can cross a
/// `compute()` isolate boundary in one argument (the same pattern as
/// `piece_selection_screen.dart`'s `_DetectArgs`).
class DisplayPngArgs {
  final RgbImage image;

  /// Optional fractional crop to apply before downscaling (e.g. a
  /// detection's `boardRegion`); null encodes the whole image.
  final NormalizedRect? crop;

  final int maxDimension;

  const DisplayPngArgs(this.image, {this.crop, this.maxDimension = 800});
}

/// Images at most this many pixels encode inline instead of via
/// `compute()`: an isolate spawn + full image copy costs more than just
/// encoding something this small, and widget tests (whose fake-async
/// pump loop never sees a real isolate's reply, hanging pumpAndSettle)
/// only ever construct tiny stand-in images.
const _syncEncodePixelBudget = 256 * 256;

/// [encodeDisplayPng] behind the right execution strategy for the image's
/// size: real scanner photos (millions of pixels) encode on a background
/// isolate, tiny images inline (completing in a microtask, so callers can
/// uniformly `.then`/`await` without special-casing). Screens should call
/// this once, cache the bytes, and hand them to `Image.memory` — encoding
/// synchronously in `build()` cost ~0.5s of jank per rebuild.
Future<Uint8List> encodeDisplayPngAsync(DisplayPngArgs args) {
  if (args.image.width * args.image.height <= _syncEncodePixelBudget) {
    return Future.value(encodeDisplayPng(args));
  }
  return compute(encodeDisplayPng, args);
}

/// Crops (optionally), downscales to at most [DisplayPngArgs.maxDimension],
/// and PNG-encodes an [RgbImage] for on-screen display. Top-level so it's
/// callable via `compute()`. Cropping happens before downscaling so a
/// cropped region keeps its sharpness rather than being cut from an
/// already-shrunk image. Prefer [encodeDisplayPngAsync], which keeps
/// large encodes off the UI isolate.
Uint8List encodeDisplayPng(DisplayPngArgs args) {
  var image = args.image;
  final crop = args.crop;
  if (crop != null) {
    image = cropFraction(image, Rect.fromLTWH(crop.left, crop.top, crop.width, crop.height));
  }
  image = image.downscaled(maxDimension: args.maxDimension);
  return encodePngFromRgbImage(image);
}

/// Crops an [RgbImage] to a fractional (0-1) rect of its own dimensions.
RgbImage cropFraction(RgbImage source, Rect fractionalRect) {
  final x = (fractionalRect.left * source.width).round().clamp(0, source.width - 1);
  final y = (fractionalRect.top * source.height).round().clamp(0, source.height - 1);
  final w = (fractionalRect.width * source.width).round().clamp(1, source.width - x);
  final h = (fractionalRect.height * source.height).round().clamp(1, source.height - y);

  final rgba = Uint8List(w * h * 4);
  for (var row = 0; row < h; row++) {
    for (var col = 0; col < w; col++) {
      final (r, g, b, a) = source.pixelAt(x + col, y + row);
      final i = (row * w + col) * 4;
      rgba[i] = r;
      rgba[i + 1] = g;
      rgba[i + 2] = b;
      rgba[i + 3] = a;
    }
  }
  return RgbImage(width: w, height: h, rgba: rgba);
}
