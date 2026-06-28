import 'dart:math';
import '../sensors/sensor_event.dart';

// Keep DetectionMode and DetectionResult identical to model_service_io.dart
// so both implementations expose the exact same API.

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
  bool _modelLoaded = false;

  bool get isModelLoaded => _modelLoaded;

  // ignore: unused_field
  static const int _inputSize = 256;
  // ignore: unused_field
  static const int _numChannels = 6;

  Future<void> loadModel() async {
    // Web: no native TFLite support — skip loading, always use fallback.
    _modelLoaded = false;
  }

  DetectionResult classify({
    required List<SensorEvent> window,
    required DetectionMode mode,
  }) {
    return _fallbackDetection(window, mode);
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

  void dispose() {
    _modelLoaded = false;
  }
}
