import 'dart:math';

class FFTAnalyzer {
  static const double minValidBpm = 30.0;
  static const double maxValidBpm = 220.0;

  static double estimateHeartRate(List<double> signal, double sampleRate) {
    final n = _nextPowerOfTwo(signal.length);
    final padded = List<double>.from(signal);
    while (padded.length < n) {
      padded.add(0.0);
    }

    final fft = _fft(padded);
    final magnitudes = fft.map((c) => c.magnitude).toList();

    final minBin = (minValidBpm / 60.0 * n / sampleRate).round().clamp(1, n ~/ 2);
    final maxBin = (maxValidBpm / 60.0 * n / sampleRate).round().clamp(1, n ~/ 2);

    double maxMag = 0;
    int peakBin = minBin;
    for (int i = minBin; i <= maxBin && i < magnitudes.length; i++) {
      if (magnitudes[i] > maxMag) {
        maxMag = magnitudes[i];
        peakBin = i;
      }
    }

    final bpm = peakBin * sampleRate / n * 60.0;
    return bpm.clamp(minValidBpm, maxValidBpm);
  }

  static List<double> magnitudeSpectrum(List<double> signal) {
    final n = _nextPowerOfTwo(signal.length);
    final padded = List<double>.from(signal);
    while (padded.length < n) {
      padded.add(0.0);
    }
    final fft = _fft(padded);
    return fft.sublist(0, n ~/ 2).map((c) => c.magnitude).toList();
  }

  static int _nextPowerOfTwo(int n) {
    int p = 1;
    while (p < n) {
      p <<= 1;
    }
    return p;
  }

  static List<Complex> _fft(List<double> x) {
    final result = x.map((v) => Complex(v, 0)).toList();
    _fftRecursive(result);
    return result;
  }

  static void _fftRecursive(List<Complex> x) {
    final n = x.length;
    if (n <= 1) return;

    final even = List<Complex>.generate(n ~/ 2, (i) => x[2 * i]);
    final odd = List<Complex>.generate(n ~/ 2, (i) => x[2 * i + 1]);

    _fftRecursive(even);
    _fftRecursive(odd);

    for (int k = 0; k < n ~/ 2; k++) {
      final t = Complex.fromPolar(1.0, -2 * pi * k / n) * odd[k];
      x[k] = even[k] + t;
      x[k + n ~/ 2] = even[k] - t;
    }
  }
}

class Complex {
  final double real;
  final double imag;

  const Complex(this.real, this.imag);

  double get magnitude => sqrt(real * real + imag * imag);
  double get phase => atan2(imag, real);

  Complex operator +(Complex other) =>
      Complex(real + other.real, imag + other.imag);

  Complex operator -(Complex other) =>
      Complex(real - other.real, imag - other.imag);

  Complex operator *(Complex other) =>
      Complex(real * other.real - imag * other.imag,
          real * other.imag + imag * other.real);

  factory Complex.fromPolar(double r, double theta) =>
      Complex(r * cos(theta), r * sin(theta));

  @override
  String toString() =>
      imag >= 0
          ? '${real.toStringAsFixed(4)} + ${imag.toStringAsFixed(4)}i'
          : '${real.toStringAsFixed(4)} - ${(-imag).toStringAsFixed(4)}i';
}
