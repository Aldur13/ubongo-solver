import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubongo_solver/state/board_calibration.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a perfect match (no diff) does not change the threshold', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final initial = container.read(boardCalibrationProvider).fillThreshold;

    await container.read(boardCalibrationProvider.notifier).recordCorrection(added: 0, removed: 0);

    expect(container.read(boardCalibrationProvider).fillThreshold, initial);
  });

  test('consistent under-detection (more additions) trends the threshold down, '
      'clamped at 0.3', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(boardCalibrationProvider.notifier);

    for (var i = 0; i < 20; i++) {
      await notifier.recordCorrection(added: 2, removed: 0);
    }

    expect(container.read(boardCalibrationProvider).fillThreshold, closeTo(0.3, 0.001));
  });

  test('consistent over-detection (more removals) trends the threshold up, '
      'clamped at 0.7', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(boardCalibrationProvider.notifier);

    for (var i = 0; i < 20; i++) {
      await notifier.recordCorrection(added: 0, removed: 2);
    }

    expect(container.read(boardCalibrationProvider).fillThreshold, closeTo(0.7, 0.001));
  });

  test('mixed corrections net out per the added-minus-removed bias', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(boardCalibrationProvider.notifier);
    final initial = container.read(boardCalibrationProvider).fillThreshold;

    // added > removed -> under-detection bias -> threshold decreases.
    await notifier.recordCorrection(added: 3, removed: 1);

    expect(container.read(boardCalibrationProvider).fillThreshold, lessThan(initial));
  });

  test('persists the adjusted threshold for a fresh provider container', () async {
    final container1 = ProviderContainer();
    await container1.read(boardCalibrationProvider.notifier).recordCorrection(added: 3, removed: 0);
    final adjusted = container1.read(boardCalibrationProvider).fillThreshold;
    container1.dispose();

    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    container2.read(boardCalibrationProvider); // triggers build(), which loads persisted state
    await pumpEventQueue();

    expect(container2.read(boardCalibrationProvider).fillThreshold, adjusted);
  });
}
