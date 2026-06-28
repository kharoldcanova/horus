import 'package:flutter/material.dart';

class BpmHistoryChart extends StatelessWidget {
  final List<double> bpmHistory;
  final List<double> timeLabels;

  const BpmHistoryChart({
    super.key,
    required this.bpmHistory,
    required this.timeLabels,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BpmPainter(
          bpmHistory: bpmHistory,
          timeLabels: timeLabels,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _BpmPainter extends CustomPainter {
  final List<double> bpmHistory;
  final List<double> timeLabels;

  static const _bgColor = Color(0xFF1A1A2E);
  static const _gridColor = Color(0x20FFFFFF);
  static const _lineColor = Color(0xFF00E676);
  static const _targetZoneColor = Color(0x1800E676);
  static const _avgLineColor = Color(0xAAFFFF00);
  static const _labelColor = Color(0xAAFFFFFF);

  static const _minBpm = 0.0;
  static const _maxBpm = 220.0;
  static const _targetLow = 50.0;
  static const _targetHigh = 150.0;

  static const _leftPad = 32.0;
  static const _topPad = 8.0;
  static const _rightPad = 8.0;
  static const _bottomPad = 28.0;

  _BpmPainter({
    required this.bpmHistory,
    required this.timeLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bpmHistory.isEmpty ||
        timeLabels.isEmpty ||
        size.width <= 0 ||
        size.height <= 0) {
      _drawEmpty(canvas, size);
      return;
    }

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _bgColor,
    );

    final chartRect = Rect.fromLTWH(
      _leftPad,
      _topPad,
      (size.width - _leftPad - _rightPad).clamp(0, double.infinity),
      (size.height - _topPad - _bottomPad).clamp(0, double.infinity),
    );

    if (chartRect.width <= 0 || chartRect.height <= 0) return;

    final bpmRange = _maxBpm - _minBpm;
    final tMin = timeLabels.first;
    final tMax = timeLabels.last;
    final duration = (tMax - tMin).clamp(0.001, double.infinity);

    // Draw target zone
    final zoneTop = chartRect.top +
        (_maxBpm - _targetHigh) / bpmRange * chartRect.height;
    final zoneBottom = chartRect.top +
        (_maxBpm - _targetLow) / bpmRange * chartRect.height;
    canvas.drawRect(
      Rect.fromLTWH(chartRect.left, zoneTop, chartRect.width, zoneBottom - zoneTop),
      Paint()..color = _targetZoneColor,
    );

    // Draw grid
    _drawGrid(canvas, chartRect);

    // Compute average BPM
    final avgBpm = bpmHistory.reduce((a, b) => a + b) / bpmHistory.length;

    // Draw average BPM dashed line
    final avgY = chartRect.top +
        (_maxBpm - avgBpm.clamp(_minBpm, _maxBpm)) / bpmRange * chartRect.height;
    _drawDashedLine(
      canvas,
      Offset(chartRect.left, avgY),
      Offset(chartRect.right, avgY),
      Paint()
        ..color = _avgLineColor
        ..strokeWidth = 1.0,
    );

    // Draw BPM line
    final linePaint = Paint()
      ..color = _lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < bpmHistory.length; i++) {
      final x = chartRect.left +
          ((timeLabels[i] - tMin) / duration) * chartRect.width;
      final y = chartRect.top +
          (_maxBpm - bpmHistory[i].clamp(_minBpm, _maxBpm)) / bpmRange *
              chartRect.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Draw axes labels
    _drawAxesLabels(canvas, chartRect, avgBpm);

    // Border
    final borderPaint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(chartRect, borderPaint);
  }

  void _drawEmpty(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _bgColor,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'Sin datos',
        style: TextStyle(color: _labelColor, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        (size.height - tp.height) / 2,
      ),
    );
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = _gridColor
      ..strokeWidth = 0.5;

    // Horizontal grid at 25% intervals (55, 110, 165 BPM)
    for (int i = 1; i <= 3; i++) {
      final y = rect.top + rect.height * i / 4;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }

    // Vertical grid at 25% intervals
    for (int i = 1; i <= 3; i++) {
      final x = rect.left + rect.width * i / 4;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final path = Path()..moveTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + 6.0).clamp(0.0, metric.length);
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, paint);
        distance += 10.0;
      }
    }
  }

  void _drawAxesLabels(Canvas canvas, Rect rect, double avgBpm) {
    final labelStyle = TextStyle(color: _labelColor, fontSize: 9);

    // Y-axis labels
    for (int i = 0; i <= 4; i++) {
      final y = rect.bottom - rect.height * i / 4;
      final bpm = _minBpm + (_maxBpm - _minBpm) * i / 4;
      final tp = TextPainter(
        text: TextSpan(text: bpm.toStringAsFixed(0), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(_leftPad - tp.width - 4, y - tp.height / 2),
      );
    }

    // X-axis time labels
    if (timeLabels.length >= 2) {
      final tMin = timeLabels.first;
      final tMax = timeLabels.last;
      final duration = (tMax - tMin).clamp(0.001, double.infinity);

      for (int i = 0; i <= 4; i++) {
        final x = rect.left + rect.width * i / 4;
        final t = duration * i / 4;
        final tp = TextPainter(
          text: TextSpan(
            text: '${t.toStringAsFixed(0)}s',
            style: labelStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, rect.bottom + 4));
      }
    }

    // Average BPM label
    final avgStyle = TextStyle(
      color: _avgLineColor,
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );
    final avgTp = TextPainter(
      text: TextSpan(
        text: 'Prom ${avgBpm.toStringAsFixed(0)} BPM',
        style: avgStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final avgY = rect.top +
        (_maxBpm - avgBpm.clamp(_minBpm, _maxBpm)) / (_maxBpm - _minBpm) *
            rect.height;
    final avgLabelX = (rect.right - avgTp.width - 4).clamp(
      rect.left,
      rect.right - avgTp.width,
    );
    final avgLabelY = (avgY - avgTp.height - 2).clamp(
      rect.top,
      rect.bottom - avgTp.height,
    );
    avgTp.paint(canvas, Offset(avgLabelX, avgLabelY));
  }

  @override
  bool shouldRepaint(covariant _BpmPainter oldDelegate) =>
      oldDelegate.bpmHistory != bpmHistory ||
      oldDelegate.timeLabels != timeLabels;
}
