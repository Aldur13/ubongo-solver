import 'package:ubongo_core/ubongo_core.dart';

import '../rgb_image.dart';
import 'hu_moments.dart';
import 'piece_catalog_renderer.dart';
import 'silhouette.dart';

class ShapeMatch {
  final Piece piece;
  final double distance;
  const ShapeMatch(this.piece, this.distance);
}

/// Matches a scanned icon's shape against a fixed catalog of pieces by
/// comparing Hu moments, rather than raw pixel/template matching — the
/// right tool for a closed-set, known-in-advance shape catalog rather than
/// open-ended object recognition.
class ShapeMatcher {
  final List<Piece> catalog;
  final PieceCatalogRenderer renderer;
  late final Map<String, HuMoments> _referenceMoments;

  ShapeMatcher({required this.catalog, PieceCatalogRenderer? renderer})
      : renderer = renderer ?? PieceCatalogRenderer() {
    _referenceMoments = {
      for (final piece in catalog)
        piece.id: computeHuMoments(this.renderer.render(piece)),
    };
  }

  /// Every catalog piece ranked by similarity to [candidate], best match
  /// first.
  List<ShapeMatch> rankMatches(Silhouette candidate) {
    final candidateMoments = computeHuMoments(candidate);
    final matches = catalog
        .map((piece) => ShapeMatch(
              piece,
              candidateMoments.distanceTo(_referenceMoments[piece.id]!),
            ))
        .toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));
    return matches;
  }

  ShapeMatch bestMatch(Silhouette candidate) => rankMatches(candidate).first;
}

enum FillStyle { solid, outline }

/// Classifies whether a scanned icon is drawn solid-color (the card
/// requires exactly that piece) or as a gray/white outline (the card
/// accepts any piece with a matching cell count), by the average color
/// saturation over the icon's own foreground pixels.
FillStyle classifyFill(
  RgbImage region,
  Silhouette mask, {
  double saturationThreshold = 0.25,
}) {
  var saturationSum = 0.0;
  var count = 0;
  for (var y = 0; y < mask.height; y++) {
    for (var x = 0; x < mask.width; x++) {
      if (!mask.at(x, y)) continue;
      final (r, g, b, _) = region.pixelAt(x, y);
      final maxC = [r, g, b].reduce((a, b) => a > b ? a : b);
      final minC = [r, g, b].reduce((a, b) => a < b ? a : b);
      final saturation = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
      saturationSum += saturation;
      count++;
    }
  }
  if (count == 0) return FillStyle.outline;
  return (saturationSum / count) > saturationThreshold
      ? FillStyle.solid
      : FillStyle.outline;
}
