import 'package:ubongo_core/ubongo_core.dart';

import '../rgb_image.dart';
import 'shape_matcher.dart';
import 'silhouette.dart';

/// One card requirement recovered from a scanned icon, plus how confident
/// the shape match was (lower [matchDistance] is more confident — see
/// [HuMoments.distanceTo]).
class RecognizedRequirement {
  final PieceSlot slot;
  final double matchDistance;
  const RecognizedRequirement(this.slot, this.matchDistance);
}

/// End-to-end recognition of one piece-icon crop from a perspective-
/// corrected card image: threshold it, isolate the icon's shape from any
/// stray noise, match it against the catalog, and classify solid-vs-gray
/// fill to determine whether the card is pinning an exact piece or
/// accepting any piece of that size.
class IconRecognizer {
  final ShapeMatcher matcher;

  IconRecognizer(this.matcher);

  RecognizedRequirement recognize(RgbImage iconRegion, {int threshold = 128}) {
    final rawMask = Silhouette.threshold(iconRegion, threshold: threshold);
    // A gray/outline icon's ink is only its traced border, not its
    // interior — fill that back in so ring-shaped and solid-shaped icons
    // of the same piece produce the same silhouette for matching.
    final cleanedMask = rawMask.largestComponentCropped().fillEnclosedHoles();

    final match = matcher.bestMatch(cleanedMask);
    // Fill classification uses the un-cropped mask (same coordinate frame
    // as iconRegion) so pixel lookups line up; a handful of stray noise
    // pixels don't meaningfully skew an average saturation.
    final fill = classifyFill(iconRegion, rawMask);

    final slot = fill == FillStyle.solid
        ? SolidSlot(match.piece)
        : GraySlot(match.piece.cellCount);
    return RecognizedRequirement(slot, match.distance);
  }
}
