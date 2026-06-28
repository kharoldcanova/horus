import 'dart:math' as math;

import 'package:flutter/material.dart';

class SpectrumChart extends StatelessWidget {
  final List<double> magnitudes;
  final double sampleRate;
  final double maxDisplayFreq;

  const SpectrumChart({
    super.key,
    required this.magnitudes,
    required this.sampleRate,
    this.maxDisplayFreq = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SpectrumPainter(
          magnitudes: magnitudes,
          sampleRate: sampleRate,
          maxDisplayFreq: maxDisplayFreq,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final List<double> magnitudes;
  final double sampleRate;
  final double maxDisplayFreq;

  static const _bgColor = Color(0xFF1A1A2E);
  static const _gridColor = Color(0x20FFFFFF);
  static const _barColor = Color(0xFF448AFF);
  static const _peakColor = Color(0xFFFF6B35);
  static const _labelColor = Color(0xAAFFFFFF);

  static const _leftPad = 32.0;
  static const _topPad = 8.0;
  static const _rightPad = 8.0;
  static const _bottomPad = 28.0;

  _SpectrumPainter({
    required this.magnitudes,
    required this.sampleRate,
    this.maxDisplayFreq = 30.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Always draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _bgColor,
    );

    if (magnitudes.isEmpty || size.width <= 0 || size.height <= 0) return;

    final chartRect = Rect.fromLTWH(
      _leftPad,
      _topPad,
      (size.width - _leftPad - _rightPad).clamp(0, double.infinity),
      (size.height - _topPad - _bottomPad).clamp(0, double.infinity),
    );

    if (chartRect.width <= 0 || chartRect.height <= 0) return;

    final fftSize = magnitudes.length * 2;
    final maxFreq = maxDisplayFreq; // Show up to maxDisplayFreq Hz
    final maxBin = (maxFreq * fftSize / sampleRate).round().clamp(
          0,
          magnitudes.length - 1,
        );
    final displayBins = magnitudes.sublist(0, maxBin + 1);

    if (displayBins.isEmpty) return;

    // Find max magnitude for scaling
    final maxMag = displayBins.reduce(math.max).clamp(0.001, double.infinity);

    // Find peak bin (excluding DC bin 0)
    double peakMag = 0;
    int peakIndex = 1;
    for (int i = 1; i < displayBins.length; i++) {
      if (displayBins[i] > peakMag) {
        peakMag = displayBins[i];
        peakIndex = i;
      }
    }

    final barWidth = chartRect.width / displayBins.length;

    // Draw grid
    _drawGrid(canvas, chartRect, maxMag);

    // Draw bars
    for (int i = 0; i < displayBins.length; i++) {
      final isPeak = i == peakIndex && peakMag > 0;
      final barHeight = (displayBins[i] / maxMag) * chartRect.height;
      final x = chartRect.left + i * barWidth;
      final y = chartRect.bottom - barHeight;

      final paint = Paint()
        ..color = isPeak ? _peakColor : _barColor.withValues(
            alpha: (0.3 + 0.5 * (displayBins[i] / maxMag)).clamp(0.0, 1.0));

      canvas.drawRect(
        Rect.fromLTWH(x, y, barWidth.clamp(0.5, double.infinity), barHeight),
        paint,
      );
    }

    // Draw axes labels
    _drawAxesLabels(canvas, chartRect, maxMag);

    // Draw peak label
    if (peakMag > 0) {
      final peakFreq = peakIndex * sampleRate / fftSize;
      final labelStyle = TextStyle(
        color: _peakColor,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${peakFreq.toStringAsFixed(1)} Hz',
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelX = (chartRect.left + peakIndex * barWidth + barWidth / 2 -
              tp.width / 2)
          .clamp(chartRect.left, chartRect.right - tp.width);
      final labelY = (chartRect.bottom -
              (displayBins[peakIndex] / maxMag) * chartRect.height -
              tp.height -
              4)
          .clamp(chartRect.top, chartRect.bottom - tp.height);
      tp.paint(canvas, Offset(labelX, labelY));
    }

    // Border
    final borderPaint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(chartRect, borderPaint);
  }

  void _drawGrid(Canvas canvas, Rect rect, double maxMag) {
    final paint = Paint()
      ..color = _gridColor
      ..strokeWidth = 0.5;

    // Horizontal grid at 25% intervals
    for (int i = 1; i <= 3; i++) {
      final y = rect.top + rect.height * i / 4;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }

    // Draw vertical grid lines at labeled frequencies
    final gridStep = maxDisplayFreq <= 30.0 ? 5.0 : 25.0;
    for (double freq = gridStep; freq <= maxDisplayFreq; freq += gridStep) {
      final fftSize = magnitudes.length * 2;
      final bin = freq * fftSize / sampleRate;
      final x = rect.left + (bin / magnitudes.length) * rect.width;
      if (x > rect.left && x < rect.right) {
        canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
      }
    }
  }

  void _drawAxesLabels(Canvas canvas, Rect rect, double maxMag) {
    // X-axis frequency labels
    final xLabelStyle = TextStyle(color: _labelColor, fontSize: 9);
    final gridStep = maxDisplayFreq <= 30.0 ? 5.0 : 25.0;

    for (double freq = gridStep; freq <= maxDisplayFreq; freq += gridStep) {
      final fftSize = magnitudes.length * 2;
      final bin = freq * fftSize / sampleRate;
      final x = rect.left + (bin / magnitudes.length) * rect.width;

      if (x >= rect.left && x <= rect.right) {
        final tp = TextPainter(
          text: TextSpan(text: '$freq', style: xLabelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, rect.bottom + 4));
      }
    }

    // "Hz" label at the end
    final hzTp = TextPainter(
      text: TextSpan(text: 'Hz', style: xLabelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    hzTp.paint(
      canvas,
      Offset(rect.right - hzTp.width, rect.bottom + 4),
    );

    // Y-axis label (magnitude)
    for (int i = 0; i <= 4; i++) {
      final y = rect.bottom - rect.height * i / 4;
      final val = maxMag * i / 4;
      final tp = TextPainter(
        text: TextSpan(
          text: val > 100 ? val.toStringAsFixed(0) : val.toStringAsFixed(1),
          style: xLabelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(_leftPad - tp.width - 4, y - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) =>
      oldDelegate.magnitudes != magnitudes ||
      oldDelegate.sampleRate != sampleRate ||
      oldDelegate.maxDisplayFreq != maxDisplayFreq;
}
