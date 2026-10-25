import 'dart:async';

import 'package:flutter/material.dart';

/// Modal dialog requiring a 30-second delay and typing "I have an urgent reason"
/// to prevent impulsive disabling during active Full Restriction phases or active cooldowns.
class AntiImpulseDialog extends StatefulWidget {
  final String activeReason;
  final VoidCallback onConfirmed;

  const AntiImpulseDialog({
    super.key,
    required this.activeReason,
    required this.onConfirmed,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String activeReason,
    required VoidCallback onConfirmed,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AntiImpulseDialog(
        activeReason: activeReason,
        onConfirmed: onConfirmed,
      ),
    );
  }

  @override
  State<AntiImpulseDialog> createState() => _AntiImpulseDialogState();
}

class _AntiImpulseDialogState extends State<AntiImpulseDialog> {
  static const String requiredPhrase = 'I have an urgent reason';
  static const int totalSeconds = 30;

  int _remainingSeconds = totalSeconds;
  Timer? _timer;
  final TextEditingController _controller = TextEditingController();
  bool _isPhraseMatched = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _controller.addListener(_checkPhrase);
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _checkPhrase() {
    final text = _controller.text.trim();
    final matched = text.toLowerCase() == requiredPhrase.toLowerCase();
    if (matched != _isPhraseMatched) {
      setState(() {
        _isPhraseMatched = matched;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canUnlock = _remainingSeconds == 0 && _isPhraseMatched;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              color: Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Anti-Impulse Lock',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.activeReason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'To prevent mindless scrolling impulses, disabling restriction requires a 30-second mindful pause and typing the confirmation phrase below.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // 30-Second Countdown Indicator
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _remainingSeconds > 0
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _remainingSeconds > 0 ? Colors.orange : Colors.green,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _remainingSeconds > 0
                          ? Icons.timer_outlined
                          : Icons.check_circle_rounded,
                      color: _remainingSeconds > 0
                          ? Colors.orange
                          : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _remainingSeconds > 0
                          ? 'Wait $_remainingSeconds seconds'
                          : 'Pause complete! Ready to unlock',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds > 0
                            ? Colors.orange.shade800
                            : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Type: "$requiredPhrase"',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: requiredPhrase,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                suffixIcon: _isPhraseMatched
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep Focusing'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: canUnlock
              ? () {
                  Navigator.of(context).pop(true);
                  widget.onConfirmed();
                }
              : null,
          child: const Text('Confirm Unlock'),
        ),
      ],
    );
  }
}
