import 'package:flutter_test/flutter_test.dart';
import 'package:ubongo_core/ubongo_core.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

import '../support/synthetic_card_renderer.dart';

CellCoord c(int r, int col) => CellCoord(r, col);

void main() {
  test('erosionRadiusScale is load-bearing: too large erases the bold outline itself', () async {
    final outline = {c(1, 1), c(2, 1), c(2, 2)};
    // boldLineWidth 5 survives a small erosion radius but not a large one.
    final image = renderSyntheticCard(gridWidth: 5, gridHeight: 5, outlineCells: outline);

    final withDefaultParams = await detectBoardShape(image);
    expect(withDefaultParams, isNotNull);
    expect(withDefaultParams!.cells, outline);

    // erosionRadiusScale high enough that radius*2 exceeds the bold
    // line's own width erases it along with the thin grid lines, leaving
    // nothing for fillEnclosedHoles to work with.
    final withAggressiveErosion = await detectBoardShape(
      image,
      params: const DetectionParams(erosionRadiusScale: 0.5),
    );
    expect(withAggressiveErosion, isNull);
  });
}
