import 'package:flutter_test/flutter_test.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

void main() {
  group('RgbImage.downscaled', () {
    test('returns the same image unchanged when already within maxDimension', () {
      final image = RgbImage.blank(100, 50);
      final result = image.downscaled(maxDimension: 100);
      expect(identical(result, image), isTrue);
    });

    test('preserves aspect ratio when shrinking', () {
      final image = RgbImage.blank(800, 400);
      final result = image.downscaled(maxDimension: 200);
      expect(result.width, 200);
      expect(result.height, 100);
    });

    test('a fine checkerboard\'s average intensity survives roughly intact', () {
      // 40x40 image, alternating black/white in 1px columns — a fine
      // pattern that nearest-neighbor downscaling could alias away
      // entirely, but area-averaging should fade to a consistent mid-gray.
      final image = RgbImage.blank(40, 40);
      for (var y = 0; y < 40; y++) {
        for (var x = 0; x < 40; x++) {
          if (x.isEven) image.setPixel(x, y, 0, 0, 0);
        }
      }
      final result = image.downscaled(maxDimension: 10);

      var sum = 0;
      for (var y = 0; y < result.height; y++) {
        for (var x = 0; x < result.width; x++) {
          final (r, g, b, _) = result.pixelAt(x, y);
          sum += (r + g + b) ~/ 3;
        }
      }
      final average = sum / (result.width * result.height);
      // Original is a 50/50 black/white mix -> average luminance ~127.
      expect(average, closeTo(127, 30));
    });
  });
}
