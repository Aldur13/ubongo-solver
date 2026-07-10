import 'dart:math' as math;

import 'silhouette.dart';

double _ipow(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}

/// The 7 Hu invariant moments of a [Silhouette], log-scaled so magnitudes
/// are directly comparable (the same convention OpenCV's `matchShapes`
/// uses internally). Invariant to translation, scale, and rotation, which
/// is exactly the nuisance variation between a synthesized reference piece
/// silhouette and a photographed-then-corrected card icon of the same
/// piece.
class HuMoments {
  final List<double> values; // length 7

  const HuMoments(this.values);

  /// Sum of absolute differences between log-moments — a simpler, more
  /// numerically stable cousin of OpenCV's `matchShapes` I1 metric (which
  /// divides by each moment and blows up near zero). Lower is more similar;
  /// 0 is an exact match.
  double distanceTo(HuMoments other) {
    var sum = 0.0;
    for (var i = 0; i < values.length; i++) {
      sum += (values[i] - other.values[i]).abs();
    }
    return sum;
  }
}

/// Computes raw image moments M(p,q) = sum over foreground pixels of
/// x^p * y^q.
double _rawMoment(Silhouette mask, int p, int q) {
  var sum = 0.0;
  for (var y = 0; y < mask.height; y++) {
    for (var x = 0; x < mask.width; x++) {
      if (mask.at(x, y)) {
        sum += _ipow(x.toDouble(), p) * _ipow(y.toDouble(), q);
      }
    }
  }
  return sum;
}

/// Computes central moments mu(p,q) about the shape's own centroid —
/// makes the moments translation-invariant.
double _centralMoment(Silhouette mask, double xBar, double yBar, int p, int q) {
  var sum = 0.0;
  for (var y = 0; y < mask.height; y++) {
    for (var x = 0; x < mask.width; x++) {
      if (mask.at(x, y)) {
        sum += _ipow(x - xBar, p) * _ipow(y - yBar, q);
      }
    }
  }
  return sum;
}

/// Computes the 7 Hu invariant moments of [mask]. Returns all-zero moments
/// for an empty mask (no foreground pixels) rather than dividing by zero.
HuMoments computeHuMoments(Silhouette mask) {
  final m00 = _rawMoment(mask, 0, 0);
  if (m00 == 0) return const HuMoments([0, 0, 0, 0, 0, 0, 0]);

  final xBar = _rawMoment(mask, 1, 0) / m00;
  final yBar = _rawMoment(mask, 0, 1) / m00;
  final mu00 = _centralMoment(mask, xBar, yBar, 0, 0);

  double eta(int p, int q) {
    final gamma = (p + q) / 2.0 + 1;
    return _centralMoment(mask, xBar, yBar, p, q) / math.pow(mu00, gamma);
  }

  final n20 = eta(2, 0), n02 = eta(0, 2), n11 = eta(1, 1);
  final n30 = eta(3, 0), n12 = eta(1, 2), n21 = eta(2, 1), n03 = eta(0, 3);

  final h1 = n20 + n02;
  final h2 = _ipow(n20 - n02, 2) + 4 * _ipow(n11, 2);
  final h3 = _ipow(n30 - 3 * n12, 2) + _ipow(3 * n21 - n03, 2);
  final h4 = _ipow(n30 + n12, 2) + _ipow(n21 + n03, 2);
  final h5 = (n30 - 3 * n12) *
          (n30 + n12) *
          (_ipow(n30 + n12, 2) - 3 * _ipow(n21 + n03, 2)) +
      (3 * n21 - n03) *
          (n21 + n03) *
          (3 * _ipow(n30 + n12, 2) - _ipow(n21 + n03, 2));
  final h6 = (n20 - n02) * (_ipow(n30 + n12, 2) - _ipow(n21 + n03, 2)) +
      4 * n11 * (n30 + n12) * (n21 + n03);
  final h7 = (3 * n21 - n03) *
          (n30 + n12) *
          (_ipow(n30 + n12, 2) - 3 * _ipow(n21 + n03, 2)) -
      (n30 - 3 * n12) *
          (n21 + n03) *
          (3 * _ipow(n30 + n12, 2) - _ipow(n21 + n03, 2));

  // Below this, a moment's value is floating-point cancellation noise
  // around a true value of exactly zero (which happens for any shape with
  // a reflection symmetry line — h7 in particular is a difference of
  // near-equal terms for such shapes) rather than real signal. Log-scaling
  // noise that small would otherwise blow up into a huge apparent
  // difference between two computations of the "same" (zero) value.
  const noiseFloor = 1e-9;

  final rawHu = [h1, h2, h3, h4, h5, h6, h7];
  final logScaled = List<double>.generate(rawHu.length, (i) {
    final h = rawHu[i];
    final magnitude = h.abs();
    if (magnitude < noiseFloor) return 0.0;
    final logMag = math.log(magnitude) / math.ln10;
    // h7 (index 6) is Hu's "skew invariant": by design it flips sign under
    // reflection, to distinguish a shape from its mirror image. Card icons
    // are printed assets that are never physically mirrored (unlike the
    // solver's physical pieces, which legitimately can be flipped — see
    // ubongo_core's orientation generation), so for icon matching we want
    // mirror-*insensitivity* here rather than chirality discrimination —
    // take its magnitude only, like the other six moments.
    if (i == 6) return logMag;
    return h.isNegative ? -logMag : logMag;
  });

  return HuMoments(logScaled);
}
