import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../processing/fft.dart';
import '../processing/filters.dart';
import '../processing/peak_detection.dart';

/// Detection result emitted by AudioService every ~500ms.
class AudioFrame {
  final DateTime timestamp;
  final double bpm;
  final bool hasHeartbeat;
  final double confidence;
  final List<double> waveform;
  final List<double> spectrum;

  const AudioFrame({
    required this.timestamp,
    required this.bpm,
    required this.hasHeartbeat,
    required this.confidence,
    required this.waveform,
    required this.spectrum,
  });
}

/// Singleton service for contact microphone (stethoscope) detection.
///
/// Pipeline:
///   44100 Hz PCM (native) → resample 4000 Hz → bandpass 20-200 Hz
///   → PeakDetection on 2s sliding window → AudioFrame every ~500ms
class AudioService {
  static const _channelName = 'com.horus.app/audio_stream';
  static const _methodStart = 'startAudioStream';
  static const _methodStop = 'stopAudioStream';

  static const _inputRate = 44100.0;
  static const _outputRate = 4000.0;
  static const _windowSize = 8000; // 2 seconds at 4 kHz
  static const _emitInterval = 2000; // emitted every ~0.5s at 4 kHz

  static final AudioService instance = AudioService._();

  final MethodChannel _methodChannel = const MethodChannel(_channelName);
  final EventChannel _eventChannel = const EventChannel('$_channelName/events');

  final StreamController<AudioFrame> _frameController =
      StreamController<AudioFrame>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  bool _isRunning = false;

  // Resampling state
  double _phase = 0.0;
  double _lastSample = 0.0;

  // Processed signal buffer at 4000 Hz
  final List<double> _buffer = [];

  // Filters — one bandpass per iteration (stateful IIR)
  late final ButterworthFilter _filter = ButterworthFilter.bandpass(
    lowFreq: 20.0,
    highFreq: 200.0,
    sampleRate: _outputRate,
  );

  final PeakDetection _peakDetector = PeakDetection(sampleRate: _outputRate);

  Stream<AudioFrame> get frameStream => _frameController.stream;
  bool get isRunning => _isRunning;

  AudioService._();

  /// Request mic permission and start the audio pipeline.
  Future<bool> start() async {
    if (_isRunning) return true;

    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    try {
      await _methodChannel.invokeMethod(_methodStart);
    } on PlatformException {
      return false;
    }

    _isRunning = true;
    _phase = 0.0;
    _lastSample = 0.0;
    _buffer.clear();
    _filter.reset();

    _subscription = _eventChannel
        .receiveBroadcastStream()
        .cast<List<dynamic>>()
        .listen(
          _onRawPcm,
          onError: (_) => stop(),
        );

    return true;
  }

  Future<void> stop() async {
    _isRunning = false;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _methodChannel.invokeMethod(_methodStop);
    } on PlatformException {
      // ignore
    }
    _buffer.clear();
  }

  void _onRawPcm(List<dynamic> raw) {
    if (!_isRunning) return;

    final samples = raw.cast<double>();
    _resample(samples);

    if (_buffer.length >= _emitInterval) {
      _detect();
    }
  }

  /// Resample 44100 Hz → 4000 Hz using linear interpolation with phase
  /// accumulator. Appends resampled samples directly to [_buffer].
  void _resample(List<double> samples) {
    final ratio = _inputRate / _outputRate; // 11.025

    for (final sample in samples) {
      _phase += 1.0 / ratio;
      while (_phase >= 1.0) {
        final interpolated =
            _lastSample + (sample - _lastSample) * (1.0 - (_phase - 1.0));
        final filtered = _filter.filter(interpolated);
        _buffer.add(filtered);
        _phase -= 1.0;
      }
      _lastSample = sample;
    }
  }

  /// Run PeakDetection + FFT on the latest [_windowSize] samples.
  void _detect() {
    final windowStart = _buffer.length - _windowSize;
    final windowStartClamped = windowStart.clamp(0, _buffer.length);
    final signal = _buffer.sublist(windowStartClamped);

    if (signal.length < _outputRate) {
      // Need at least 1 second of data
      return;
    }

    final analysis = _peakDetector.analyzeHeartRate(signal);
    final bpm = analysis['bpm']!;
    final confidence = analysis['confidence']!;
    final hasHeartbeat = bpm >= 30.0 && bpm <= 220.0 && confidence > 0.3;

    final spectrum = FFTAnalyzer.magnitudeSpectrum(signal);

    final frame = AudioFrame(
      timestamp: DateTime.now(),
      bpm: bpm,
      hasHeartbeat: hasHeartbeat,
      confidence: confidence,
      waveform: signal.sublist(math.max(0, signal.length - 400)),
      spectrum: spectrum,
    );

    _frameController.add(frame);
  }

  void dispose() {
    stop();
    _frameController.close();
  }
}
