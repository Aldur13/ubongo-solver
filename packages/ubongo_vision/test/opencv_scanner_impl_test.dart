import 'package:flutter_test/flutter_test.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

void main() {
  test('OpenCvScannerImpl is a documented placeholder, not silently broken', () {
    expect(
      () => OpenCvScannerImpl().scanCard(),
      throwsA(isA<UnimplementedError>()),
    );
  });
}
