import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../sensors/sensor_event.dart';

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
  bool _modelLoaded = false;

  bool get isModelLoaded => _modelLoaded;

  static const int _inputSize = 256;
  static const int _numChannels = 6;

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

    final magnitudes = window.map((e) => e.magnitude).toList();
    final mean =
        magnitudes.reduce((a, b) => a + b) / magnitudes.length;
    final variance = magnitudes
            .map((m) => (m - mean) * (m - mean))
            .reduce((a, b) => a + b) /
        magnitudes.length;
    final std = variance <= 0 ? 0.0 : sqrt(variance);

    final activity =
        magnitudes.map((m) => m.abs()).reduce((a, b) => a > b ? a : b);

    final detected = activity > mean + std * 2.0;

    return DetectionResult(
      heartbeatDetected: detected,
      bpm: 0.0,
      confidence: detected ? 0.3 : 0.7,
      mode: mode,
      timestamp: window.last.timestamp,
      metadata: {
        'signal_activity': activity,
        'signal_std': std,
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

  double _estimateBpm(List<SensorEvent> window) {
    if (window.length < 2) return 0.0;
    final dt = window.last.timestamp - window.first.timestamp;
    if (dt <= 0) return 0.0;
    return 60.0 / dt;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
  }
}
