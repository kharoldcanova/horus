class PeakDetection {
  final double minPeakDistance;
  final double minPeakHeight;
  final double sampleRate;

  PeakDetection({
    required this.sampleRate,
    this.minPeakDistance = 0.3,
    this.minPeakHeight = 0.05,
  });

  List<int> findPeaks(List<double> signal) {
    final peaks = <int>[];
    final minDistanceSamples = (minPeakDistance * sampleRate).round();

    for (int i = 2; i < signal.length - 2; i++) {
      if (signal[i] < minPeakHeight) continue;

      if (signal[i] > signal[i - 1] &&
          signal[i] > signal[i - 2] &&
          signal[i] > signal[i + 1] &&
          signal[i] > signal[i + 2]) {
        if (peaks.isEmpty || i - peaks.last >= minDistanceSamples) {
          peaks.add(i);
        }
      }
    }

    return peaks;
  }

  Map<String, double> analyzeHeartRate(List<double> signal) {
    final peaks = findPeaks(signal);

    if (peaks.length < 2) {
      return {'bpm': 0.0, 'confidence': 0.0, 'meanInterval': 0.0};
    }

    final intervals = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      intervals.add((peaks[i] - peaks[i - 1]) / sampleRate);
    }

    final meanInterval =
        intervals.reduce((a, b) => a + b) / intervals.length;
    final bpm = 60.0 / meanInterval;

    final intervalStd = sqrt(
        intervals.map((i) => (i - meanInterval) * (i - meanInterval))
            .reduce((a, b) => a + b) /
        intervals.length);

    final cv = intervalStd / meanInterval;
    final confidence = (1.0 - cv.clamp(0.0, 1.0)) *
        (peaks.length / signal.length * sampleRate / 60.0).clamp(0.0, 1.0);

    return {
      'bpm': bpm.clamp(30.0, 220.0),
      'confidence': confidence.clamp(0.0, 1.0),
      'meanInterval': meanInterval,
    };
  }
}

double sqrt(double x) {
  if (x <= 0) return 0;
  double r = x;
  for (int i = 0; i < 10; i++) {
    r = (r + x / r) / 2;
  }
  return r;
}
