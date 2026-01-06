import 'package:flutter/material.dart';
import 'package:conversion_hub/state/app_state.dart';
import 'package:conversion_hub/tools/tools_list.dart';

enum ToolListMode { all, favorites, recents }

class ToolsRegistryScreen extends StatefulWidget {
  final ToolListMode mode;
  const ToolsRegistryScreen({super.key, required this.mode});

  @override
  State<ToolsRegistryScreen> createState() => _ToolsRegistryScreenState();
}

class _ToolsRegistryScreenState extends State<ToolsRegistryScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    List<ToolDef> tools;
    switch (widget.mode) {
      case ToolListMode.all:
        tools = allTools;
        break;
      case ToolListMode.favorites:
        tools = allTools.where((t) => state.isFavorite(t.id)).toList();
        break;
      case ToolListMode.recents:
        final ids = state.recents.map((r) => r.toolId).toSet();
        tools = allTools.where((t) => ids.contains(t.id)).toList();
        tools.sort((a, b) {
          DateTime aAt = DateTime.fromMillisecondsSinceEpoch(0);
          DateTime bAt = DateTime.fromMillisecondsSinceEpoch(0);
          for (final r in state.recents) {
            if (r.toolId == a.id) aAt = r.at;
            if (r.toolId == b.id) bAt = r.at;
          }
          return bAt.compareTo(aAt);
        });
        break;
    }

    if (_q.trim().isNotEmpty) {
      final q = _q.trim().toLowerCase();
      tools = tools.where((t) {
        final hay = (t.title + ' ' + t.keywords.join(' ')).toLowerCase();
        return hay.contains(q);
      }).toList();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search tools',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 12),
        ...tools.map((t) => _ToolTile(tool: t)),
        if (tools.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text('No tools found.'),
          ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  final ToolDef tool;
  const _ToolTile({required this.tool});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final fav = state.isFavorite(tool.id);

    return Card(
      elevation: 0.5,
      child: ListTile(
        leading: Icon(tool.icon),
        title: Text(tool.title),
        trailing: IconButton(
          icon: Icon(fav ? Icons.star : Icons.star_border),
          onPressed: () => state.toggleFavorite(tool.id),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => tool.builder()),
        ),
      ),
    );
  }
}
