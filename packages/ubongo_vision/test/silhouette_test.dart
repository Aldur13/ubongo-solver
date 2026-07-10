import 'package:flutter_test/flutter_test.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

RgbImage _blockOn(int width, int height, {
  required int blockX,
  required int blockY,
  required int blockW,
  required int blockH,
}) {
  final image = RgbImage.blank(width, height);
  for (var y = blockY; y < blockY + blockH; y++) {
    for (var x = blockX; x < blockX + blockW; x++) {
      image.setPixel(x, y, 0, 0, 0);
    }
  }
  return image;
}

void main() {
  group('Silhouette.threshold', () {
    test('dark pixels on a light background become foreground', () {
      final image = _blockOn(10, 10, blockX: 2, blockY: 2, blockW: 4, blockH: 4);
      final mask = Silhouette.threshold(image);
      expect(mask.foregroundCount, 16);
      expect(mask.at(3, 3), isTrue);
      expect(mask.at(0, 0), isFalse);
    });
  });

  group('Silhouette.largestComponentCropped', () {
    test('isolates the bigger of two disconnected components, cropped to it', () {
      final image = RgbImage.blank(20, 20);
      image.setPixel(1, 1, 0, 0, 0); // one-pixel speck
      for (var y = 10; y < 13; y++) {
        for (var x = 10; x < 13; x++) {
          image.setPixel(x, y, 0, 0, 0); // 3x3 block
        }
      }
      final largest = Silhouette.threshold(image).largestComponentCropped();
      expect(largest.width, 3);
      expect(largest.height, 3);
      expect(largest.foregroundCount, 9);
    });

    test('an all-background mask returns a trivial empty silhouette', () {
      final largest = Silhouette.filled(5, 5, false).largestComponentCropped();
      expect(largest.foregroundCount, 0);
    });
  });

  group('Silhouette.fillEnclosedHoles', () {
    test('fills a hole fully enclosed by a ring, leaves open background alone', () {
      // 7x7 ring (border of a 7x7 square, one pixel thick) around a hole.
      final mask = Silhouette.filled(7, 7, false);
      for (var i = 0; i < 7; i++) {
        mask.set(i, 0, true);
        mask.set(i, 6, true);
        mask.set(0, i, true);
        mask.set(6, i, true);
      }
      expect(mask.foregroundCount, 24); // just the ring
      expect(mask.at(3, 3), isFalse); // hole not yet filled

      final filled = mask.fillEnclosedHoles();

      expect(filled.at(3, 3), isTrue); // hole filled in
      expect(filled.foregroundCount, 49); // the whole 7x7 square
    });

    test('background reachable from the border is left untouched', () {
      final mask = Silhouette.filled(5, 5, false);
      mask.set(2, 2, true); // single isolated foreground pixel, no ring
      final filled = mask.fillEnclosedHoles();
      expect(filled.foregroundCount, 1); // nothing to fill; all bg reaches the edge
    });
  });

  group('Silhouette.erode', () {
    test('erases a 1px-thin line entirely at radius 1', () {
      final mask = Silhouette.filled(11, 11, false);
      for (var x = 1; x < 10; x++) {
        mask.set(x, 5, true); // horizontal 1px-tall line
      }
      final eroded = mask.erode(1);
      expect(eroded.foregroundCount, 0);
    });

    test('shrinks a solid block but does not erase it', () {
      final mask = Silhouette.filled(11, 11, false);
      for (var y = 3; y < 8; y++) {
        for (var x = 3; x < 8; x++) {
          mask.set(x, y, true); // solid 5x5 block, centered, away from edges
        }
      }
      final eroded = mask.erode(1);
      // Interior 3x3 survives; the 1px border of the block is stripped.
      expect(eroded.foregroundCount, 9);
      expect(eroded.at(5, 5), isTrue);
      expect(eroded.at(3, 3), isFalse);
    });
  });

  group('Silhouette.dilate', () {
    test('grows a single pixel into a full neighborhood', () {
      final mask = Silhouette.filled(11, 11, false);
      mask.set(5, 5, true);
      final dilated = mask.dilate(1);
      expect(dilated.foregroundCount, 9); // the full 3x3 neighborhood
      expect(dilated.at(4, 4), isTrue);
      expect(dilated.at(6, 6), isTrue);
    });
  });

  group('Silhouette.opened', () {
    test('erases a thin line while reconstructing a thick block exactly', () {
      final mask = Silhouette.filled(15, 15, false);
      for (var x = 1; x < 14; x++) {
        mask.set(x, 2, true); // thin line, well away from the block below
      }
      for (var y = 6; y < 12; y++) {
        for (var x = 4; x < 10; x++) {
          mask.set(x, y, true); // solid 6x6 block, away from image edges
        }
      }

      final opened = mask.opened(1);

      // Opening (erode then dilate) of an axis-aligned rectangle away
      // from the image border reconstructs it exactly; the thin line
      // doesn't survive erosion at all, so dilating an empty result stays
      // empty for it.
      expect(opened.foregroundCount, 36);
      for (var y = 6; y < 12; y++) {
        for (var x = 4; x < 10; x++) {
          expect(opened.at(x, y), isTrue, reason: 'block cell ($x,$y) should survive opening');
        }
      }
      for (var x = 1; x < 14; x++) {
        expect(opened.at(x, 2), isFalse, reason: 'thin line at ($x,2) should be erased by opening');
      }
    });
  });
}
