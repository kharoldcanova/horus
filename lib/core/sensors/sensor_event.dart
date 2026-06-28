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

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'ax': ax,
        'ay': ay,
        'az': az,
        'gx': gx,
        'gy': gy,
        'gz': gz,
      };

  factory SensorEvent.fromJson(Map<String, dynamic> json) {
    return SensorEvent(
      timestamp: (json['timestamp'] as num).toDouble(),
      ax: (json['ax'] as num).toDouble(),
      ay: (json['ay'] as num).toDouble(),
      az: (json['az'] as num).toDouble(),
      gx: (json['gx'] as num).toDouble(),
      gy: (json['gy'] as num).toDouble(),
      gz: (json['gz'] as num).toDouble(),
    );
  }

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
  final List<double>? audioSamples;

  SensorSession({
    required this.id,
    required this.startTime,
    List<SensorEvent>? events,
    this.notes,
    this.audioSamples,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'events': events.map((e) => e.toJson()).toList(),
        if (notes != null) 'notes': notes,
        if (audioSamples != null) 'audioSamples': audioSamples,
      };

  factory SensorSession.fromJson(Map<String, dynamic> json) {
    return SensorSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      events: (json['events'] as List)
          .map((e) => SensorEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
      audioSamples: json['audioSamples'] != null
          ? (json['audioSamples'] as List).cast<double>()
          : null,
    );
  }
}
