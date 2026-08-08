import 'dart:math' as math;

double? detectPitch(
  List<double> samples,
  double sampleRate, {
    double minHz = 60,
    double maxHz = 1000,
    double silenceRmsThreshold = 0.01,
    double threshold = 0.25
  }
) {
  final n = samples.length;
  if (n < 2) return null;

  double sumSquares = 0;
  for (final s in samples) {
    sumSquares += s * s;
  }
  final rms = math.sqrt(sumSquares / n);
  if (rms < silenceRmsThreshold) return null;

  final tauMin = (sampleRate / maxHz).floor().clamp(1, n - 1);
  final tauMax = (sampleRate / minHz).floor().clamp(1, n - 1);
  if (tauMin >= tauMax) return null;

  final diff = List<double>.filled(tauMax + 1, 0.0);
  for (int tau = 1; tau <= tauMax; tau++) {
    double sum = 0;
    for (int j = 0; j < n - tau; j++) {
      final delta = samples[j] - samples[j + tau];
      sum += delta * delta;
    }
    diff[tau] = sum;
  }

  final cmndf = List<double>.filled(tauMax + 1, 1.0);
  double runningSum = 0;
  for (int tau = 1; tau <= tauMax; tau++) {
    runningSum += diff[tau];
    cmndf[tau] = runningSum > 0 ? diff[tau] * tau / runningSum : 1.0;
  }

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

  if (tauEstimate == -1) return null;

  final refinedTau = _parabolicInterpolation(cmndf, tauEstimate, tauMin, tauMax);
  if (refinedTau <= 0) return null;

  return sampleRate / refinedTau;
}

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