import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;

  /// Optional header text.
  final String? title;
  final String? subtitle;

  /// Optional trailing widgets (e.g., buttons).
  final List<Widget>? actions;

  /// Layout customization
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double elevation;
  final double borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.actions,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.elevation = 0.5,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || subtitle != null || (actions != null && actions!.isNotEmpty);

    return Card(
      elevation: elevation,
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: padding,
        child: hasHeader
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(title: title, subtitle: subtitle, actions: actions),
                  const SizedBox(height: 12),
                  child,
                ],
              )
            : child,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;

  const _Header({this.title, this.subtitle, this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (actions != null && actions!.isNotEmpty) ...[
          const SizedBox(width: 8),
          Wrap(spacing: 6, runSpacing: 6, children: actions!),
        ],
      ],
    );
  }
}
