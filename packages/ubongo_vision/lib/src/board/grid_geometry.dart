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
}) {
  final peaks = _findPeaks(profile)..sort();
  if (peaks.length < _minInliers) return null;

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

  if (bestPitch == null || bestOrigin == null || bestInlierCount < _minInliers) return null;
  if (bestInlierCount / peaks.length < _minInlierRatio) return null;

  final bestToleranceFraction =
      math.min(relativeTolerance, maxAbsoluteToleranceOffPitch / bestPitch);
  final inlierPeaks = peaks.where((p) {
    final offset = (p - bestOrigin!) / bestPitch!;
    return (offset - offset.round()).abs() <= bestToleranceFraction;
  }).toList();
  if (inlierPeaks.length < _minInliers) return null;

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
  if (inlierPeaks.length / lineCount < _minLineDensity) return null;

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
