import 'package:ubongo_vision/ubongo_vision.dart';

/// Bundles the corrected card photo together with (if detection
/// succeeded) the board shape auto-detected from it, so `GridMarkupScreen`
/// can both show the photo as a reference AND, later, diff the user's
/// final corrections against what was originally detected — see
/// `state/board_calibration.dart`.
class ScannedBoardData {
  final CorrectedCardImage corrected;
  final DetectedBoardShape? detectedShape;

  const ScannedBoardData({required this.corrected, this.detectedShape});
}
