/// Available search/detection modes.
/// Each mode uses a different sensor to detect heartbeats.
enum SearchMode {
  /// Accelerometer + Gyroscope — primary mode for USAR.
  imu,

  /// Contact microphone — confirmatory mode, stethoscope-like.
  audio,
}

class SensorConstants {
  static const channelName = 'com.horus.app/sensor_stream';
  static const methodStart = 'startSensorStream';
  static const methodStop = 'stopSensorStream';

  static const double defaultSampleRate = 128.0;
  static const int windowSize = 256;
  static const double windowDuration = 2.0;
  static const double minCardiacFreq = 0.5;
  static const double maxCardiacFreq = 30.0;
  static const double minValidBpm = 30.0;
  static const double maxValidBpm = 220.0;
}
