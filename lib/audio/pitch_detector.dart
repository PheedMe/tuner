import 'dart:math' as math;

double? detectPitch(
  List<double> samples,
  double sampleRate, {
    double minHz = 60,
    double maxHz = 1000,
    double silenceRmsThreshold = 0.01,
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

  final minLag = (sampleRate / maxHz).floor().clamp(1, n - 1);
  final maxLag = (sampleRate / minHz).floor().clamp(1, n - 1);
  if (minLag >= maxLag) return null;

  double bestCorr = 0;
  int bestLag = -1;

  for (int lag = minLag; lag <= maxLag; lag++) {
    double corr = 0;
    for (int i = 0; i < n - lag; i++) {
      corr += samples[i] * samples[i + lag];
    }

    corr /= (n - lag);

    if (corr > bestCorr) {
      bestCorr = corr;
      bestLag = lag;
    }
  }

  if (bestLag <= 0) return null;

  final refinedLag = _parabolicInterpolation(samples, bestLag, minLag, maxLag);
  return sampleRate / refinedLag;
}

double _parabolicInterpolation(
List<double> samples,
int bestLag,
int minLag,
int maxLag,
) {
  double corrAt(int lag) {
    double c = 0;
    final n = samples.length;
    for (int i = 0; i < n - lag; i++) {
      c += samples[i] * samples[i + lag];
    }
    return c / (n - lag);
  }

  if (bestLag - 1 < minLag || bestLag + 1 > maxLag) {
    return bestLag.toDouble();
  }

  final yMinus = corrAt(bestLag - 1);
  final yCenter = corrAt(bestLag);
  final yPlus = corrAt(bestLag + 1);

  final denom = (yMinus - 2 * yCenter + yPlus);
  if (denom == 0) return bestLag.toDouble();

  final shift = 0.5 * (yMinus - yPlus) / denom;
  return bestLag + shift;
}