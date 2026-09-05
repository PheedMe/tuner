import 'dart:math' as math;

/// Detects the fundamental frequency (in Hz) of a monophonic audio buffer
/// using the YIN algorithm.
///
/// YIN is more robust than plain autocorrelation for harmonic-rich or
/// sustained tones (drones, synth pads, bowed strings) because it searches
/// for the first clear periodic dip in a normalized difference function,
/// rather than picking whichever lag has the single strongest correlation.
/// Plain autocorrelation can lock onto a strong overtone (e.g. a third or
/// sixth away from the true note) when the fundamental is weak relative
/// to its harmonics — YIN's thresholded search largely avoids that.
///
/// Reference: de Cheveigné & Kawahara, "YIN, a fundamental frequency
/// estimator for speech and music" (2002).
///
/// Returns `null` if the signal is too quiet or no reliable pitch is found.
///
/// [samples] should be normalized floats in roughly [-1.0, 1.0].
/// [sampleRate] is the audio sample rate in Hz (e.g. 44100).
/// [minHz] / [maxHz] bound the search range — tighten these for your use
/// case (e.g. human voice ~80-1000 Hz) to improve speed and accuracy.
/// [threshold] is YIN's absolute threshold — lower values require a
/// cleaner periodic signal before accepting a pitch (fewer false
/// positives, but may miss quieter/noisier notes). Typical range is
/// 0.05-0.15; lower it further (e.g. 0.05-0.08) if you see systematic
/// sharp errors on sustained/harmonic-rich tones (drones, pads) — that
/// pattern means a spurious shorter-lag dip is clearing the threshold
/// before the true, cleaner fundamental dip is reached.
double? detectPitch(
  List<double> samples,
  double sampleRate, {
  double minHz = 60,
  double maxHz = 1000,
  double silenceRmsThreshold = 0.01,
  double threshold = 0.1,
}) {
  final n = samples.length;
  if (n < 2) return null;

  // Skip near-silence to avoid spurious low-confidence detections.
  double sumSquares = 0;
  for (final s in samples) {
    sumSquares += s * s;
  }
  final rms = math.sqrt(sumSquares / n);
  if (rms < silenceRmsThreshold) return null;

  // Apply a Hann window before analysis. A raw rectangular buffer has an
  // abrupt discontinuity at its edges (the signal doesn't return to zero
  // at the start/end), which introduces spectral leakage — this can
  // create spurious periodic-looking patterns that YIN mistakes for a
  // real (but wrong) pitch, especially on harmonic-rich/sustained tones.
  // Windowing tapers the edges smoothly to reduce this artifact.
  final windowed = _applyHannWindow(samples);

  final tauMin = (sampleRate / maxHz).floor().clamp(1, n - 1);
  final tauMax = (sampleRate / minHz).floor().clamp(1, n - 1);
  if (tauMin >= tauMax) return null;

  // --- Step 1: difference function ---
  // d(tau) = sum_j (x[j] - x[j+tau])^2
  // Low values of d(tau) indicate the signal at lag `tau` looks similar
  // to the original — i.e. a candidate period.
  final diff = List<double>.filled(tauMax + 1, 0.0);
  for (int tau = 1; tau <= tauMax; tau++) {
    double sum = 0;
    for (int j = 0; j < n - tau; j++) {
      final delta = windowed[j] - windowed[j + tau];
      sum += delta * delta;
    }
    diff[tau] = sum;
  }

  // --- Step 2: cumulative mean normalized difference function (CMNDF) ---
  // This is YIN's key trick: normalizing by the running average difference
  // so early small-tau noise doesn't dominate, and so the function starts
  // at 1 and dips toward 0 at the true period — making a fixed threshold
  // meaningful regardless of signal amplitude or harmonic content.
  final cmndf = List<double>.filled(tauMax + 1, 1.0);
  double runningSum = 0;
  for (int tau = 1; tau <= tauMax; tau++) {
    runningSum += diff[tau];
    cmndf[tau] = runningSum > 0 ? diff[tau] * tau / runningSum : 1.0;
  }

  // --- Step 3: absolute threshold search ---
  // Find the FIRST tau (within our min/max range) where CMNDF dips below
  // the threshold, then walk forward to the local minimum of that dip.
  // Taking the *first* qualifying dip (not the global minimum) is what
  // makes YIN prefer the true fundamental over a stronger-but-wrong
  // harmonic match at a shorter or longer lag.
  int tauEstimate = -1;
  for (int tau = tauMin; tau <= tauMax; tau++) {
    if (cmndf[tau] < threshold) {
      while (tau + 1 <= tauMax && cmndf[tau + 1] < cmndf[tau]) {
        tau++;
      }
      tauEstimate = tau;
      break;
    }
  }

  // Fallback: nothing cleared the threshold. Rather than giving up, take
  // the global minimum of CMNDF across the whole range — this is the
  // standard YIN fallback (per the original paper) and matters a lot in
  // practice: some real signals (e.g. certain drone/pad tones) never
  // produce a dip clean enough to clear a strict threshold, even though
  // there's still a clear best candidate. Without this fallback, tightening
  // the threshold to fix harmonic-confusion errors can cause total dropout
  // on other notes instead.
  if (tauEstimate == -1) {
    double minVal = double.infinity;
    for (int tau = tauMin; tau <= tauMax; tau++) {
      if (cmndf[tau] < minVal) {
        minVal = cmndf[tau];
        tauEstimate = tau;
      }
    }
  }

  if (tauEstimate == -1) return null;

  // --- Step 3b: sub-harmonic (multiple-of-tau) correction ---
  // Real instruments — especially thick/stiff strings like a cello's low
  // C string — exhibit "inharmonicity": their upper partials aren't at
  // exact integer multiples of the fundamental, they're stretched
  // slightly sharp by the string's physical stiffness. If the initial
  // tauEstimate landed on one of these upper partials (a shorter lag,
  // since we scan short-to-long), it will report a frequency that's
  // both wrong-octave AND slightly sharp of the "clean" harmonic —
  // which is exactly the kind of error a simple 2x octave check can
  // miss if the true fundamental is 3-4+ octaves below the detected
  // partial. Check several integer multiples of tauEstimate and prefer
  // the longest lag (lowest frequency) whose CMNDF value is still
  // comparably good — that's very likely the true, stable fundamental.
  const int maxHarmonicMultiple = 6;
  const double comparableFactor = 1.25; // allow up to 25% worse CMNDF and still prefer the lower frequency

  int bestTau = tauEstimate;
  double bestVal = cmndf[tauEstimate];

  for (int m = 2; m <= maxHarmonicMultiple; m++) {
    final candidateTau = tauEstimate * m;
    if (candidateTau > tauMax) break;

    // Walk to the local minimum around this candidate lag, same as the
    // primary search does, so we're comparing actual troughs, not an
    // arbitrary point that happens to land near one.
    int refinedCandidate = candidateTau;
    while (refinedCandidate + 1 <= tauMax &&
        cmndf[refinedCandidate + 1] < cmndf[refinedCandidate]) {
      refinedCandidate++;
    }
    while (refinedCandidate - 1 > tauMin &&
        cmndf[refinedCandidate - 1] < cmndf[refinedCandidate]) {
      refinedCandidate--;
    }

    final candidateVal = cmndf[refinedCandidate];

    if (candidateVal < bestVal * comparableFactor) {
      bestTau = refinedCandidate;
      bestVal = candidateVal;
    }
  }

  tauEstimate = bestTau;

  // --- Step 4: parabolic interpolation for sub-sample precision ---
  final refinedTau = _parabolicInterpolation(cmndf, tauEstimate, tauMin, tauMax);
  if (refinedTau <= 0) return null;

  return sampleRate / refinedTau;
}

/// Applies a Hann window to taper the buffer's edges toward zero,
/// reducing spectral leakage artifacts from the rectangular cut.
List<double> _applyHannWindow(List<double> samples) {
  final n = samples.length;
  final out = List<double>.filled(n, 0.0);
  for (int i = 0; i < n; i++) {
    final w = 0.5 * (1 - math.cos(2 * math.pi * i / (n - 1)));
    out[i] = samples[i] * w;
  }
  return out;
}

/// Refines the integer tau estimate using neighboring CMNDF values fit to
/// a parabola, giving a fractional period for better pitch accuracy.
double _parabolicInterpolation(
  List<double> cmndf,
  int tauEstimate,
  int tauMin,
  int tauMax,
) {
  if (tauEstimate - 1 < tauMin || tauEstimate + 1 > tauMax) {
    return tauEstimate.toDouble();
  }

  final yMinus = cmndf[tauEstimate - 1];
  final yCenter = cmndf[tauEstimate];
  final yPlus = cmndf[tauEstimate + 1];

  final denom = (yMinus - 2 * yCenter + yPlus);
  if (denom == 0) return tauEstimate.toDouble();

  final shift = 0.5 * (yMinus - yPlus) / denom;
  return tauEstimate + shift;
}


