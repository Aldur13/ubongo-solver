import 'dart:collection';

import '../rgb_image.dart';

/// A binary foreground/background pixel mask — the shared representation
/// both piece-icon recognition and board-outline detection work against,
/// whether it came from thresholding a real photo or from synthetically
/// rendering a catalog piece or test card.
class Silhouette {
  final int width;
  final int height;
  final List<bool> _pixels;

  Silhouette(this.width, this.height, List<bool> pixels) : _pixels = pixels {
    if (pixels.length != width * height) {
      throw ArgumentError('pixel count does not match $width x $height');
    }
  }

  factory Silhouette.filled(int width, int height, bool value) =>
      Silhouette(width, height, List.filled(width * height, value));

  bool at(int x, int y) => _pixels[y * width + x];

  void set(int x, int y, bool value) => _pixels[y * width + x] = value;

  int get foregroundCount => _pixels.where((p) => p).length;

  /// Thresholds an [RgbImage] into a foreground/background mask by
  /// luminance. Printed card icons are dark marks on a light background,
  /// so darker-than-[threshold] pixels are foreground by default — pass
  /// [invert] true for a light-on-dark region.
  factory Silhouette.threshold(
    RgbImage image, {
    int threshold = 128,
    bool invert = false,
  }) {
    final pixels = List<bool>.filled(image.width * image.height, false);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final (r, g, b, _) = image.pixelAt(x, y);
        final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        final isForeground =
            invert ? luminance >= threshold : luminance < threshold;
        pixels[y * image.width + x] = isForeground;
      }
    }
    return Silhouette(image.width, image.height, pixels);
  }

  /// Isolates the largest 4-connected foreground component, returned as
  /// its own tightly cropped mask (background elsewhere discarded). Used
  /// to pull one clean piece-icon shape out of a binarized crop that may
  /// contain stray specks or a partial neighboring icon.
  Silhouette largestComponentCropped() {
    final visited = List<bool>.filled(width * height, false);
    List<int>? best;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final start = y * width + x;
        if (!_pixels[start] || visited[start]) continue;

        final component = <int>[];
        final queue = Queue<int>()..add(start);
        visited[start] = true;
        while (queue.isNotEmpty) {
          final cur = queue.removeFirst();
          component.add(cur);
          final cx = cur % width;
          final cy = cur ~/ width;
          for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final nx = cx + dx;
            final ny = cy + dy;
            if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
            final nIdx = ny * width + nx;
            if (_pixels[nIdx] && !visited[nIdx]) {
              visited[nIdx] = true;
              queue.add(nIdx);
            }
          }
        }
        if (best == null || component.length > best.length) best = component;
      }
    }

    if (best == null) return Silhouette.filled(1, 1, false);

    var minX = width, maxX = 0, minY = height, maxY = 0;
    for (final idx in best) {
      final x = idx % width;
      final y = idx ~/ width;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    final w = maxX - minX + 1;
    final h = maxY - minY + 1;
    final cropped = List<bool>.filled(w * h, false);
    for (final idx in best) {
      final x = idx % width;
      final y = idx ~/ width;
      cropped[(y - minY) * w + (x - minX)] = true;
    }
    return Silhouette(w, h, cropped);
  }

  /// Fills any background region fully enclosed by foreground pixels —
  /// i.e. background pixels that can't reach the mask's own border by
  /// walking only through other background pixels. Needed because a
  /// gray/outline card icon's foreground (after thresholding) is only the
  /// thin traced border, not the shape's interior; without filling that
  /// hole back in, its silhouette would be a hollow ring rather than the
  /// solid piece shape the catalog's reference silhouettes are rendered
  /// as, and Hu-moment matching would compare a ring against a filled
  /// shape instead of like-for-like.
  Silhouette fillEnclosedHoles() {
    final reachesBorder = List<bool>.filled(width * height, false);
    final queue = Queue<int>();

    void seed(int x, int y) {
      final idx = y * width + x;
      if (!_pixels[idx] && !reachesBorder[idx]) {
        reachesBorder[idx] = true;
        queue.add(idx);
      }
    }

    for (var x = 0; x < width; x++) {
      seed(x, 0);
      if (height > 1) seed(x, height - 1);
    }
    for (var y = 0; y < height; y++) {
      seed(0, y);
      if (width > 1) seed(width - 1, y);
    }

    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();
      final cx = cur % width;
      final cy = cur ~/ width;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = cx + dx;
        final ny = cy + dy;
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        final nIdx = ny * width + nx;
        if (!_pixels[nIdx] && !reachesBorder[nIdx]) {
          reachesBorder[nIdx] = true;
          queue.add(nIdx);
        }
      }
    }

    final filled = List<bool>.generate(
      width * height,
      (i) => _pixels[i] || !reachesBorder[i],
    );
    return Silhouette(width, height, filled);
  }

  /// Morphological erosion: a pixel survives only if every pixel within a
  /// `(2*radius+1) x (2*radius+1)` neighborhood is foreground (pixels
  /// outside the mask's bounds count as background). Thin lines (width
  /// <= `2*radius`) are erased entirely; thicker regions shrink but
  /// survive.
  Silhouette erode(int radius) {
    final result = List<bool>.filled(width * height, false);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var allForeground = true;
        for (var dy = -radius; dy <= radius && allForeground; dy++) {
          final ny = y + dy;
          for (var dx = -radius; dx <= radius; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= width || ny < 0 || ny >= height || !_pixels[ny * width + nx]) {
              allForeground = false;
              break;
            }
          }
        }
        result[y * width + x] = allForeground;
      }
    }
    return Silhouette(width, height, result);
  }

  /// Morphological dilation: a pixel becomes foreground if any pixel
  /// within a `(2*radius+1) x (2*radius+1)` neighborhood is foreground.
  Silhouette dilate(int radius) {
    final result = List<bool>.filled(width * height, false);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var anyForeground = false;
        for (var dy = -radius; dy <= radius && !anyForeground; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          for (var dx = -radius; dx <= radius; dx++) {
            final nx = x + dx;
            if (nx >= 0 && nx < width && _pixels[ny * width + nx]) {
              anyForeground = true;
              break;
            }
          }
        }
        result[y * width + x] = anyForeground;
      }
    }
    return Silhouette(width, height, result);
  }

  /// Morphological opening (erode then dilate): removes features thinner
  /// than `2*radius` (e.g. thin printed grid lines) while preserving
  /// thicker ones (e.g. a bold traced outline) at close to their original
  /// size.
  Silhouette opened(int radius) => erode(radius).dilate(radius);
}
