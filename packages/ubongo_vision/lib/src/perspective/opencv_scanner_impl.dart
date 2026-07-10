import 'card_scanner.dart';

/// Placeholder for an OpenCV-based [CardScanner] (contour detection +
/// `warpPerspective` via `opencv_dart`), kept behind the same interface as
/// [NativeScannerImpl] so it's a drop-in swap if the native document-
/// scanner UI turns out not to auto-detect Ubongo cards well.
///
/// Deliberately unimplemented for now: the project plan flags
/// `opencv_dart`'s native-assets packaging as needing a dedicated
/// on-device validation spike (real Android + iOS hardware) before it's
/// load-bearing, which hasn't happened yet. Wiring this up for real means:
///   1. Capture a raw camera frame (e.g. via the `camera` plugin).
///   2. Grayscale + threshold, `findContours`, keep the largest 4-point
///      `approxPolyDP` result as the card's corners.
///   3. Order the 4 corners consistently, `getPerspectiveTransform`, then
///      `warpPerspective` to a flat top-down rectangle.
class OpenCvScannerImpl implements CardScanner {
  @override
  Future<CorrectedCardImage?> scanCard() {
    throw UnimplementedError(
      'OpenCvScannerImpl is a documented placeholder (see class doc) — '
      'use NativeScannerImpl until this pipeline is built and validated '
      'on real devices.',
    );
  }
}
