import 'dart:math';

class ButterworthFilter {
  final List<double> _aCoeffs;
  final List<double> _bCoeffs;
  final List<double> _xHistory;
  final List<double> _yHistory;

  ButterworthFilter._({
    required List<double> aCoeffs,
    required List<double> bCoeffs,
  })  : _aCoeffs = aCoeffs,
        _bCoeffs = bCoeffs,
        _xHistory = List.filled(bCoeffs.length, 0.0),
        _yHistory = List.filled(aCoeffs.length, 0.0);

  static ButterworthFilter lowPass6Hz({double sampleRate = 128.0}) {
    final dt = 1.0 / sampleRate;
    final tau = 1.0 / (2 * pi * 6.0);
    final alpha = dt / (tau + dt);
    return ButterworthFilter._(
      aCoeffs: [-(1 - alpha)],
      bCoeffs: [alpha],
    );
  }

  static ButterworthFilter highPass0_5Hz({double sampleRate = 128.0}) {
    final dt = 1.0 / sampleRate;
    final rc = 1.0 / (2 * pi * 0.5);
    final alpha = rc / (rc + dt);
    return ButterworthFilter._(
      aCoeffs: [-(1 - alpha)],
      bCoeffs: [alpha, -alpha],
    );
  }

  static ButterworthFilter bandpass({
    required double lowFreq,
    required double highFreq,
    required double sampleRate,
  }) {
    final dt = 1.0 / sampleRate;
    final w0 = 2 * pi * sqrt(lowFreq * highFreq);
    final bw = 2 * pi * (highFreq - lowFreq);
    final q = w0 / bw;
    final alpha = sin(w0 * dt) / (2 * q);
    final cosW0 = cos(w0 * dt);

    final b0 = alpha;
    final b1 = 0;
    final b2 = -alpha;
    final a0 = 1 + alpha;
    final a1 = -2 * cosW0;
    final a2 = 1 - alpha;

    return ButterworthFilter._(
      aCoeffs: [a1 / a0, a2 / a0],
      bCoeffs: [b0 / a0, b1 / a0, b2 / a0],
    );
  }

  double filter(double sample) {
    for (int i = _bCoeffs.length - 1; i > 0; i--) {
      _xHistory[i] = _xHistory[i - 1];
    }
    _xHistory[0] = sample;

    double y = 0;
    for (int i = 0; i < _bCoeffs.length; i++) {
      y += _bCoeffs[i] * _xHistory[i];
    }
    for (int i = 0; i < _aCoeffs.length; i++) {
      y -= _aCoeffs[i] * _yHistory[i];
    }

    for (int i = _yHistory.length - 1; i > 0; i--) {
      _yHistory[i] = _yHistory[i - 1];
    }
    _yHistory[0] = y;

    return y;
  }

  void reset() {
    _xHistory.fillRange(0, _xHistory.length, 0.0);
    _yHistory.fillRange(0, _yHistory.length, 0.0);
  }
}
