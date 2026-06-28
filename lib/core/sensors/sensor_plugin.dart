import 'dart:async';
import 'package:flutter/services.dart';
import 'sensor_event.dart';
import 'sensor_constants.dart';

class SensorPlugin {
  static final MethodChannel _channel =
      MethodChannel(SensorConstants.channelName);

  static const EventChannel _eventChannel =
      EventChannel('${SensorConstants.channelName}/events');

  static Future<bool> startSensorStream() async {
    try {
      await _channel.invokeMethod(SensorConstants.methodStart);
      return true;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<bool> stopSensorStream() async {
    try {
      await _channel.invokeMethod(SensorConstants.methodStop);
      return true;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Stream<List<SensorEvent>> get eventStream {
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) {
          final data = event as List<dynamic>;
          return data.map((raw) {
            final values = raw as List<dynamic>;
            return SensorEvent.fromList(
              values.sublist(1, 7).cast<double>(),
              (values[0] as num).toDouble(),
            );
          }).toList();
        })
        .handleError((_) => <SensorEvent>[]);
  }
}
