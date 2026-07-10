import 'package:flutter_test/flutter_test.dart';
import 'package:ubongo_core/ubongo_core.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

/// A solid-color-filled icon, like a card marking "use exactly this piece".
RgbImage _renderSolidIcon(Piece piece, {int pixelsPerCell = 20}) {
  final mask = renderCells(piece.cells, pixelsPerCell: pixelsPerCell);
  final image = RgbImage.blank(mask.width, mask.height);
  for (var y = 0; y < mask.height; y++) {
    for (var x = 0; x < mask.width; x++) {
      if (mask.at(x, y)) image.setPixel(x, y, 200, 30, 30); // saturated red
    }
  }
  return image;
}

/// A gray/outline-only icon, like a card marking "any piece this size".
RgbImage _renderOutlineIcon(Piece piece, {int pixelsPerCell = 20}) {
  final mask = renderCells(piece.cells, pixelsPerCell: pixelsPerCell);
  final image = RgbImage.blank(mask.width, mask.height);
  for (var y = 0; y < mask.height; y++) {
    for (var x = 0; x < mask.width; x++) {
      if (!mask.at(x, y)) continue;
      final isBorder = !(x > 0 && mask.at(x - 1, y)) ||
          !(x < mask.width - 1 && mask.at(x + 1, y)) ||
          !(y > 0 && mask.at(x, y - 1)) ||
          !(y < mask.height - 1 && mask.at(x, y + 1));
      if (isBorder) image.setPixel(x, y, 90, 90, 90); // unsaturated gray stroke
    }
  }
  return image;
}

void main() {
  final recognizer = IconRecognizer(ShapeMatcher(catalog: UbongoCatalog.classic));

  test('a solid-color icon recognizes its piece and classifies as a SolidSlot', () {
    final piece = UbongoCatalog.classic.firstWhere((p) => p.id == 'P11');
    final result = recognizer.recognize(_renderSolidIcon(piece));

    expect(result.slot, isA<SolidSlot>());
    expect((result.slot as SolidSlot).piece.id, 'P11');
  });

  test('a gray/outline icon recognizes its piece\'s shape and classifies as a GraySlot', () {
    final piece = UbongoCatalog.classic.firstWhere((p) => p.id == 'P10');
    final result = recognizer.recognize(_renderOutlineIcon(piece));

    expect(result.slot, isA<GraySlot>());
    expect((result.slot as GraySlot).cellCount, piece.cellCount);
  });

  test('classifyFill agrees: saturated fill is solid, gray stroke is outline', () {
    final piece = UbongoCatalog.classic.firstWhere((p) => p.id == 'P4');
    final solidImage = _renderSolidIcon(piece);
    final outlineImage = _renderOutlineIcon(piece);

    final solidMask = Silhouette.threshold(solidImage);
    final outlineMask = Silhouette.threshold(outlineImage);

    expect(classifyFill(solidImage, solidMask), FillStyle.solid);
    expect(classifyFill(outlineImage, outlineMask), FillStyle.outline);
  });
}
