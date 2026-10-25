import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/focus_models.dart';
import '../../providers/focus_providers.dart';
import 'anti_impulse_dialog.dart';

/// Top card displaying active Focus Mode status, current phase, next transition, and master toggle
class FocusStatusCard extends ConsumerWidget {
  const FocusStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusModeProvider);
    final transition = ref.watch(focusNextTransitionProvider);
    final theme = Theme.of(context);

    final isFocusActive = focus.isFocusActive;
    final activeColor = focus.isOverrideActive
        ? const Color(0xFFF59E0B)
        : (isFocusActive
              ? focus.currentPhase.color
              : theme.colorScheme.outline);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: activeColor.withValues(alpha: isFocusActive ? 0.6 : 0.2),
          width: isFocusActive ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Switch & Phase Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    focus.isOverrideActive
                        ? Icons.coffee_rounded
                        : (isFocusActive
                              ? focus.currentPhase.icon
                              : Icons.schedule_rounded),
                    color: activeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        focus.isOverrideActive
                            ? 'Emergency Override Break'
                            : (focus.enabled
                                  ? (focus.isManualFocus
                                        ? 'Manual Focus Active'
                                        : focus.currentPhase.displayName)
                                  : 'Focus Mode Disabled'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isFocusActive
                              ? activeColor
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        focus.enabled
                            ? (focus.isOverrideActive
                                  ? 'Break in progress'
                                  : (isFocusActive
                                        ? 'Digital wellbeing active'
                                        : 'Scheduled hours idle'))
                            : 'Enable to start schedule monitoring',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: focus.enabled,
                  onChanged: (val) {
                    if (!val && focus.isAntiImpulseLocked) {
                      final reason = focus.currentPhase.isFullRestriction
                          ? '${focus.currentPhase.displayName} is active (0-second grace). Restrictive focus is enforced.'
                          : '${focus.activeCooldowns.length} app(s) currently locked in cooldown.';
                      AntiImpulseDialog.show(
                        context,
                        activeReason: reason,
                        onConfirmed: () {
                          ref
                              .read(focusModeProvider.notifier)
                              .toggleFocusMode(false, bypassAntiImpulse: true);
                        },
                      );
                    } else {
                      ref.read(focusModeProvider.notifier).toggleFocusMode(val);
                    }
                  },
                ),
              ],
            ),

            if (focus.enabled) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Active Cooldowns Banner
              if (focus.activeCooldowns.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_clock_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${focus.activeCooldowns.length} distracting app(s) in Cooldown Lock',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Daily auto-close counter badge
              if (focus.todayBlocksCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${focus.todayBlocksCount} apps forcefully closed by "The Bouncer" today',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Emergency Override Banner (if active)
              if (focus.isOverrideActive &&
                  focus.overrideExpiresAt != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Break ends in ${_formatRemaining(focus.overrideExpiresAt!)}',
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref
                              .read(focusModeProvider.notifier)
                              .cancelEmergencyOverride();
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFFB45309),
                        ),
                        child: const Text('Return Now'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Next Transition Info
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      transition.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'in ${transition.formattedRemaining(DateTime.now())}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Buttons Row (Responsive LayoutBuilder)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 320;
                  final manualButton = OutlinedButton.icon(
                    onPressed: () {
                      if (focus.isManualFocus) {
                        ref.read(focusModeProvider.notifier).endManualFocus();
                      } else {
                        ref.read(focusModeProvider.notifier).startManualFocus();
                      }
                    },
                    icon: Icon(
                      focus.isManualFocus
                          ? Icons.stop_circle_outlined
                          : Icons.play_arrow_rounded,
                      size: 18,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        focus.isManualFocus ? 'End Focus' : 'Start Focus Now',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                  );

                  final breakButton = FilledButton.tonalIcon(
                    onPressed: isFocusActive
                        ? () => _showOverrideConfirmDialog(context, ref, focus)
                        : null,
                    icon: const Icon(Icons.coffee_rounded, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Take ${focus.overrideDurationMinutes}m Break',
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        manualButton,
                        const SizedBox(height: 8),
                        breakButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: manualButton),
                      const SizedBox(width: 10),
                      Expanded(child: breakButton),
                    ],
                  );
                },
              ),
            ],

            const SizedBox(height: 14),

            // Truthful Platform Capability Badge
            InkWell(
              onTap: () => _showCapabilityDisclosure(context, focus.capability),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: focus.capability.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: focus.capability.color.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: focus.capability.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Enforcement: ${focus.capability.label}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: focus.capability.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: focus.capability.color,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRemaining(DateTime expiresAt) {
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return '0 min';
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return '$m m ${s.toString().padLeft(2, '0')} s';
  }

  void _showOverrideConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    FocusState focus,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Take Emergency Break?'),
        content: Text(
          'This activates a ${focus.overrideDurationMinutes}-minute break from Focus Mode. '
          'Calls, banking, and essential communication will remain fully accessible. '
          'Use this break mindfully.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(focusModeProvider.notifier).activateEmergencyOverride();
            },
            child: Text('Start ${focus.overrideDurationMinutes}m Break'),
          ),
        ],
      ),
    );
  }

  void _showCapabilityDisclosure(
    BuildContext context,
    FocusCapability capability,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: capability.color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    capability.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              capability.description,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Truth in Enforcement Policy:\n'
              'Standard consumer operating systems prevent third-party apps from force-closing or killing external apps. '
              'TimeTable strictly follows platform security policies and will never promise impossible blocking mechanisms.',
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
