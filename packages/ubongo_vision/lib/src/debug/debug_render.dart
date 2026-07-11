import 'dart:typed_data';

import 'package:ubongo_core/ubongo_core.dart';

import '../board/grid_geometry.dart';
import '../recognition/silhouette.dart';
import '../rgb_image.dart';

/// Debug-only rendering helpers that turn intermediate pipeline values (a
/// [Silhouette] mask, a fitted [GridGeometry], per-cell fill fractions)
/// into a plain [RgbImage] that can be PNG-encoded and looked at directly.
/// Used by `tool/inspect_card.dart` and `tool/tune_params.dart` — not
/// part of the production detection path, so this file is deliberately
/// not exported from the public `ubongo_vision.dart` barrel (same
/// tool/test-only status as `test/support/synthetic_card_renderer.dart`).

RgbImage _clone(RgbImage image) =>
    RgbImage(width: image.width, height: image.height, rgba: Uint8List.fromList(image.rgba));

/// Renders a binary mask as a flat black-on-white image (white-on-black
/// if [invert] is true) — lets a threshold/morphology stage be looked at
/// directly instead of only through what it produces downstream.
RgbImage renderSilhouette(Silhouette mask, {bool invert = false}) {
  final fg = invert ? 255 : 0;
  final bg = invert ? 0 : 255;
  final image = RgbImage.blank(mask.width, mask.height);
  for (var y = 0; y < mask.height; y++) {
    for (var x = 0; x < mask.width; x++) {
      final v = mask.at(x, y) ? fg : bg;
      image.setPixel(x, y, v, v, v);
    }
  }
  return image;
}

void _drawVerticalLine(RgbImage image, int x, int y0, int y1, int r, int g, int b, {int width = 2}) {
  final half = width ~/ 2;
  for (var dx = -half; dx <= half; dx++) {
    final px = x + dx;
    if (px < 0 || px >= image.width) continue;
    for (var y = y0; y <= y1; y++) {
      if (y < 0 || y >= image.height) continue;
      image.setPixel(px, y, r, g, b);
    }
  }
}

void _drawHorizontalLine(RgbImage image, int x0, int x1, int y, int r, int g, int b, {int width = 2}) {
  final half = width ~/ 2;
  for (var dy = -half; dy <= half; dy++) {
    final py = y + dy;
    if (py < 0 || py >= image.height) continue;
    for (var x = x0; x <= x1; x++) {
      if (x < 0 || x >= image.width) continue;
      image.setPixel(x, py, r, g, b);
    }
  }
}

/// Copies [image] and draws the fitted lattice's vertical/horizontal
/// lines over it, so a wrong or missing lattice fit is visible directly
/// against the source photo instead of only as a downstream symptom.
RgbImage overlayGridLattice(
  RgbImage image,
  GridGeometry geometry, {
  int r = 255,
  int g = 32,
  int b = 32,
}) {
  final out = _clone(image);
  final x0 = geometry.originX.round();
  final y0 = geometry.originY.round();
  final x1 = (geometry.originX + geometry.cols * geometry.pitchX).round();
  final y1 = (geometry.originY + geometry.rows * geometry.pitchY).round();

  for (var col = 0; col <= geometry.cols; col++) {
    final x = (geometry.originX + col * geometry.pitchX).round();
    _drawVerticalLine(out, x, y0, y1, r, g, b);
  }
  for (var row = 0; row <= geometry.rows; row++) {
    final y = (geometry.originY + row * geometry.pitchY).round();
    _drawHorizontalLine(out, x0, x1, y, r, g, b);
  }
  return out;
}

/// Copies [image] and tints each candidate cell in [cellFillFractions] —
/// green if its fraction exceeds [fillThreshold] (classified inside the
/// outline), red otherwise — so misclassified cells and borderline ones
/// close to the threshold are visible at a glance against the photo.
RgbImage overlayCellClassification(
  RgbImage image,
  GridGeometry geometry,
  Map<CellCoord, double> cellFillFractions,
  double fillThreshold, {
  double alpha = 0.4,
}) {
  final out = _clone(image);
  cellFillFractions.forEach((coord, fraction) {
    final inside = fraction > fillThreshold;
    final tintR = inside ? 0 : 255;
    final tintG = inside ? 200 : 0;
    const tintB = 0;

    final left = (geometry.originX + coord.col * geometry.pitchX).round();
    final top = (geometry.originY + coord.row * geometry.pitchY).round();
    final right = (geometry.originX + (coord.col + 1) * geometry.pitchX).round();
    final bottom = (geometry.originY + (coord.row + 1) * geometry.pitchY).round();

    for (var y = top; y < bottom; y++) {
      if (y < 0 || y >= out.height) continue;
      for (var x = left; x < right; x++) {
        if (x < 0 || x >= out.width) continue;
        final (r0, g0, b0, _) = out.pixelAt(x, y);
        final nr = (r0 * (1 - alpha) + tintR * alpha).round().clamp(0, 255);
        final ng = (g0 * (1 - alpha) + tintG * alpha).round().clamp(0, 255);
        final nb = (b0 * (1 - alpha) + tintB * alpha).round().clamp(0, 255);
        out.setPixel(x, y, nr, ng, nb);
      }
    }
  });
  return out;
}
