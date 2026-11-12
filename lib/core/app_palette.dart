import 'package:flutter/material.dart';

/// Design tokens taken straight from the "Absensi" Figma screens.
abstract final class AppPalette {
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF4C8DF6);

  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;

  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color faint = Color(0xFF94A3B8);

  static const Color border = Color(0xFFE7ECF5);
  static const Color slate = Color(0xFFF1F5F9);
  static const Color blueSoft = Color(0xFFEAF1FE);

  static const Color green = Color(0xFF15803D);
  static const Color greenSoft = Color(0xFFE8F7EE);

  static const Color amber = Color(0xFFB45309);
  static const Color amberSoft = Color(0xFFFEF3C7);

  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEE2E2);

  static const Color headerStart = Color(0xFF1A54E8);
  static const Color headerEnd = Color(0xFF4C8DF6);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [headerStart, headerEnd],
  );

  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 24, offset: Offset(0, 10)),
  ];
}
