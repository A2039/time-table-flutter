import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/focus_models.dart';
import '../../providers/focus_providers.dart';
import 'installed_app_picker_dialog.dart';

/// Card managing the user-configurable Essential-App Allowlist
class FocusAllowlistCard extends ConsumerWidget {
  const FocusAllowlistCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusModeProvider);
    final theme = Theme.of(context);
    final allowlist = focus.allowlist;

    // Group apps by category
    final grouped = <AllowlistCategory, List<FocusAllowlistApp>>{};
    for (final app in allowlist) {
      grouped.putIfAbsent(app.category, () => []).add(app);
    }

    final allowedCount = allowlist.where((a) => a.isAllowed).length;

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
            // Header
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VIP Exception Allowlist (Always Allowed 24/7)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$allowedCount of ${allowlist.length} apps permitted 24/7',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    InstalledAppPickerDialog.show(
                      context,
                      isForAllowlist: true,
                      onSelected: (app, cat) {
                        ref
                            .read(focusModeProvider.notifier)
                            .addCustomAllowlistApp(
                              name: app.appName,
                              packageName: app.packageName,
                              category: cat ?? AllowlistCategory.utilities,
                            );
                      },
                    );
                  },
                  icon: const Icon(Icons.apps_rounded),
                  tooltip: 'Pick from Installed Apps',
                ),
                IconButton(
                  onPressed: () => _showAddCustomAppDialog(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Add Custom App Manually',
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'Essential phone, UPI, banking, and study tools that are never blocked in any phase.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 16),

            // Categorized App Lists
            ...AllowlistCategory.values.map((category) {
              final apps = grouped[category] ?? [];
              if (apps.isEmpty) return const SizedBox.shrink();

              return ExpansionTile(
                initiallyExpanded:
                    category == AllowlistCategory.phone ||
                    category == AllowlistCategory.payments ||
                    category == AllowlistCategory.study,
                leading: Icon(
                  category.icon,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  category.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${apps.where((a) => a.isAllowed).length} allowed',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                tilePadding: EdgeInsets.zero,
                children: apps.map((app) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      app.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      app.packageName,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (app.isCustom)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () {
                              ref
                                  .read(focusModeProvider.notifier)
                                  .removeCustomAllowlistApp(app.id);
                            },
                          ),
                        Switch.adaptive(
                          value: app.isAllowed,
                          onChanged: (val) {
                            ref
                                .read(focusModeProvider.notifier)
                                .toggleAllowlistApp(app.id, val);
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showAddCustomAppDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final pkgCtrl = TextEditingController();
    AllowlistCategory selectedCategory = AllowlistCategory.study;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Custom Allowlist App'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'App Name',
                      hintText: 'e.g. Google Drive',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pkgCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Package Name',
                      hintText: 'e.g. com.google.android.apps.docs',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AllowlistCategory>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: AllowlistCategory.values.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat.title),
                      );
                    }).toList(),
                    onChanged: (cat) {
                      if (cat != null) setState(() => selectedCategory = cat);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final pkg = pkgCtrl.text.trim();
                  if (name.isNotEmpty && pkg.isNotEmpty) {
                    ref
                        .read(focusModeProvider.notifier)
                        .addCustomAllowlistApp(
                          name: name,
                          packageName: pkg,
                          category: selectedCategory,
                        );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Add App'),
              ),
            ],
          );
        },
      ),
    );
  }
}
