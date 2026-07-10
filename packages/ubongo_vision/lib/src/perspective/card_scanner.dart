import '../rgb_image.dart';

/// A card photo that's been perspective-corrected to a flat top-down
/// rectangle.
class CorrectedCardImage {
  final RgbImage image;
  const CorrectedCardImage(this.image);
}

/// Obtains a perspective-corrected photo of a physical puzzle card.
///
/// Implementations differ in how they get there: [NativeScannerImpl] hands
/// the whole capture+crop+correct flow to the platform's own document-
/// scanner UI; [OpenCvScannerImpl] is a documented placeholder for a
/// hand-rolled OpenCV contour-detection + warp pipeline. Callers only
/// depend on this interface, so swapping the implementation never touches
/// the rest of the app — the same seam the abstract `BoardShapeSource` in
/// `ubongo_core` uses for the (separately-scoped) board-outline step.
abstract interface class CardScanner {
  /// Launches the scan flow and returns the corrected image, or null if
  /// the user cancelled.
  Future<CorrectedCardImage?> scanCard();
}
