import 'package:flutter/material.dart';

import '../../core/sensors/sensor_constants.dart';

/// Animated visual guide showing correct phone placement for each search mode.
///
/// Draws a side-view phone silhouette, the contact surface, and animated
/// indicators showing where to place the phone and how to orient it.
class PhonePositionGuide extends StatefulWidget {
  final SearchMode mode;

  const PhonePositionGuide({super.key, required this.mode});

  @override
  State<PhonePositionGuide> createState() => _PhonePositionGuideState();
}

class _PhonePositionGuideState extends State<PhonePositionGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PhonePositionGuide old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = switch (widget.mode) {
      SearchMode.imu => (primary: const Color(0xFFFF6B35), label: 'IMU'),
      SearchMode.audio => (primary: const Color(0xFF00BCD4), label: 'Audio'),
    };

    final instruction = switch (widget.mode) {
      SearchMode.imu => 'Apoyá el teléfono plano sobre la superficie',
      SearchMode.audio => 'Presioná el micrófono contra la superficie',
    };

    final detail = switch (widget.mode) {
      SearchMode.imu => 'El giroscopio detecta las vibraciones\na través del material',
      SearchMode.audio => 'El micrófono capta los latidos\npor conducción sólida',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          // Animated phone illustration
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => SizedBox(
              height: 120,
              child: _PhoneIllustration(
                mode: widget.mode,
                pulse: _ctrl.value,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              colors.label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.primary,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            instruction,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the phone silhouette, surface, and animated contact indicator.
class _PhoneIllustration extends StatelessWidget {
  final SearchMode mode;
  final double pulse;
  final Color color;

  const _PhoneIllustration({
    required this.mode,
    required this.pulse,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PhonePainter(mode: mode, pulse: pulse, color: color),
      size: const Size(double.infinity, 120),
    );
  }
}

class _PhonePainter extends CustomPainter {
  final SearchMode mode;
  final double pulse;
  final Color color;

  _PhonePainter({
    required this.mode,
    required this.pulse,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Phone body dimensions
    final phoneW = 100.0;
    final phoneH = 56.0;
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: phoneW, height: phoneH),
      const Radius.circular(10),
    );

    final surfaceY = cy + phoneH / 2 + 4;

    if (mode == SearchMode.imu) {
      _drawImu(canvas, phoneRect, surfaceY, cx);
    } else {
      _drawAudio(canvas, phoneRect, surfaceY, cx);
    }
  }

  void _drawImu(Canvas canvas, RRect phoneRect, double surfaceY, double cx) {
    // Surface line
    _drawSurface(canvas, surfaceY, cx);

    // Phone body — flat on surface
    final phonePaint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(phoneRect, phonePaint);

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(phoneRect, borderPaint);

    // Screen area
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, phoneRect.center.dy),
        width: phoneRect.width - 20,
        height: phoneRect.height - 14,
      ),
      const Radius.circular(6),
    );
    final screenPaint = Paint()
      ..color = const Color(0xFF0F3460)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(screenRect, screenPaint);

    // Gyro sensor indicator (center) — pulsing
    final gyroR = 5.0 + pulse * 3;
    final gyroPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2 + pulse * 0.3);
    canvas.drawCircle(Offset(cx, phoneRect.center.dy), gyroR + 4, gyroPaint);

    final gyroCorePaint = Paint()..color = color;
    canvas.drawCircle(Offset(cx, phoneRect.center.dy), 4, gyroCorePaint);

    // Downward arrow at top
    _drawArrows(canvas, cx, phoneRect.top - 20, -1, color);
  }

  void _drawAudio(Canvas canvas, RRect phoneRect, double surfaceY, double cx) {
    // Phone body — upright, tilted slightly toward surface
    final matrix = Matrix4.identity()
      ..setTranslationRaw(cx, surfaceY - phoneRect.height / 2 - 12, 0)
      ..rotateZ(-0.08); // slight tilt toward surface
    final rotatedRect = Rect.fromLTWH(
      -phoneRect.width / 2,
      -phoneRect.height / 2,
      phoneRect.width,
      phoneRect.height,
    );

    canvas.save();
    canvas.transform(matrix.storage);

    final phonePaint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rotatedRect, const Radius.circular(10)),
      phonePaint,
    );

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rotatedRect, const Radius.circular(10)),
      borderPaint,
    );

    // Screen area
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, 0),
        width: phoneRect.width - 18,
        height: phoneRect.height - 14,
      ),
      const Radius.circular(6),
    );
    final screenPaint = Paint()
      ..color = const Color(0xFF0F3460)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(screenRect, screenPaint);

    canvas.restore();

    // Mic indicator at bottom edge — pulsing contact point
    final micY = surfaceY - 6;
    final micPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15 + pulse * 0.3);
    canvas.drawCircle(Offset(cx, micY), 6 + pulse * 4, micPaint);

    final micCorePaint = Paint()..color = color;
    canvas.drawCircle(Offset(cx, micY), 4, micCorePaint);

    // Surface line
    _drawSurface(canvas, surfaceY, cx);

    // Side arrow
    _drawArrows(canvas, cx + phoneRect.width / 2 + 24, surfaceY - 12, 0, color);
  }

  void _drawSurface(Canvas canvas, double surfaceY, double cx) {
    // Thick surface line
    final surfacePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, surfaceY), width: 200, height: 6),
      surfacePaint,
    );

    // Subtle texture lines
    for (int i = -4; i <= 4; i++) {
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.03)
        ..strokeWidth = 0.5;
      canvas.drawLine(
        Offset(cx - 90 + i * 20, surfaceY - 3),
        Offset(cx - 70 + i * 20, surfaceY + 3),
        linePaint,
      );
    }
  }

  void _drawArrows(
      Canvas canvas, double x, double y, int dir, Color color) {
    // dir: -1 = downward, 0 = rightward, 1 = upward
    final arrowPaint = Paint()
      ..color = color.withValues(alpha: 0.5 + pulse * 0.4)
      ..style = PaintingStyle.fill;

    final path = Path();
    if (dir == -1) {
      // Downward arrow (IMU: place phone down)
      path.moveTo(x, y - 14 + pulse * 4);
      path.lineTo(x - 6, y - 2 + pulse * 4);
      path.lineTo(x + 6, y - 2 + pulse * 4);
      path.close();
    } else {
      // Rightward arrow (Audio: press against surface)
      path.moveTo(x - 14 + pulse * 4, y);
      path.lineTo(x - 2 + pulse * 4, y - 6);
      path.lineTo(x - 2 + pulse * 4, y + 6);
      path.close();
    }
    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(_PhonePainter old) => old.pulse != pulse || old.mode != mode;
}
