import 'package:flutter/material.dart';

/// Pill badge indicating Weekday or Weekend schedule type
class DayTypeChip extends StatelessWidget {
  final String dayType; // 'weekday' or 'weekend'
  final bool compact;

  const DayTypeChip({super.key, required this.dayType, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWeekend = dayType.toLowerCase() == 'weekend';
    final isDark = theme.brightness == Brightness.dark;

    final bg = isWeekend
        ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));

    final fg = isWeekend
        ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA))
        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569));

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isWeekend ? Icons.weekend_rounded : Icons.calendar_today_rounded,
            size: compact ? 12 : 14,
            color: fg,
          ),
          const SizedBox(width: 5),
          Text(
            isWeekend ? 'Weekend' : 'Weekday',
            style: TextStyle(
              color: fg,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
