import 'package:flutter_test/flutter_test.dart';
import 'package:ubongo_core/ubongo_core.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

import '../support/synthetic_card_renderer.dart';

CellCoord c(int r, int col) => CellCoord(r, col);

void main() {
  test('DetectionParams.copyWith overrides only the given field', () {
    const params = DetectionParams(fillThreshold: 0.5);
    final updated = params.copyWith(fillThreshold: 0.7);

    expect(updated.fillThreshold, 0.7);
    expect(params.fillThreshold, 0.5); // original untouched
  });

  test('fillThreshold is load-bearing: too strict rejects an otherwise-detectable card', () async {
    // Detection reports the outline's own tight bounding box in local
    // (0,0)-based coordinates -- {(1,1),(2,1),(2,2)} in this 5x5 canvas
    // becomes {(0,0),(1,0),(1,1)} in the result.
    final outline = {c(1, 1), c(2, 1), c(2, 2)};
    final image = renderSyntheticCard(gridWidth: 5, gridHeight: 5, outlineCells: outline);

    final withDefaultParams = await detectBoardShape(image);
    expect(withDefaultParams, isNotNull);
    expect(withDefaultParams!.cells, {c(0, 0), c(1, 0), c(1, 1)});

    // A threshold above 1.0 can never be exceeded by any fraction in
    // [0, 1], so every candidate cell is rejected.
    final withImpossibleThreshold = await detectBoardShape(
      image,
      params: const DetectionParams(fillThreshold: 1.01),
    );
    expect(withImpossibleThreshold, isNull);
  });
}
