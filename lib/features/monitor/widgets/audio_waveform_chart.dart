import 'package:flutter/material.dart';

class AudioWaveformChart extends StatelessWidget {
  final List<double> waveform;

  const AudioWaveformChart({
    super.key,
    required this.waveform,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _WaveformPainter(waveform: waveform),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> waveform;

  static const _bgColor = Color(0xFF1A1A2E);
  static const _gridColor = Color(0x20FFFFFF);
  static const _waveColor = Color(0xFF00BCD4);
  static const _centerColor = Color(0x40FFFFFF);

  static const _leftPad = 8.0;
  static const _topPad = 8.0;
  static const _rightPad = 8.0;
  static const _bottomPad = 28.0;

  _WaveformPainter({required this.waveform});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _bgColor,
    );

    if (waveform.isEmpty || size.width <= 0 || size.height <= 0) return;

    final chartRect = Rect.fromLTWH(
      _leftPad,
      _topPad,
      (size.width - _leftPad - _rightPad).clamp(0, double.infinity),
      (size.height - _topPad - _bottomPad).clamp(0, double.infinity),
    );

    if (chartRect.width <= 0 || chartRect.height <= 0) return;

    // Center line
    final centerY = chartRect.top + chartRect.height / 2;
    canvas.drawLine(
      Offset(chartRect.left, centerY),
      Offset(chartRect.right, centerY),
      Paint()..color = _centerColor..strokeWidth = 0.5,
    );

    // Find amplitude range
    double maxAbs = 0;
    for (final v in waveform) {
      final abs = v.abs();
      if (abs > maxAbs) maxAbs = abs;
    }
    if (maxAbs < 0.001) maxAbs = 0.001;

    // Draw grid
    _drawGrid(canvas, chartRect);

    // Draw waveform
    final paint = Paint()
      ..color = _waveColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final step = chartRect.width / waveform.length;

    for (int i = 0; i < waveform.length; i++) {
      final x = chartRect.left + i * step;
      final y = centerY - (waveform[i] / maxAbs) * (chartRect.height / 2);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Border
    final borderPaint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(chartRect, borderPaint);
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = _gridColor
      ..strokeWidth = 0.5;

    for (int i = 1; i <= 3; i++) {
      final y = rect.top + rect.height * i / 4;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.waveform != waveform;
}
