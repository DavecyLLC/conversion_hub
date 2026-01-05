import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StepsPanel extends StatelessWidget {
  final List<String> lines;

  /// Title shown when collapsed/expanded.
  final String title;

  /// Whether it starts expanded.
  final bool initiallyExpanded;

  /// Show a "Copy" action to copy all steps.
  final bool showCopy;

  /// Reduce vertical spacing for smaller screens.
  final bool dense;

  /// Padding inside the expanded area.
  final EdgeInsetsGeometry contentPadding;

  const StepsPanel({
    super.key,
    required this.lines,
    this.title = 'Show steps',
    this.initiallyExpanded = false,
    this.showCopy = true,
    this.dense = false,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();

    final textStyle = Theme.of(context).textTheme.bodyMedium;

    return Theme(
      // Makes ExpansionTile feel cleaner (no default divider)
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: contentPadding,
        title: Text(title),
        trailing: showCopy
            ? _CopyButton(lines: lines)
            : const Icon(Icons.expand_more),
        children: [
          for (final line in lines)
            Padding(
              padding: EdgeInsets.only(top: dense ? 6 : 8),
              child: Text(line, style: textStyle),
            ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final List<String> lines;
  const _CopyButton({required this.lines});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Copy steps',
      icon: const Icon(Icons.copy, size: 18),
      onPressed: () async {
        final text = lines.join('\n');
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Steps copied')),
        );
      },
    );
  }
}
