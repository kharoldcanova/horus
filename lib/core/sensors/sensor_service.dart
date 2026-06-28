import 'dart:async';
import '../processing/filters.dart';
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

  /// Buffer for events accumulated during one resampling window.
  List<SensorEvent> _buffer = [];

  /// Tracks the output timestamp of the last processed sample.
  double? _lastOutputTime;

  /// One Butterworth bandpass filter per channel (ax, ay, az, gx, gy, gz).
  /// Filters are stateful IIR — one instance per channel.
  late final List<ButterworthFilter> _filters = List.generate(
    6,
    (_) => ButterworthFilter.bandpass(
      lowFreq: SensorConstants.minCardiacFreq,
      highFreq: SensorConstants.maxCardiacFreq,
      sampleRate: SensorConstants.defaultSampleRate,
    ),
  );

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
    _lastOutputTime = null;
    for (final f in _filters) {
      f.reset();
    }

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
    _lastOutputTime = null;
  }

  void _resampleAndBuffer(List<SensorEvent> events) {
    final targetDt = 1.0 / SensorConstants.defaultSampleRate;
    final interpolated = <SensorEvent>[];

    for (final event in events) {
      if (_buffer.isEmpty) {
        _buffer = [event];
        _lastOutputTime ??= event.timestamp;
        continue;
      }

      // Accumulate events until the buffer spans at least one targetDt.
      // This produces one interpolated sample every 1/128s regardless of
      // the native sensor rate (typically ~200 Hz on SENSOR_DELAY_FASTEST).
      _buffer.add(event);
      final span = event.timestamp - _buffer.first.timestamp;

      if (span >= targetDt) {
        interpolated.add(_interpolate(_buffer, targetDt));
        _lastOutputTime = _lastOutputTime! + targetDt;
        // Keep the last event as the start of the next window to avoid gaps.
        _buffer = [_buffer.last];
      }
    }

    if (interpolated.isNotEmpty) {
      // Apply Butterworth bandpass 0.5–30 Hz to every interpolated sample.
      final filtered = interpolated.map((e) => SensorEvent(
        timestamp: e.timestamp,
        ax: _filters[0].filter(e.ax),
        ay: _filters[1].filter(e.ay),
        az: _filters[2].filter(e.az),
        gx: _filters[3].filter(e.gx),
        gy: _filters[4].filter(e.gy),
        gz: _filters[5].filter(e.gz),
      )).toList();
      _processedController.add(filtered);
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
