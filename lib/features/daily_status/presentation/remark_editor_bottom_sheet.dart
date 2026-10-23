import 'package:flutter/material.dart';

/// Bottom sheet for creating and updating daily reflection remarks
class RemarkEditorBottomSheet extends StatefulWidget {
  final String date;
  final String initialRemark;
  final Future<void> Function(String newRemark) onSave;

  const RemarkEditorBottomSheet({
    super.key,
    required this.date,
    required this.initialRemark,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required String date,
    required String currentRemark,
    required Future<void> Function(String newRemark) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => RemarkEditorBottomSheet(
        date: date,
        initialRemark: currentRemark,
        onSave: onSave,
      ),
    );
  }

  @override
  State<RemarkEditorBottomSheet> createState() =>
      _RemarkEditorBottomSheetState();
}

class _RemarkEditorBottomSheetState extends State<RemarkEditorBottomSheet> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialRemark);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _controller.text.trim() != widget.initialRemark.trim();

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(_controller.text.trim());
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.notes_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Remark / Reflection',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Date: ${widget.date}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Share reflections, accomplishments, or challenges for today...',
              helperText: _hasChanges ? 'Unsaved changes' : 'Saved',
              helperStyle: TextStyle(
                color: _hasChanges
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: _hasChanges ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Save Reflection'),
          ),
        ],
      ),
    );
  }
}
