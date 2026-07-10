import 'dart:typed_data';
import 'dart:ui';

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
