import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/focus_providers.dart';
import 'installed_app_picker_dialog.dart';

/// Card managing tracked distracting apps (Instagram, Facebook, etc.) and showing live usage
class FocusDistractingAppsCard extends ConsumerWidget {
  const FocusDistractingAppsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusModeProvider);
    final theme = Theme.of(context);

    final apps = focus.distractingApps;
    final durations = focus.distractingAppDurationsSeconds;
    final graceLimitSec = focus.gracePeriodMinutes * 60;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Add buttons
            Row(
              children: [
                Icon(
                  Icons.phone_android_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Distracting Apps (5m Limit + Cooldown)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.apps_rounded, size: 18),
                  tooltip: 'Pick from Installed Apps',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    InstalledAppPickerDialog.show(
                      context,
                      isForAllowlist: false,
                      onSelected: (app, _) {
                        ref
                            .read(focusModeProvider.notifier)
                            .addCustomDistractingApp(
                              name: app.appName,
                              packageName: app.packageName,
                            );
                      },
                    );
                  },
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  tooltip: 'Add Custom App Manually',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showAddAppDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'During daytime, opening these apps starts a 5-minute countdown. When time expires, "The Bouncer" auto-closes the app and locks it in cooldown.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),

            // Policy note banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Usage is cumulative within the active focus window. Quick app switches do not reset your grace period.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Distracting Apps Column (avoids nested Scrollable)
            Column(
              children: [
                for (int i = 0; i < apps.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _buildAppTile(
                    context,
                    ref,
                    theme,
                    apps[i],
                    durations[apps[i].packageName] ?? 0,
                    graceLimitSec,
                    focus,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppTile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    dynamic app,
    int usedSeconds,
    int graceLimitSec,
    dynamic focus,
  ) {
    final usedMinutes = (usedSeconds / 60).floor();
    final isOverGrace = usedSeconds >= graceLimitSec;
    final isActiveNow = focus.activeForegroundPackage == app.packageName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Social/App Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  (app.isTracked
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest)
                      .withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getAppIcon(app.id as String),
              size: 18,
              color: app.isTracked ? theme.colorScheme.primary : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),

          // Name, Package, & Live Duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        app.name as String,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: app.isTracked
                              ? theme.colorScheme.onSurface
                              : Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (focus.activeCooldowns.containsKey(app.packageName)) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'COOLDOWN LOCKED',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    if (isActiveNow) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FOREGROUND NOW',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  app.packageName as String,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (focus.isFocusActive && (app.isTracked as bool)) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isOverGrace
                            ? Icons.warning_rounded
                            : Icons.timer_outlined,
                        size: 12,
                        color: isOverGrace
                            ? Colors.red
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isOverGrace
                              ? '$usedMinutes mins used (Grace exceeded: ${focus.gracePeriodMinutes}m)'
                              : '$usedMinutes / ${focus.gracePeriodMinutes} mins used',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isOverGrace
                                ? Colors.red
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Delete custom button
          if (app.isCustom as bool)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              onPressed: () {
                ref
                    .read(focusModeProvider.notifier)
                    .removeCustomDistractingApp(app.id as String);
              },
            ),

          // Toggle switch
          Switch.adaptive(
            value: app.isTracked as bool,
            onChanged: (val) {
              ref
                  .read(focusModeProvider.notifier)
                  .toggleDistractingApp(app.id as String, val);
            },
          ),
        ],
      ),
    );
  }

  IconData _getAppIcon(String id) {
    switch (id) {
      case 'instagram':
        return Icons.camera_alt_rounded;
      case 'facebook':
        return Icons.facebook_rounded;
      case 'twitter':
        return Icons.chat_bubble_outline_rounded;
      case 'reddit':
        return Icons.forum_rounded;
      case 'snapchat':
        return Icons.snapchat_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  void _showAddAppDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final pkgController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Monitored App'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'App Name',
                hintText: 'e.g. TikTok',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pkgController,
              decoration: const InputDecoration(
                labelText: 'Android Package Name',
                hintText: 'e.g. com.zhiliaoapp.musically',
                prefixIcon: Icon(Icons.code_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final pkg = pkgController.text.trim();
              if (name.isNotEmpty && pkg.isNotEmpty) {
                ref
                    .read(focusModeProvider.notifier)
                    .addCustomDistractingApp(name: name, packageName: pkg);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add App'),
          ),
        ],
      ),
    );
  }
}
