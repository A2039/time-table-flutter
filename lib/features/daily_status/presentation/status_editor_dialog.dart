import 'package:flutter/material.dart';

/// Modal dialog allowing the user to select or change status for a specific activity
class StatusEditorDialog extends StatefulWidget {
  final int activityNo;
  final String activityTitle;
  final String category;
  final String time;
  final dynamic initialStatus; // 'y', 'n', int > 0, or null
  final Future<void> Function(dynamic newStatus) onSave;

  const StatusEditorDialog({
    super.key,
    required this.activityNo,
    required this.activityTitle,
    required this.category,
    required this.time,
    required this.initialStatus,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required int activityNo,
    required String activityTitle,
    required String category,
    required String time,
    required dynamic currentStatus,
    required Future<void> Function(dynamic newStatus) onSave,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => StatusEditorDialog(
        activityNo: activityNo,
        activityTitle: activityTitle,
        category: category,
        time: time,
        initialStatus: currentStatus,
        onSave: onSave,
      ),
    );
  }

  @override
  State<StatusEditorDialog> createState() => _StatusEditorDialogState();
}

class _StatusEditorDialogState extends State<StatusEditorDialog> {
  late String _selectedType; // 'y', 'late', 'n', 'unrecorded'
  late int _lateMinutes;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final status = widget.initialStatus;
    if (status == 'y' || status == 'Y') {
      _selectedType = 'y';
      _lateMinutes = 10;
    } else if (status == 'n' || status == 'N') {
      _selectedType = 'n';
      _lateMinutes = 10;
    } else if (status is int && status > 0) {
      _selectedType = 'late';
      _lateMinutes = status;
    } else if (status is String &&
        int.tryParse(status) != null &&
        int.parse(status) > 0) {
      _selectedType = 'late';
      _lateMinutes = int.parse(status);
    } else {
      _selectedType = 'unrecorded';
      _lateMinutes = 10;
    }
  }

  dynamic _computeResultStatus() {
    switch (_selectedType) {
      case 'y':
        return 'y';
      case 'n':
        return 'n';
      case 'late':
        return _lateMinutes > 0 ? _lateMinutes : 5;
      case 'unrecorded':
      default:
        return null;
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final newStatus = _computeResultStatus();
      await widget.onSave(newStatus);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      title: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              '#${widget.activityNo}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.activityTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.category} • ${widget.time}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Select Completion Status:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _selectedType,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedType = val);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Option 1: On-Time
                  _buildOption(
                    value: 'y',
                    title: 'Completed On Time',
                    subtitle: 'Activity finished according to schedule ("y")',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF10B981),
                  ),

                  // Option 2: Completed Late
                  _buildOption(
                    value: 'late',
                    title: 'Completed Late',
                    subtitle: 'Completed, but delayed by minutes',
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFFF59E0B),
                  ),

                  if (_selectedType == 'late') ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Late Duration:',
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                '$_lateMinutes min',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _lateMinutes.toDouble().clamp(1.0, 120.0),
                            min: 1,
                            max: 120,
                            divisions: 119,
                            label: '$_lateMinutes min',
                            activeColor: const Color(0xFFF59E0B),
                            onChanged: (val) {
                              setState(() {
                                _lateMinutes = val.round();
                              });
                            },
                          ),
                          Wrap(
                            spacing: 8,
                            children: [5, 10, 15, 30, 45, 60].map((mins) {
                              final isSelected = _lateMinutes == mins;
                              return ChoiceChip(
                                label: Text('$mins m'),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _lateMinutes = mins;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Option 3: Not Completed
                  _buildOption(
                    value: 'n',
                    title: 'Not Completed',
                    subtitle: 'Did not complete this activity ("n")',
                    icon: Icons.cancel_rounded,
                    color: const Color(0xFFEF4444),
                  ),

                  // Option 4: Unrecorded / Reset
                  _buildOption(
                    value: 'unrecorded',
                    title: 'Not Recorded / Reset',
                    subtitle: 'Leave slot empty or reset entry (null)',
                    icon: Icons.radio_button_unchecked_rounded,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save Status'),
        ),
      ],
    );
  }

  Widget _buildOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedType == value;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Radio<String>(value: value, activeColor: color),
          ],
        ),
      ),
    );
  }
}
