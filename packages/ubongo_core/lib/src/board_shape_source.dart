import 'cell_coord.dart';

/// Resolves which cells of a [width] x [height] bounding box form a
/// puzzle's board outline.
///
/// This is the seam between the solver (which only ever consumes a
/// `Set<CellCoord>`) and however that set was actually produced. The app's
/// manual grid-markup screen implements this by collecting taps; a future
/// automatic implementation (detecting the outline from a photo) would
/// implement it in the vision package instead — neither implementation
/// needs to know about the other, and this package needs to know about
/// neither.
abstract interface class BoardShapeSource {
  Future<Set<CellCoord>> resolveBoardShape({
    required int width,
    required int height,
  });
}
