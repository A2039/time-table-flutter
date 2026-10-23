import 'package:flutter/material.dart';

/// Cohesive, modern Material 3 color palette for productivity and timetable tracking
class AppColors {
  AppColors._();

  // Primary Brand: Deep Indigo / Violet
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryContainer = Color(0xFFEEF2FF); // Indigo 50
  static const Color onPrimary = Colors.white;
  static const Color onPrimaryContainer = Color(0xFF312E81);

  // Dark variant primary
  static const Color primaryDark = Color(0xFF818CF8); // Indigo 400
  static const Color primaryContainerDark = Color(0xFF312E81);
  static const Color onPrimaryDark = Color(0xFF0F172A);

  // Secondary Brand: Slate / Neutral
  static const Color secondary = Color(0xFF475569); // Slate 600
  static const Color secondaryContainer = Color(0xFFF1F5F9);
  static const Color onSecondary = Colors.white;
  static const Color onSecondaryContainer = Color(0xFF0F172A);

  // Status: On-Time (Emerald)
  static const Color statusOnTime = Color(0xFF10B981);
  static const Color statusOnTimeContainer = Color(0xFFD1FAE5);
  static const Color onStatusOnTime = Color(0xFF065F46);

  // Status: Late (Amber)
  static const Color statusLate = Color(0xFFF59E0B);
  static const Color statusLateContainer = Color(0xFFFEF3C7);
  static const Color onStatusLate = Color(0xFF92400E);

  // Status: Not Completed (Rose)
  static const Color statusNotCompleted = Color(0xFFEF4444);
  static const Color statusNotCompletedContainer = Color(0xFFFFE4E6);
  static const Color onStatusNotCompleted = Color(0xFF991B1B);

  // Status: Unrecorded (Slate)
  static const Color statusUnrecorded = Color(0xFF64748B);
  static const Color statusUnrecordedContainer = Color(0xFFF8FAFC);
  static const Color onStatusUnrecorded = Color(0xFF334155);

  // Backgrounds & Surfaces - Light
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Colors.white;
  static const Color surfaceVariantLight = Color(0xFFF1F5F9); // Slate 100
  static const Color outlineLight = Color(0xFFE2E8F0); // Slate 200

  // Backgrounds & Surfaces - Dark
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color surfaceVariantDark = Color(0xFF334155); // Slate 700
  static const Color outlineDark = Color(0xFF475569); // Slate 600
}
