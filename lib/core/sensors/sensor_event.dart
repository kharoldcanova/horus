class SensorEvent {
  final double timestamp;
  final double ax, ay, az;
  final double gx, gy, gz;

  const SensorEvent({
    required this.timestamp,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });

  double get magnitude =>
      (ax * ax + ay * ay + az * az).clamp(0, double.infinity);

  List<double> toList() => [ax, ay, az, gx, gy, gz];

  factory SensorEvent.fromList(List<double> values, double timestamp) {
    return SensorEvent(
      timestamp: timestamp,
      ax: values[0],
      ay: values[1],
      az: values[2],
      gx: values[3],
      gy: values[4],
      gz: values[5],
    );
  }

  @override
  String toString() =>
      'SensorEvent(${timestamp.toStringAsFixed(3)}s: '
      'accel=(${ax.toStringAsFixed(3)}, ${ay.toStringAsFixed(3)}, ${az.toStringAsFixed(3)}) '
      'gyro=(${gx.toStringAsFixed(3)}, ${gy.toStringAsFixed(3)}, ${gz.toStringAsFixed(3)}))';
}

class SensorSession {
  final String id;
  final DateTime startTime;
  final List<SensorEvent> events;
  final String? notes;

  SensorSession({
    required this.id,
    required this.startTime,
    List<SensorEvent>? events,
    this.notes,
  }) : events = events ?? [];

  Duration get duration =>
      events.length >= 2
          ? Duration(
              milliseconds:
                  ((events.last.timestamp - events.first.timestamp) * 1000)
                      .round())
          : Duration.zero;

  double get sampleRate {
    if (events.length < 2) return 0;
    final dt = events.last.timestamp - events.first.timestamp;
    if (dt <= 0) return 0;
    return (events.length - 1) / dt;
  }
}
