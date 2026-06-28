import 'dart:async';
import 'sensor_event.dart';
import 'sensor_plugin.dart';
import 'sensor_constants.dart';

class SensorService {
  /// Shared singleton instance so HomeScreen, MonitorScreen, etc.
  /// all receive the same sensor stream without duplicating native listeners.
  static final SensorService instance = SensorService._();

  SensorService._();

  final StreamController<List<SensorEvent>> _rawStreamController =
      StreamController<List<SensorEvent>>.broadcast();

  final StreamController<List<SensorEvent>> _processedController =
      StreamController<List<SensorEvent>>.broadcast();

  StreamSubscription? _subscription;
  bool _isRunning = false;

  List<SensorEvent> _buffer = [];
  double _accumulator = 0.0;

  Stream<List<SensorEvent>> get rawStream => _rawStreamController.stream;
  Stream<List<SensorEvent>> get processedStream =>
      _processedController.stream;
  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;

    final started = await SensorPlugin.startSensorStream();
    if (!started) throw Exception('Failed to start sensor stream');

    _isRunning = true;
    _buffer = [];
    _accumulator = 0.0;

    _subscription = SensorPlugin.eventStream.listen(
      (events) {
        _rawStreamController.add(events);
        _resampleAndBuffer(events);
      },
      onError: (error) {
        _rawStreamController.addError(error);
      },
    );
  }

  Future<void> stop() async {
    await SensorPlugin.stopSensorStream();
    await _subscription?.cancel();
    _subscription = null;
    _isRunning = false;
    _buffer = [];
    _accumulator = 0.0;
  }

  void _resampleAndBuffer(List<SensorEvent> events) {
    final targetDt = 1.0 / SensorConstants.defaultSampleRate;
    final interpolated = <SensorEvent>[];

    for (final event in events) {
      _accumulator += event.timestamp;
      if (_buffer.isEmpty || _accumulator >= targetDt) {
        if (_buffer.isNotEmpty) {
          interpolated.add(_interpolate(_buffer, targetDt));
        }
        _buffer = [event];
        _accumulator = 0.0;
      } else {
        _buffer.add(event);
      }
    }

    if (interpolated.isNotEmpty) {
      _processedController.add(interpolated);
    }
  }

  SensorEvent _interpolate(List<SensorEvent> events, double targetDt) {
    if (events.length == 1) return events.first;

    final t0 = events.first.timestamp;
    final t1 = events.last.timestamp;
    final t = t0 + targetDt;
    final frac = (t - t0) / (t1 - t0).clamp(1e-6, double.infinity);
    final clamp = frac.clamp(0.0, 1.0);

    return SensorEvent(
      timestamp: t,
      ax: _lerp(events.first.ax, events.last.ax, clamp),
      ay: _lerp(events.first.ay, events.last.ay, clamp),
      az: _lerp(events.first.az, events.last.az, clamp),
      gx: _lerp(events.first.gx, events.last.gx, clamp),
      gy: _lerp(events.first.gy, events.last.gy, clamp),
      gz: _lerp(events.first.gz, events.last.gz, clamp),
    );
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void dispose() {
    stop();
    _rawStreamController.close();
    _processedController.close();
  }
}
