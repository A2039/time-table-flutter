import 'package:flutter/material.dart';

/// Clean accessible badge displaying activity completion status
class StatusBadge extends StatelessWidget {
  final dynamic statusValue; // 'y', 'n', int > 0, or null
  final bool compact;
  final VoidCallback? onTap;

  const StatusBadge({
    super.key,
    required this.statusValue,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;
    IconData icon;
    String label;

    if (statusValue == 'y' || statusValue == 'Y') {
      bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);
      icon = Icons.check_circle_rounded;
      label = 'On Time';
    } else if (statusValue == 'n' || statusValue == 'N') {
      bg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFFE4E6);
      fg = isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
      icon = Icons.cancel_rounded;
      label = 'Not Done';
    } else if (statusValue is int && statusValue > 0) {
      bg = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
      fg = isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);
      icon = Icons.schedule_rounded;
      label = '+$statusValue min';
    } else if (statusValue is String &&
        int.tryParse(statusValue) != null &&
        int.parse(statusValue) > 0) {
      final mins = int.parse(statusValue);
      bg = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
      fg = isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);
      icon = Icons.schedule_rounded;
      label = '+$mins min';
    } else {
      bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      icon = Icons.radio_button_unchecked_rounded;
      label = 'Unrecorded';
    }

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: badge,
      );
    }

    return badge;
  }
}
