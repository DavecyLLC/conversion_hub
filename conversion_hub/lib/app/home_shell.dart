import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:conversion_hub/tools/tools_registry.dart';
import 'package:conversion_hub/tools/batch_converter.dart';
import 'package:conversion_hub/state/app_state.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    final pages = [
      ToolsRegistryScreen(mode: ToolListMode.all),
      ToolsRegistryScreen(mode: ToolListMode.favorites),
      ToolsRegistryScreen(mode: ToolListMode.recents),
      const BatchConverterScreen(),
    ];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismissKeyboard,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _index == 0
                ? 'Tools'
                : _index == 1
                    ? 'Favorites'
                    : _index == 2
                        ? 'Recents'
                        : 'Batch',
          ),
          actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => showModalBottomSheet(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => _SettingsSheet(state: state),
              ),
            ),
          ],
        ),
        body: pages[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.grid_view), label: 'All'),
            NavigationDestination(icon: Icon(Icons.star_outline), label: 'Fav'),
            NavigationDestination(icon: Icon(Icons.history), label: 'Recent'),
            NavigationDestination(icon: Icon(Icons.view_list), label: 'Batch'),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  final AppState state;
  const _SettingsSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state.settings;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: s.defaultLengthUnit,
            decoration: const InputDecoration(
              labelText: 'Default length unit',
            ),
            items: const [
              DropdownMenuItem(value: 'mm', child: Text('mm')),
              DropdownMenuItem(value: 'cm', child: Text('cm')),
              DropdownMenuItem(value: 'm', child: Text('m')),
              DropdownMenuItem(value: 'in', child: Text('in')),
              DropdownMenuItem(value: 'µm', child: Text('µm')),
            ],
            onChanged: (v) => state.updateSettings(s.copyWith(defaultLengthUnit: v!)),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<int>(
            value: s.decimals,
            decoration: const InputDecoration(
              labelText: 'Decimals',
            ),
            items: const [
              DropdownMenuItem(value: 2, child: Text('2')),
              DropdownMenuItem(value: 3, child: Text('3')),
              DropdownMenuItem(value: 4, child: Text('4')),
              DropdownMenuItem(value: 5, child: Text('5')),
              DropdownMenuItem(value: 6, child: Text('6')),
            ],
            onChanged: (v) => state.updateSettings(s.copyWith(decimals: v!)),
          ),
          const SizedBox(height: 12),

          SwitchListTile(
            value: s.haptics,
            onChanged: (v) => state.updateSettings(s.copyWith(haptics: v)),
            title: const Text('Haptics'),
          ),

          SwitchListTile(
            value: s.scientific,
            onChanged: (v) => state.updateSettings(s.copyWith(scientific: v)),
            title: const Text('Scientific formatting (future use)'),
          ),

          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: Text(s.privacyPolicyUrl),
            onTap: () async {
              final uri = Uri.parse(s.privacyPolicyUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),

          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
