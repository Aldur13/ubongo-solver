/// Tunable numeric parameters for [detectBoardShape] (see
/// `board_outline_detector.dart`).
///
/// These start as reasoned hypotheses about real card print
/// characteristics (see that file's doc comments), not validated
/// constants. The app layer persists a per-device [DetectionParams],
/// nudged over time based on how often/which-direction the user corrects
/// detected boards — see the app's `state/board_calibration.dart`. This
/// class itself stays a plain, storage-agnostic value type so
/// `ubongo_vision` doesn't need to know anything about persistence.
class DetectionParams {
  /// Fraction of a cell's sampled interior that must be foreground (after
  /// isolating and filling the bold outline) for that cell to be
  /// classified as inside the puzzle shape. Higher = stricter (fewer
  /// cells classified as inside).
  final double fillThreshold;

  /// Morphological opening structuring-element radius, as a fraction of
  /// the detected grid pitch — used to erase thin grid lines while
  /// preserving the thicker bold outline. Higher = removes thicker lines
  /// too (risking erasing the outline itself); lower = may leave thin
  /// grid lines intact (breaking the single-enclosed-region assumption).
  final double erosionRadiusScale;

  const DetectionParams({
    this.fillThreshold = 0.5,
    this.erosionRadiusScale = 0.03,
  });

  DetectionParams copyWith({double? fillThreshold, double? erosionRadiusScale}) {
    return DetectionParams(
      fillThreshold: fillThreshold ?? this.fillThreshold,
      erosionRadiusScale: erosionRadiusScale ?? this.erosionRadiusScale,
    );
  }
}
