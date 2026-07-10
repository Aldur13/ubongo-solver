import 'dart:typed_data';

/// A minimal, dependency-free RGBA pixel buffer.
///
/// Kept independent of `package:image`'s `Image` type (and of any
/// Flutter/platform image type) so the recognition pipeline's core logic
/// only depends on this tiny value type and can be unit-tested with
/// synthetic pixels, with no decoder/camera/native binding involved.
class RgbImage {
  final int width;
  final int height;

  /// Row-major, 4 bytes per pixel: R, G, B, A.
  final Uint8List rgba;

  RgbImage({required this.width, required this.height, required this.rgba}) {
    if (rgba.length != width * height * 4) {
      throw ArgumentError(
        'rgba length ${rgba.length} does not match $width x $height x 4',
      );
    }
  }

  factory RgbImage.blank(int width, int height, {int r = 255, int g = 255, int b = 255}) {
    final bytes = Uint8List(width * height * 4);
    for (var i = 0; i < width * height; i++) {
      bytes[i * 4] = r;
      bytes[i * 4 + 1] = g;
      bytes[i * 4 + 2] = b;
      bytes[i * 4 + 3] = 255;
    }
    return RgbImage(width: width, height: height, rgba: bytes);
  }

  (int r, int g, int b, int a) pixelAt(int x, int y) {
    final i = (y * width + x) * 4;
    return (rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]);
  }

  void setPixel(int x, int y, int r, int g, int b, {int a = 255}) {
    final i = (y * width + x) * 4;
    rgba[i] = r;
    rgba[i + 1] = g;
    rgba[i + 2] = b;
    rgba[i + 3] = a;
  }

  /// Shrinks the image so its longer side is at most [maxDimension],
  /// area-averaging (box-filter) each output pixel from its corresponding
  /// source region rather than nearest-neighbor sampling — this matters
  /// for downstream thresholding, since a thin 1px line sampled by
  /// nearest-neighbor can land entirely between output pixels and vanish,
  /// whereas area-averaging instead fades it to a weaker-but-present gray
  /// that a luminance threshold can still pick up. Returns this image
  /// unchanged if it's already within [maxDimension].
  RgbImage downscaled({required int maxDimension}) {
    final longSide = width > height ? width : height;
    if (longSide <= maxDimension) return this;

    final scale = maxDimension / longSide;
    final newWidth = (width * scale).round().clamp(1, width);
    final newHeight = (height * scale).round().clamp(1, height);
    final out = Uint8List(newWidth * newHeight * 4);

    for (var oy = 0; oy < newHeight; oy++) {
      final srcY0 = (oy * height / newHeight).floor();
      final srcY1 = (((oy + 1) * height) / newHeight).ceil().clamp(srcY0 + 1, height);
      for (var ox = 0; ox < newWidth; ox++) {
        final srcX0 = (ox * width / newWidth).floor();
        final srcX1 = (((ox + 1) * width) / newWidth).ceil().clamp(srcX0 + 1, width);

        var sumR = 0, sumG = 0, sumB = 0, sumA = 0, count = 0;
        for (var sy = srcY0; sy < srcY1; sy++) {
          for (var sx = srcX0; sx < srcX1; sx++) {
            final (r, g, b, a) = pixelAt(sx, sy);
            sumR += r;
            sumG += g;
            sumB += b;
            sumA += a;
            count++;
          }
        }

        final i = (oy * newWidth + ox) * 4;
        out[i] = (sumR / count).round();
        out[i + 1] = (sumG / count).round();
        out[i + 2] = (sumB / count).round();
        out[i + 3] = (sumA / count).round();
      }
    }
    return RgbImage(width: newWidth, height: newHeight, rgba: out);
  }
}
