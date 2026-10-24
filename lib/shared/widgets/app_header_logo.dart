import 'package:flutter/material.dart';

/// Small circular profile-picture style brand logo icon for application headers
class AppHeaderLogo extends StatelessWidget {
  final double size;

  const AppHeaderLogo({
    super.key,
    this.size = 38.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'asset/logo/time-table-logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.schedule_rounded,
            size: size * 0.55,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
