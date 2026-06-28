import 'package:flutter/material.dart';

import '../../../core/sensors/sensor_event.dart';

class SignalChart extends StatelessWidget {
  final List<SensorEvent> events;
  final Set<int> activeChannels;

  static const channelColors = <int, Color>{
    0: Color(0xFFFF6B35), // ax — orange
    1: Color(0xFF00E676), // ay — green
    2: Color(0xFF448AFF), // az — blue
    3: Color(0xFFFF1744), // gx — red
    4: Color(0xFFFFFF00), // gy — yellow
    5: Color(0xFFE040FB), // gz — purple
  };

  static const channelNames = <int, String>{
    0: 'ax',
    1: 'ay',
    2: 'az',
    3: 'gx',
    4: 'gy',
    5: 'gz',
  };

  static const accelIndices = {0, 1, 2};
  static const gyroIndices = {3, 4, 5};

  const SignalChart({
    super.key,
    required this.events,
    this.activeChannels = const {0, 1, 2, 3, 4, 5},
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SignalPainter(
          events: events,
          activeChannels: activeChannels,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SignalPainter extends CustomPainter {
  final List<SensorEvent> events;
  final Set<int> activeChannels;

  static const _bgColor = Color(0xFF1A1A2E);
  static const _gridColor = Color(0x20FFFFFF);
  static const _labelColor = Color(0xAAFFFFFF);
  static const _legendLabelColor = Color(0xCCFFFFFF);

  static const _leftPad = 8.0;
  static const _topPad = 8.0;
  static const _rightPad = 8.0;
  static const _bottomPad = 36.0;

  _SignalPainter({
    required this.events,
    required this.activeChannels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Always draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _bgColor,
    );

    if (events.isEmpty || size.width <= 0 || size.height <= 0) return;

    final chartRect = Rect.fromLTWH(
      _leftPad,
      _topPad,
      (size.width - _leftPad - _rightPad).clamp(0, double.infinity),
      (size.height - _topPad - _bottomPad).clamp(0, double.infinity),
    );

    if (chartRect.width <= 0 || chartRect.height <= 0) return;

    final tMin = events.first.timestamp;
    final tMax = events.last.timestamp;
    final duration = (tMax - tMin).clamp(0.001, double.infinity);

    // Compute data range across active channels
    double dataMin = double.infinity;
    double dataMax = double.negativeInfinity;

    for (final ch in activeChannels) {
      for (final e in events) {
        final v = _channelValue(e, ch);
        if (v < dataMin) dataMin = v;
        if (v > dataMax) dataMax = v;
      }
    }

    // Apply 10% padding
    final range = (dataMax - dataMin).clamp(0.001, double.infinity);
    final pad = range * 0.1;
    dataMin -= pad;
    dataMax += pad;

    // Draw grid
    _drawGrid(canvas, chartRect, duration);

    // Draw channels
    for (final ch in activeChannels) {
      _drawChannel(canvas, chartRect, ch, tMin, duration, dataMin, dataMax);
    }

    // Draw x-axis labels
    _drawXLabels(canvas, chartRect, duration);

    // Draw legend
    _drawLegend(canvas, chartRect, size);
  }

  double _channelValue(SensorEvent e, int ch) {
    switch (ch) {
      case 0:
        return e.ax;
      case 1:
        return e.ay;
      case 2:
        return e.az;
      case 3:
        return e.gx;
      case 4:
        return e.gy;
      case 5:
        return e.gz;
      default:
        return 0;
    }
  }

  void _drawGrid(Canvas canvas, Rect rect, double duration) {
    final paint = Paint()
      ..color = _gridColor
      ..strokeWidth = 0.5;

    // Horizontal grid lines at 25% intervals
    for (int i = 1; i <= 3; i++) {
      final y = rect.top + rect.height * i / 4;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }

    // Vertical grid lines at 25% intervals
    for (int i = 1; i <= 3; i++) {
      final x = rect.left + rect.width * i / 4;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }

    // Border
    final borderPaint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, borderPaint);
  }

  void _drawChannel(
    Canvas canvas,
    Rect rect,
    int ch,
    double tMin,
    double duration,
    double dataMin,
    double dataMax,
  ) {
    final paint = Paint()
      ..color = SignalChart.channelColors[ch]!
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < events.length; i++) {
      final e = events[i];
      final x = rect.left + ((e.timestamp - tMin) / duration) * rect.width;
      final y = rect.bottom -
          ((_channelValue(e, ch) - dataMin) / (dataMax - dataMin)) *
              rect.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawXLabels(Canvas canvas, Rect rect, double duration) {
    final textStyle = TextStyle(
      color: _labelColor,
      fontSize: 9,
    );

    for (int i = 0; i <= 4; i++) {
      final x = rect.left + rect.width * i / 4;
      final t = (duration * i / 4);
      final label = '${t.toStringAsFixed(1)}s';

      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(x - tp.width / 2, rect.bottom + 4));
    }
  }

  void _drawLegend(Canvas canvas, Rect chartRect, Size size) {
    final legendY = size.height - 24;
    final textStyle = TextStyle(
      color: _legendLabelColor,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );

    // ACCEL group (channels 0,1,2)
    double x = _leftPad + 4;
    for (final ch in SignalChart.accelIndices) {
      canvas.drawCircle(
        Offset(x, legendY),
        3.5,
        Paint()..color = SignalChart.channelColors[ch]!.withValues(alpha: 0.7),
      );
      x += 14;
    }

    var tp = TextPainter(
      text: TextSpan(text: 'ACCEL', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, legendY - tp.height / 2));
    x += tp.width + 20;

    // GYRO group (channels 3,4,5)
    for (final ch in SignalChart.gyroIndices) {
      canvas.drawCircle(
        Offset(x, legendY),
        3.5,
        Paint()..color = SignalChart.channelColors[ch]!.withValues(alpha: 0.7),
      );
      x += 14;
    }

    tp = TextPainter(
      text: TextSpan(text: 'GYRO', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, legendY - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _SignalPainter oldDelegate) =>
      oldDelegate.events != events ||
      oldDelegate.activeChannels != activeChannels;
}
