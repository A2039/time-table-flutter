import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/focus_models.dart';
import '../../providers/focus_providers.dart';

/// Modal dialog letting the user search and select from installed apps on their device
class InstalledAppPickerDialog extends ConsumerStatefulWidget {
  final bool isForAllowlist;
  final Function(InstalledAppInfo app, AllowlistCategory? category) onSelected;

  const InstalledAppPickerDialog({
    super.key,
    required this.isForAllowlist,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isForAllowlist,
    required Function(InstalledAppInfo app, AllowlistCategory? category)
    onSelected,
  }) {
    return showDialog(
      context: context,
      builder: (context) => InstalledAppPickerDialog(
        isForAllowlist: isForAllowlist,
        onSelected: onSelected,
      ),
    );
  }

  @override
  ConsumerState<InstalledAppPickerDialog> createState() =>
      _InstalledAppPickerDialogState();
}

class _InstalledAppPickerDialogState
    extends ConsumerState<InstalledAppPickerDialog> {
  List<InstalledAppInfo> _allApps = [];
  List<InstalledAppInfo> _filteredApps = [];
  bool _isLoading = true;
  String _searchQuery = '';
  AllowlistCategory _selectedCategory = AllowlistCategory.utilities;

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    final notifier = ref.read(focusModeProvider.notifier);
    final apps = await notifier.getInstalledApps();
    if (mounted) {
      setState(() {
        _allApps = apps;
        _filteredApps = apps;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.trim().isEmpty) {
        _filteredApps = _allApps;
      } else {
        final q = query.toLowerCase();
        _filteredApps = _allApps.where((app) {
          return app.appName.toLowerCase().contains(q) ||
              app.packageName.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.isForAllowlist
        ? 'Add VIP Exception App'
        : 'Add Distracting App';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    widget.isForAllowlist
                        ? Icons.star_rounded
                        : Icons.block_rounded,
                    color: widget.isForAllowlist ? Colors.amber : Colors.orange,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (widget.isForAllowlist) ...[
                Text(
                  'Select Category for Allowlist:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: AllowlistCategory.values.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(
                        cat.title,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedCategory = cat);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search installed apps...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 12),

              // Apps List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredApps.isEmpty
                    ? Center(
                        child: Text(
                          _allApps.isEmpty
                              ? 'No launchable apps found on device'
                              : 'No apps matching "$_searchQuery"',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredApps.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              foregroundColor:
                                  theme.colorScheme.onPrimaryContainer,
                              child: Text(
                                app.appName.isNotEmpty
                                    ? app.appName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              app.appName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              app.packageName,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                widget.onSelected(
                                  app,
                                  widget.isForAllowlist
                                      ? _selectedCategory
                                      : null,
                                );
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'Add',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
