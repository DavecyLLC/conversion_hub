import 'package:flutter/material.dart';
import 'package:conversion_hub/state/app_state.dart';
import 'package:conversion_hub/widgets/card.dart';
import 'package:conversion_hub/utils/haptics.dart';

import 'tools_list.dart';

enum ToolListMode { all, favorites, recents }

class ToolsRegistryScreen extends StatelessWidget {
  final ToolListMode mode;
  const ToolsRegistryScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    final tools = allTools;

    final filtered = switch (mode) {
      ToolListMode.all => tools,
      ToolListMode.favorites => tools.where((t) => state.isFavorite(t.id)).toList(),
      ToolListMode.recents => tools.where((t) => state.recents.any((r) => r.toolId == t.id)).toList(),
    };

    if (mode == ToolListMode.recents) {
      filtered.sort((a, b) {
        final aAt = _lastUsedAt(state, a.id);
        final bAt = _lastUsedAt(state, b.id);
        return bAt.compareTo(aAt);
      });
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final tool = filtered[i];
        final fav = state.isFavorite(tool.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tool.title),
              subtitle: Text(tool.subtitle),
              leading: Icon(tool.icon),
              trailing: IconButton(
                tooltip: fav ? 'Unfavorite' : 'Favorite',
                icon: Icon(fav ? Icons.star : Icons.star_border),
                onPressed: () async {
                  await tapHaptic(state.settings.haptics);
                  state.toggleFavorite(tool.id);
                },
              ),
              onTap: () async {
                await tapHaptic(state.settings.haptics);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => tool.builder()),
                );
              },
            ),
          ),
        );
      },
    );
  }

  DateTime _lastUsedAt(AppState state, String toolId) {
    for (final r in state.recents) {
      if (r.toolId == toolId) return r.at; // recents are stored newest-first
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class ToolMeta {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() builder;

  const ToolMeta({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}
