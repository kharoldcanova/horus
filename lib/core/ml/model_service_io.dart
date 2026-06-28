import 'dart:math' as math;

import 'package:tflite_flutter/tflite_flutter.dart';
import '../processing/peak_detection.dart';
import '../sensors/sensor_event.dart';
import '../sensors/sensor_constants.dart';

enum DetectionMode { imu, audio, camera }

class DetectionResult {
  final bool heartbeatDetected;
  final double bpm;
  final double confidence;
  final DetectionMode mode;
  final double timestamp;
  final Map<String, dynamic> metadata;

  const DetectionResult({
    required this.heartbeatDetected,
    required this.bpm,
    required this.confidence,
    required this.mode,
    required this.timestamp,
    this.metadata = const {},
  });
}

class ModelService {
  Interpreter? _interpreter;
  Interpreter? _audioInterpreter;
  bool _modelLoaded = false;
  bool _audioModelLoaded = false;
  final PeakDetection _peakDetector = PeakDetection(
    sampleRate: SensorConstants.defaultSampleRate,
  );

  bool get isModelLoaded => _modelLoaded;
  bool get isAudioModelLoaded => _audioModelLoaded;

  static const int _inputSize = 256;
  static const int _numChannels = 6;
  static const int _audioInputSize = 8000;

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions()..threads = 4;

      _interpreter = await Interpreter.fromAsset(
        'models/heartbeat_cnn.tflite',
        options: options,
      );
      _modelLoaded = true;
    } catch (e) {
      _modelLoaded = false;
    }

    // Load audio model independently — it's OK if only one loads.
    try {
      final audioOptions = InterpreterOptions()..threads = 2;
      _audioInterpreter = await Interpreter.fromAsset(
        'models/heartbeat_audio_cnn.tflite',
        options: audioOptions,
      );
      _audioModelLoaded = true;
    } catch (e) {
      _audioModelLoaded = false;
    }
  }

  DetectionResult classify({
    required List<SensorEvent> window,
    required DetectionMode mode,
  }) {
    if (!_modelLoaded || window.length < _inputSize) {
      return _fallbackDetection(window, mode);
    }

    try {
      final input = _prepareInput(window);
      final output = List<double>.filled(1, 0.0).reshape([1, 1]);

      _interpreter!.run(input, output);

      final probability = output[0][0] as double;
      final detected = probability > 0.5;

      return DetectionResult(
        heartbeatDetected: detected,
        bpm: detected ? _estimateBpm(window) : 0.0,
        confidence: detected ? probability : 1.0 - probability,
        mode: mode,
        timestamp: window.last.timestamp,
        metadata: {
          'ml_probability': probability,
          'window_samples': window.length,
        },
      );
    } catch (e) {
      return _fallbackDetection(window, mode);
    }
  }

  /// Audio-specific classification that combines ML model with PeakDetection.
  ///
  /// Takes the filtered signal at 4000 Hz (the same buffer used by AudioService
  /// for PeakDetection). When the ML model is loaded, its probability is blended
  /// with the peak-detection confidence for a robust final score.
  ///
  /// [signal] must have at least 4000 samples (1 second at 4 kHz);
  /// 8000 samples (2 seconds) yields best results.
  DetectionResult classifyAudio({
    required List<double> signal,
    required double bpm,
    required double peakConfidence,
    required double timestamp,
  }) {
    // Base decision from PeakDetection
    final peakDetected = bpm >= 30.0 && bpm <= 220.0 && peakConfidence > 0.3;

    if (!_audioModelLoaded || signal.length < _audioInputSize) {
      // Fallback: pure PeakDetection when model is unavailable or signal is short
      return DetectionResult(
        heartbeatDetected: peakDetected,
        bpm: bpm,
        confidence: peakConfidence,
        mode: DetectionMode.audio,
        timestamp: timestamp,
        metadata: {
          'peak_confidence': peakConfidence,
          if (!_audioModelLoaded) 'model': 'unavailable',
          if (signal.length < _audioInputSize)
            'signal_samples': signal.length,
        },
      );
    }

    try {
      // Run model on the latest 8000 samples
      final window = signal.sublist(signal.length - _audioInputSize);
      final input = _prepareAudioInput(window);
      final output = List<double>.filled(1, 0.0).reshape([1, 1]);

      _audioInterpreter!.run(input, output);
      final mlProbability = output[0][0] as double;

      // Blend: model has high precision, PeakDetection handles periodic signals
      // Weighted average: 60% model / 40% peak when both agree, favors model
      final blended = mlProbability * 0.6 + peakConfidence * 0.4;
      final detected = blended > 0.4;

      return DetectionResult(
        heartbeatDetected: detected,
        bpm: bpm,
        confidence: blended.clamp(0.0, 1.0),
        mode: DetectionMode.audio,
        timestamp: timestamp,
        metadata: {
          'ml_probability': mlProbability,
          'peak_confidence': peakConfidence,
          'blended_confidence': blended,
        },
      );
    } catch (e) {
      return DetectionResult(
        heartbeatDetected: peakDetected,
        bpm: bpm,
        confidence: peakConfidence,
        mode: DetectionMode.audio,
        timestamp: timestamp,
        metadata: {
          'peak_confidence': peakConfidence,
          'model_error': e.toString(),
        },
      );
    }
  }

  DetectionResult _fallbackDetection(
      List<SensorEvent> window, DetectionMode mode) {
    if (window.length < 2) {
      return DetectionResult(
        heartbeatDetected: false,
        bpm: 0.0,
        confidence: 0.0,
        mode: mode,
        timestamp: 0.0,
      );
    }

    // Use GCG signal (gyroscope magnitude) — per Centracchio 2025,
    // gyroscope outperforms accelerometer for mechanical heartbeat detection.
    final signal = window.map((e) => math.sqrt(e.gx * e.gx + e.gy * e.gy + e.gz * e.gz)).toList();
    final analysis = _peakDetector.analyzeHeartRate(signal);

    final detected = analysis['bpm']! >= SensorConstants.minValidBpm &&
        analysis['confidence']! > 0.3;

    return DetectionResult(
      heartbeatDetected: detected,
      bpm: analysis['bpm']!,
      confidence: analysis['confidence']!,
      mode: mode,
      timestamp: window.last.timestamp,
      metadata: {
        'peak_interval': analysis['meanInterval'],
        'fallback': true,
      },
    );
  }

  List<List<List<double>>> _prepareInput(List<SensorEvent> window) {
    final result = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (i) => List.generate(_numChannels, (c) {
          if (i < window.length) {
            final e = window[i];
            switch (c) {
              case 0: return e.ax;
              case 1: return e.ay;
              case 2: return e.az;
              case 3: return e.gx;
              case 4: return e.gy;
              case 5: return e.gz;
              default: return 0.0;
            }
          }
          return 0.0;
        }),
      ),
    );
    return result;
  }

  /// Prepare [1, 8000, 1] input tensor from a 1D filtered audio signal.
  List<List<List<double>>> _prepareAudioInput(List<double> window) {
    // Pad or truncate to exactly _audioInputSize
    final padded = List<double>.from(window);
    while (padded.length < _audioInputSize) {
      padded.add(0.0);
    }
    final trimmed = padded.sublist(padded.length - _audioInputSize);

    return [
      trimmed.map((s) => [s]).toList(),
    ];
  }

  double _estimateBpm(List<SensorEvent> window) {
    if (window.length < 2) return 0.0;
    // Use GCG signal for BPM estimation via peak-to-peak interval analysis.
    final signal = window.map((e) => math.sqrt(e.gx * e.gx + e.gy * e.gy + e.gz * e.gz)).toList();
    final analysis = _peakDetector.analyzeHeartRate(signal);
    final bpm = analysis['bpm']!;
    return bpm.clamp(SensorConstants.minValidBpm, SensorConstants.maxValidBpm);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _audioInterpreter?.close();
    _audioInterpreter = null;
    _modelLoaded = false;
    _audioModelLoaded = false;
  }
}
