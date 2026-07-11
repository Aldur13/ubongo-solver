import 'dart:math' as math;

import '../recognition/silhouette.dart';

/// Minimum number of peaks that must agree on a common lattice before
/// [fitGridLines] trusts it — 3 was found (empirically, via this
/// package's own test suite) to be too permissive: with only 3 points,
/// coincidental near-fits to an unrelated pitch are common enough to
/// produce false positives on non-grid input.
const _minInliers = 4;

/// Minimum fraction of *all* detected peaks that must fit the winning
/// lattice. An absolute inlier floor alone isn't enough: tested
/// empirically against random point sets (15 uniformly random peaks,
/// many random seeds), the RANSAC search below reliably found *some*
/// 4+-point coincidental alignment in every single trial — with enough
/// peaks and enough candidate (pitch, origin) pairs tried, a small
/// absolute inlier count is nearly always achievable by chance. A real
/// grid's peaks overwhelmingly belong to the lattice (occlusion drops a
/// peak from the list entirely, it doesn't add unrelated ones), so
/// requiring most of what was actually detected to fit is what actually
/// discriminates signal from noise.
const _minInlierRatio = 0.6;

/// Minimum fraction of the *implied* grid lines (span between the first
/// and last inlier, divided by pitch) that must actually have been
/// observed as inliers. Tolerates one occluded line (e.g. 4 observed
/// inliers implying 5 lines = 0.8) but rejects a small coincidental pitch
/// that "explains" only a sparse handful of points across a huge implied
/// span — see [fitGridLines]'s use of this constant for how this was
/// found necessary.
const _minLineDensity = 0.7;

/// Ink-pixel count per column — the raw signal grid-line detection works
/// from. A vertical grid line shows up as a sharp local peak.
List<int> columnInkProfile(Silhouette mask) {
  final profile = List<int>.filled(mask.width, 0);
  for (var x = 0; x < mask.width; x++) {
    var count = 0;
    for (var y = 0; y < mask.height; y++) {
      if (mask.at(x, y)) count++;
    }
    profile[x] = count;
  }
  return profile;
}

/// Ink-pixel count per row — the row-axis counterpart of
/// [columnInkProfile].
List<int> rowInkProfile(Silhouette mask) {
  final profile = List<int>.filled(mask.height, 0);
  for (var y = 0; y < mask.height; y++) {
    var count = 0;
    for (var x = 0; x < mask.width; x++) {
      if (mask.at(x, y)) count++;
    }
    profile[y] = count;
  }
  return profile;
}

/// Finds one peak position per contiguous above-noise-floor run in
/// [profile] (the position of that run's maximum value) — a simple
/// non-maximum-suppression that avoids reporting several adjacent indices
/// for what's really one thick line.
List<int> _findPeaks(List<int> profile) {
  if (profile.isEmpty) return const [];
  final mean = profile.reduce((a, b) => a + b) / profile.length;
  final variance =
      profile.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / profile.length;
  final noiseFloor = mean + math.sqrt(variance);

  final peaks = <int>[];
  var i = 0;
  while (i < profile.length) {
    if (profile[i] <= noiseFloor) {
      i++;
      continue;
    }
    var argmax = i;
    while (i < profile.length && profile[i] > noiseFloor) {
      if (profile[i] > profile[argmax]) argmax = i;
      i++;
    }
    peaks.add(argmax);
  }
  return peaks;
}

/// A fitted regular lattice of grid lines along one axis: lines sit at
/// `origin + k * pitch` for integer `k`, spanning `lineCount` lines
/// (`lineCount - 1` cells).
class GridLineFit {
  final double origin;
  final double pitch;
  final int lineCount;

  const GridLineFit({required this.origin, required this.pitch, required this.lineCount});

  int get cellCount => lineCount - 1;
}

/// Fits a regular lattice to the peaks found in [profile] via a
/// RANSAC-style consensus: every (pitch, origin) candidate pair is scored
/// by how many detected peaks land within [relativeTolerance] (as a
/// fraction of pitch) of an integer multiple of pitch from that origin,
/// and the best-scoring pair wins. This tolerates a single occluded/missed
/// line (the other peaks still agree on the same lattice) and a stray
/// peak from unrelated ink elsewhere in the image (it just won't fit any
/// consistent lattice and gets excluded as an outlier).
///
/// Returns null when there's no reliable lattice to report — fewer than
/// [_minInliers] detected peaks, or no candidate lattice attracts at
/// least that many inliers — rather than guessing.
///
/// [relativeTolerance] is a fraction of the candidate pitch, but it's
/// capped by [maxAbsoluteToleranceOffPitch] pixels regardless of pitch
/// size: tested empirically (random point sets, many seeds), a
/// tolerance that's *purely* relative gives large candidate pitches a
/// proportionally large absolute pixel window too, which made
/// coincidental alignment of unrelated/noise peaks common — real
/// detection jitter (anti-aliasing, thresholding, slight perspective
/// residue) is an absolute few pixels, not a percentage that grows with
/// pitch.
GridLineFit? fitGridLines(
  List<int> profile, {
  double relativeTolerance = 0.2,
  double maxAbsoluteToleranceOffPitch = 4,
  int minInliers = _minInliers,
  double minInlierRatio = _minInlierRatio,
  double minLineDensity = _minLineDensity,
}) {
  final peaks = _findPeaks(profile)..sort();
  if (peaks.length < minInliers) return null;

  // Candidate pitches are raw consecutive gaps only (deduplicated) — NOT
  // also divided by 2/3. A single missing (occluded) line is already
  // handled without division: its neighbors' gap is simply twice the true
  // pitch, but the *other*, unaffected consecutive gaps still directly
  // observe the true pitch. Also trying gap/2 and gap/3 as candidates was
  // tried and rejected: any pitch P's submultiples P/2, P/3 trivially fit
  // every peak P does (and often pick up extra coincidental fits besides),
  // which systematically biased the RANSAC consensus toward spuriously
  // small pitches on real (and test) data.
  final gapCandidates = <double>{};
  for (var i = 0; i < peaks.length - 1; i++) {
    final gap = (peaks[i + 1] - peaks[i]).toDouble();
    if (gap >= 2) gapCandidates.add(gap);
  }

  double? bestPitch;
  double? bestOrigin;
  var bestInlierCount = 0;

  for (final pitch in gapCandidates) {
    final toleranceFraction =
        math.min(relativeTolerance, maxAbsoluteToleranceOffPitch / pitch);
    for (final originCandidate in peaks) {
      var inliers = 0;
      for (final p in peaks) {
        final offset = (p - originCandidate) / pitch;
        final residual = (offset - offset.round()).abs();
        if (residual <= toleranceFraction) inliers++;
      }
      // On a tie, prefer the LARGER pitch: a smaller pitch that fits
      // exactly as many peaks is either a spurious submultiple or no more
      // informative, and a larger pitch means fewer, more confident lines.
      final better = inliers > bestInlierCount ||
          (inliers == bestInlierCount && bestPitch != null && pitch > bestPitch);
      if (better) {
        bestInlierCount = inliers;
        bestPitch = pitch;
        bestOrigin = originCandidate.toDouble();
      }
    }
  }

  if (bestPitch == null || bestOrigin == null || bestInlierCount < minInliers) return null;
  if (bestInlierCount / peaks.length < minInlierRatio) return null;

  final bestToleranceFraction =
      math.min(relativeTolerance, maxAbsoluteToleranceOffPitch / bestPitch);
  final inlierPeaks = peaks.where((p) {
    final offset = (p - bestOrigin!) / bestPitch!;
    return (offset - offset.round()).abs() <= bestToleranceFraction;
  }).toList();
  if (inlierPeaks.length < minInliers) return null;

  final spanStart = inlierPeaks.first.toDouble();
  final spanEnd = inlierPeaks.last.toDouble();
  final lineCount = ((spanEnd - spanStart) / bestPitch).round() + 1;
  if (lineCount < 2) return null;

  // The clearest tell of a spurious small-pitch fit: it *implies* far
  // more grid lines (by spanning many pitch-multiples between the first
  // and last inlier) than were actually observed as peaks. A real grid
  // (occlusion tolerance aside) has almost every implied line show up as
  // an actual peak; a coincidental fit typically explains only a small,
  // scattered fraction of a huge implied span. This is what finally
  // rejected every case the inlier-count and inlier-ratio checks above
  // still let through when empirically fuzzed against random point sets.
  if (inlierPeaks.length / lineCount < minLineDensity) return null;

  return GridLineFit(origin: spanStart, pitch: bestPitch, lineCount: lineCount);
}

/// The detected grid geometry of a board photo: where its cells sit
/// (origin + pitch per axis) and how many rows/columns it has.
class GridGeometry {
  final double originX;
  final double pitchX;
  final int cols;
  final double originY;
  final double pitchY;
  final int rows;

  const GridGeometry({
    required this.originX,
    required this.pitchX,
    required this.cols,
    required this.originY,
    required this.pitchY,
    required this.rows,
  });
}

/// Detects the grid geometry of [inkMask] (a thresholded card photo),
/// fitting each axis independently via [fitGridLines]. Returns null if
/// either axis doesn't resolve to a reliable lattice.
///
/// This assumes [inkMask] marks thin grid lines directly (foreground =
/// ink) spanning the full card — real Ubongo cards don't print a grid
/// outside their outline, so this isn't what production board-outline
/// detection uses (see [detectGridGeometryFromMask] instead); kept for
/// its existing tests and because it's the correct tool if a different
/// card layout ever does print a full grid.
GridGeometry? detectGridGeometry(Silhouette inkMask) {
  final colFit = fitGridLines(columnInkProfile(inkMask));
  final rowFit = fitGridLines(rowInkProfile(inkMask));
  if (colFit == null || rowFit == null) return null;
  if (colFit.cellCount < 1 || rowFit.cellCount < 1) return null;

  return GridGeometry(
    originX: colFit.origin,
    pitchX: colFit.pitch,
    cols: colFit.cellCount,
    originY: rowFit.origin,
    pitchY: rowFit.pitch,
    rows: rowFit.cellCount,
  );
}

/// One group of nearby light/dark transition positions along a single
/// axis, collapsed into a single boundary-line estimate — see
/// [clusterBoundaryPositions].
class BoundaryCluster {
  /// Mean position of every transition in this cluster.
  final double position;

  /// Number of transitions merged into this cluster (roughly: how many
  /// rows/columns actually observed a boundary here) — a noisy/wobbly
  /// real edge still merges into one cluster as long as no single jump
  /// between consecutive sorted transitions exceeds the merge tolerance.
  final int weight;

  const BoundaryCluster(this.position, this.weight);
}

/// Real card photos: a straight printed edge rarely lands on the exact
/// same pixel column/row across every row/column it spans — camera
/// noise, JPEG blocking, and residual sub-pixel rotation after
/// perspective correction all make it wobble by a few pixels. Histogram-
/// style per-pixel counting (as [columnInkProfile]/[rowInkProfile] do)
/// splits that wobble across several adjacent bins, none of which may
/// clear a global noise floor on their own. Clustering the raw
/// transition positions directly (sort, then split wherever a gap
/// exceeds [mergeTolerance]) tolerates that wobble by construction.
///
/// A cluster additionally can't grow past [maxClusterSpan] from its own
/// first (lowest) member, even if every consecutive gap along the way is
/// within [mergeTolerance] — plain nearest-neighbor chaining (merge
/// whenever adjacent-in-sorted-order points are close) has no such cap,
/// and a moderate scatter of real-photo noise (icon-strip contamination,
/// anti-aliasing) is often just dense enough that consecutive noise
/// points stay within tolerance of each other across a huge span,
/// silently fusing many unrelated edges into one nonsense "cluster" —
/// caught during real-photo testing by a cluster's reported weight
/// exceeding the mask's own height/width, which is otherwise impossible.
List<BoundaryCluster> clusterBoundaryPositions(
  List<double> positions, {
  double mergeTolerance = 3,
  double? maxClusterSpan,
}) {
  if (positions.isEmpty) return const [];
  final span = maxClusterSpan ?? mergeTolerance * 2;
  final sorted = [...positions]..sort();

  final clusters = <BoundaryCluster>[];
  var groupStart = 0;
  for (var i = 1; i <= sorted.length; i++) {
    final atEnd = i == sorted.length;
    final tooFarFromNeighbor = !atEnd && sorted[i] - sorted[i - 1] > mergeTolerance;
    final tooFarFromGroupStart = !atEnd && sorted[i] - sorted[groupStart] > span;
    if (atEnd || tooFarFromNeighbor || tooFarFromGroupStart) {
      final group = sorted.sublist(groupStart, i);
      final mean = group.reduce((a, b) => a + b) / group.length;
      clusters.add(BoundaryCluster(mean, group.length));
      groupStart = i;
    }
  }
  return clusters;
}

/// Every x position within one row where [mask] flips between
/// background and foreground — the raw signal a vertical (column-axis)
/// boundary line leaves behind, one sample per row it spans.
List<double> _verticalTransitionPositions(Silhouette mask) {
  final positions = <double>[];
  for (var y = 0; y < mask.height; y++) {
    var previous = false;
    for (var x = 0; x <= mask.width; x++) {
      final current = x < mask.width && mask.at(x, y);
      if (current != previous) positions.add(x - 0.5);
      previous = current;
    }
  }
  return positions;
}

/// Row-axis counterpart of [_verticalTransitionPositions].
List<double> _horizontalTransitionPositions(Silhouette mask) {
  final positions = <double>[];
  for (var x = 0; x < mask.width; x++) {
    var previous = false;
    for (var y = 0; y <= mask.height; y++) {
      final current = y < mask.height && mask.at(x, y);
      if (current != previous) positions.add(y - 0.5);
      previous = current;
    }
  }
  return positions;
}

List<int> _profileFromClusters(List<BoundaryCluster> clusters, int length) {
  final profile = List<int>.filled(length, 0);
  for (final cluster in clusters) {
    final index = cluster.position.round().clamp(0, length - 1);
    profile[index] += cluster.weight;
  }
  return profile;
}

/// Fraction of the mask's cross-axis extent a boundary cluster's weight
/// must reach to be treated as a real edge rather than photo/print
/// noise. A genuine straight boundary segment spans a real fraction of
/// the shape (at least most of one cell's worth); a JPEG-block or
/// anti-aliasing artifact only ever flips at a handful of isolated
/// rows/columns. Unlike [fitGridLines]'s RANSAC inlier count (which
/// treats every candidate position as equally confident once it exists),
/// this cluster weight is a genuine confidence signal available here
/// that thin-grid-line detection never had — real photo testing (see the
/// board-outline scanning fix) found spurious single-digit-weight
/// clusters far outnumbering the real ones, diluting RANSAC's inlier
/// ratio below its threshold even though the real edges were clearly
/// distinguishable by weight alone.
const _minClusterWeightFraction = 0.15;

/// Two cells that are *both* part of the outline and sit next to each
/// other share an invisible boundary — both sides are foreground, so no
/// edge is observable there at all. Unlike a separately-printed grid
/// (where every cell boundary is drawn, occlusion aside), a simple
/// outline shape can genuinely have as few as 2-3 observable boundary
/// positions per axis. [fitGridLines]'s default `minInliers: 4` was
/// tuned against the many-observed-lines case and rejects real (if
/// sparse) fits here; 3 is used instead, relying on
/// [_minClusterWeightFraction] having already screened out low-
/// confidence noise before RANSAC ever sees these candidates — a
/// confidence signal the thin-grid-line path never had.
const _maskGeometryMinInliers = 3;

/// Detects grid geometry directly from a solid inside/outside mask (e.g.
/// the largest connected light-colored region of a real card photo,
/// after [Silhouette.otsuThreshold] — see `board_outline_detector.dart`)
/// rather than from a separately-printed grid of thin lines. The mask's
/// own boundary — where it's a straight run bordering a puzzle piece's
/// unit cells — *is* the grid: clusters the boundary's transition
/// positions along each axis ([clusterBoundaryPositions]), discards
/// low-weight (likely noise) clusters, and reuses [fitGridLines]'s
/// RANSAC lattice fit (with a relaxed inlier floor — see
/// [_maskGeometryMinInliers]) on the resulting cluster profile.
GridGeometry? detectGridGeometryFromMask(Silhouette insideMask, {double mergeTolerance = 3}) {
  final colClusters = clusterBoundaryPositions(
    _verticalTransitionPositions(insideMask),
    mergeTolerance: mergeTolerance,
  ).where((c) => c.weight >= insideMask.height * _minClusterWeightFraction).toList();
  final rowClusters = clusterBoundaryPositions(
    _horizontalTransitionPositions(insideMask),
    mergeTolerance: mergeTolerance,
  ).where((c) => c.weight >= insideMask.width * _minClusterWeightFraction).toList();

  final colFit = fitGridLines(
    _profileFromClusters(colClusters, insideMask.width + 1),
    minInliers: _maskGeometryMinInliers,
  );
  final rowFit = fitGridLines(
    _profileFromClusters(rowClusters, insideMask.height + 1),
    minInliers: _maskGeometryMinInliers,
  );
  if (colFit == null || rowFit == null) return null;
  if (colFit.cellCount < 1 || rowFit.cellCount < 1) return null;

  return GridGeometry(
    originX: colFit.origin,
    pitchX: colFit.pitch,
    cols: colFit.cellCount,
    originY: rowFit.origin,
    pitchY: rowFit.pitch,
    rows: rowFit.cellCount,
  );
}
