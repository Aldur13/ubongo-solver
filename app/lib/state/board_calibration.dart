import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

const _fillThresholdKey = 'board_calibration_fill_threshold';
const _minFillThreshold = 0.3;
const _maxFillThreshold = 0.7;
const _adjustmentStep = 0.02;

double _clampThreshold(double value) {
  if (value < _minFillThreshold) return _minFillThreshold;
  if (value > _maxFillThreshold) return _maxFillThreshold;
  return value;
}

/// Per-device [DetectionParams], persisted across launches and nudged
/// over time by how the user corrects auto-detected boards.
///
/// This is a lightweight on-device adaptive heuristic, not a trained
/// model — see the project plan's "Increment 3" notes. There's no
/// training data or server here, just a small proportional adjustment:
/// consistent under-detection nudges the fill threshold down, consistent
/// over-detection nudges it up.
class BoardCalibrationNotifier extends Notifier<DetectionParams> {
  @override
  DetectionParams build() {
    _loadPersisted();
    return const DetectionParams();
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_fillThresholdKey);
    if (stored != null) {
      state = state.copyWith(fillThreshold: stored);
    }
  }

  /// Nudges [DetectionParams.fillThreshold] based on how the user
  /// corrected a detected board: more added cells (the detector was
  /// under-inclusive/too strict) lowers the threshold; more removed cells
  /// (over-inclusive/too lax) raises it. A perfect match (both zero)
  /// makes no change — a single confirmation isn't reinforced further, to
  /// avoid drifting on noise. Persists the result immediately.
  Future<void> recordCorrection({required int added, required int removed}) async {
    if (added == 0 && removed == 0) return;

    final bias = added - removed;
    final delta = bias > 0 ? -_adjustmentStep : _adjustmentStep;
    final next = _clampThreshold(state.fillThreshold + delta);
    state = state.copyWith(fillThreshold: next);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fillThresholdKey, next);
  }
}

final boardCalibrationProvider =
    NotifierProvider<BoardCalibrationNotifier, DetectionParams>(
  BoardCalibrationNotifier.new,
);
