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
  bool _modelLoaded = false;
  final PeakDetection _peakDetector = PeakDetection(
    sampleRate: SensorConstants.defaultSampleRate,
  );

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

    // Use GCG signal (gyroscope magnitude) — per Centracchio 2025,
    // gyroscope outperforms accelerometer for mechanical heartbeat detection.
    final signal = window.map((e) => sqrt(e.gx * e.gx + e.gy * e.gy + e.gz * e.gz)).toList();
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

  double _estimateBpm(List<SensorEvent> window) {
    if (window.length < 2) return 0.0;
    // Use GCG signal for BPM estimation via peak-to-peak interval analysis.
    final signal = window.map((e) => sqrt(e.gx * e.gx + e.gy * e.gy + e.gz * e.gz)).toList();
    final analysis = _peakDetector.analyzeHeartRate(signal);
    final bpm = analysis['bpm']!;
    return bpm.clamp(SensorConstants.minValidBpm, SensorConstants.maxValidBpm);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
  }
}
