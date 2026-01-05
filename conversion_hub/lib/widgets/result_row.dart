import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResultRow extends StatelessWidget {
  final String label;
  final String value;

  /// Optional secondary value (e.g. radians, inches, raw units)
  final String? secondary;

  /// Optional custom copy action.
  /// If null, value is copied automatically.
  final VoidCallback? onCopy;

  const ResultRow({
    super.key,
    required this.label,
    required this.value,
    this.secondary,
    this.onCopy,
  });

  Future<void> _defaultCopy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copyHandler = onCopy ?? () => _defaultCopy(context);

    return InkWell(
      onTap: copyHandler,
      onLongPress: copyHandler,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (secondary != null)
                  Text(
                    secondary!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
