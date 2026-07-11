/// Tunable numeric parameters for [detectBoardShape] (see
/// `board_outline_detector.dart`).
///
/// [fillThreshold] starts as a reasoned hypothesis about real card print
/// characteristics, not a validated constant. The app layer persists a
/// per-device [DetectionParams], nudged over time based on how often/
/// which-direction the user corrects detected boards — see the app's
/// `state/board_calibration.dart`. This class itself stays a plain,
/// storage-agnostic value type so `ubongo_vision` doesn't need to know
/// anything about persistence.
class DetectionParams {
  /// Fraction of a cell's sampled interior that must be light-colored
  /// (part of the detected board region) for that cell to be classified
  /// as inside the puzzle shape. Higher = stricter (fewer cells
  /// classified as inside).
  final double fillThreshold;

  const DetectionParams({this.fillThreshold = 0.5});

  DetectionParams copyWith({double? fillThreshold}) {
    return DetectionParams(fillThreshold: fillThreshold ?? this.fillThreshold);
  }
}
