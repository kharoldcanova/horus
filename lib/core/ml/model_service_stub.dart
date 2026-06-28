import '../processing/peak_detection.dart';
import '../sensors/sensor_event.dart';
import '../sensors/sensor_constants.dart';

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
  final PeakDetection _peakDetector = PeakDetection(
    sampleRate: SensorConstants.defaultSampleRate,
  );

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

    // Use GCG signal (gyroscope magnitude) — per Centracchio 2025.
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

  void dispose() {
    _modelLoaded = false;
  }
}
