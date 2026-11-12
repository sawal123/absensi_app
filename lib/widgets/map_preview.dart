import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_palette.dart';

/// Stylised map used on the attendance confirmation screen.
/// It is a pure painter so the slice stays asset-free.
class MapPreview extends StatelessWidget {
  const MapPreview({
    super.key,
    required this.officeName,
    required this.radiusMeters,
    this.height = 260,
  });

  final String officeName;
  final int radiusMeters;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _MapPainter())),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppPalette.softShadow,
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      size: 22,
                      color: AppPalette.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      officeName,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppPalette.primary,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 7, height: 7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Radius kantor $radiusMeters m',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppPalette.surface,
                  shape: BoxShape.circle,
                  boxShadow: AppPalette.softShadow,
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  size: 20,
                  color: AppPalette.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEFF3F8),
    );

    final roads = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height * 0.30),
      Offset(size.width, size.height * 0.20),
      roads,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.70),
      Offset(size.width, size.height * 0.80),
      roads,
    );
    canvas.drawLine(
      Offset(size.width * 0.20, 0),
      Offset(size.width * 0.28, size.height),
      roads,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, 0),
      Offset(size.width * 0.66, size.height),
      roads,
    );

    _block(canvas, size, 0.030, 0.050, 0.170, 0.170, const Color(0xFFDDEBE2));
    _block(canvas, size, 0.330, 0.040, 0.110, 0.110, const Color(0xFFE3E9F1));
    _block(canvas, size, 0.460, 0.050, 0.120, 0.100, const Color(0xFFE3E9F1));
    _block(canvas, size, 0.760, 0.040, 0.210, 0.180, const Color(0xFFE3E9F1));
    _block(canvas, size, 0.050, 0.400, 0.110, 0.170, const Color(0xFFE3E9F1));
    _block(canvas, size, 0.330, 0.430, 0.100, 0.110, const Color(0xFFE9EFF7));
    _block(canvas, size, 0.780, 0.360, 0.170, 0.170, const Color(0xFFE3E9F1));
    _block(canvas, size, 0.060, 0.780, 0.180, 0.180, const Color(0xFFE3E9F1));
    _block(canvas, size, 0.320, 0.720, 0.100, 0.140, const Color(0xFFE9EFF7));
    _block(canvas, size, 0.740, 0.660, 0.220, 0.260, const Color(0xFFDDEBE2));

    final center = Offset(size.width / 2, size.height / 2);
    const radius = 68.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppPalette.primary.withValues(alpha: 0.07),
    );
    _dashedCircle(
      canvas,
      center,
      radius,
      Paint()
        ..color = AppPalette.primary.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final dot = Paint()..color = AppPalette.primary;
    final dotCenter = Offset(
      center.dx + radius * 0.62,
      center.dy + radius * 0.58,
    );
    canvas.drawCircle(dotCenter, 6, Paint()..color = Colors.white);
    canvas.drawCircle(dotCenter, 4, dot);
  }

  void _block(
    Canvas canvas,
    Size size,
    double left,
    double top,
    double width,
    double height,
    Color color,
  ) {
    final rect = Rect.fromLTWH(
      size.width * left,
      size.height * top,
      size.width * width,
      size.height * height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()..color = color,
    );
  }

  void _dashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const dash = 6.0;
    const gap = 5.0;
    final circumference = 2 * math.pi * radius;
    final count = (circumference / (dash + gap)).floor();
    final sweep = (dash + gap) / radius;

    for (var i = 0; i < count; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        dash / radius,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => false;
}
