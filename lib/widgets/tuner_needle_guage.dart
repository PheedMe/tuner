import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A semicircle tuner gauge with a needle that points based on [cents].
///
/// [cents] should be in the range -50 to +50 (values outside are clamped).
/// -50 cents maps to a needle rotation of -1.55 rad, +50 cents maps to
/// +1.55 rad, and 0 cents points straight up (0 rad) — matching the
/// mapping already validated by hand with Transform.rotate.
///
/// The needle's rendered angle animates toward each new target rather
/// than snapping instantly, so normal frame-to-frame jitter in the
/// (already-smoothed) cents value reads as gentle, steady motion rather
/// than a nervous twitch. Feed this widget your already-smoothed cents
/// value (e.g. from TunerSmoother) — this widget only smooths the visual
/// motion, not the underlying pitch data.
class TunerNeedleGauge extends StatelessWidget {
  const TunerNeedleGauge({
    super.key,
    required this.cents,
    this.size = const Size(280, 160),
    this.animationDuration = const Duration(milliseconds: 180),
  });

  /// Current cents deviation, -50 (flat) to +50 (sharp). Pass 0 for
  /// "no reading yet" if you want the needle centered at rest.
  final double cents;

  /// Overall size of the gauge widget.
  final Size size;

  /// How long the needle takes to ease toward a new angle. Shorter feels
  /// snappier but more jittery on noisy input; longer feels calmer but
  /// laggier on genuine fast pitch changes.
  final Duration animationDuration;

  static const double _maxAngleRad = 1.55;
  static const double _maxCents = 50;

  double get _targetAngle {
    final clamped = cents.clamp(-_maxCents, _maxCents);
    return (clamped / _maxCents) * _maxAngleRad;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Static background: arc, colored zones, tick marks.
          CustomPaint(
            size: size,
            painter: _GaugeArcPainter(),
          ),
          // Needle: eases toward _targetAngle instead of snapping.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _targetAngle),
            duration: animationDuration,
            curve: Curves.easeOut,
            builder: (context, angle, child) {
              return Transform.rotate(
                angle: angle,
                alignment: Alignment.bottomCenter,
                child: child,
              );
            },
            child: CustomPaint(
              size: size,
              painter: _NeedlePainter(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the static semicircle background: colored in-tune/sharp/flat
/// zones and tick marks at -50, -25, 0, +25, +50 cents.
class _GaugeArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2, size.height) - 12;

    // Background arc (flat/sharp zone, red-ish).
    final backgroundPaint = Paint()
      ..color = Colors.red.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi, // start angle: left side (180deg)
      math.pi, // sweep: half circle to right side
      false,
      backgroundPaint,
    );

    // Middle "in tune" zone, roughly +/-10 cents worth of arc, in green.
    final inTunePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    const inTuneFraction = 10 / 50; // +/-10 cents out of +/-50 range
    final inTuneSweep = math.pi * inTuneFraction;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi / 2 - inTuneSweep,
      inTuneSweep * 2,
      false,
      inTunePaint,
    );

    // Tick marks at -50, -25, 0, +25, +50 cents.
    final tickPaint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 2;

    for (final tickCents in [-50, -25, 0, 25, 50]) {
      final angle = (tickCents / 50) * 1.55 - math.pi / 2;
      final outer = Offset(
        center.dx + (radius + 10) * math.cos(angle),
        center.dy + (radius + 10) * math.sin(angle),
      );
      final inner = Offset(
        center.dx + (radius - 8) * math.cos(angle),
        center.dy + (radius - 8) * math.sin(angle),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugeArcPainter oldDelegate) => false;
}

/// Draws the needle itself: a simple tapered line from the pivot (bottom
/// center) pointing upward. Rotation is applied externally via
/// Transform.rotate, so this painter always draws pointing straight up.
class _NeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, size.height);
    final tip = Offset(size.width / 2, size.height - (size.height - 20));

    final needlePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(pivot, tip, needlePaint);

    // Small circle at the pivot to anchor it visually.
    canvas.drawCircle(pivot, 6, Paint()..color = Colors.black87);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) => false;
}