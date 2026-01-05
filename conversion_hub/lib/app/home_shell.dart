import 'package:flutter/material.dart';
import 'package:conversion_hub/tools/tools_registry.dart';
import 'package:conversion_hub/tools/batch_converter.dart';
import 'package:conversion_hub/state/app_state.dart';
import 'package:conversion_hub/state/models.dart';
import 'package:url_launcher/url_launcher.dart';


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

  static const _privacyUrl =
      'https://davecyllc.github.io/conversion-hub-privacy/';

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

          // ───────────── Units ─────────────
          DropdownButtonFormField<String>(
            value: s.defaultLengthUnit,
            decoration: const InputDecoration(
              labelText: 'Default length unit',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'mm', child: Text('mm')),
              DropdownMenuItem(value: 'cm', child: Text('cm')),
              DropdownMenuItem(value: 'm', child: Text('m')),
              DropdownMenuItem(value: 'in', child: Text('in')),
              DropdownMenuItem(value: 'µm', child: Text('µm')),
            ],
            onChanged: (v) =>
                state.updateSettings(s.copyWith(defaultLengthUnit: v!)),
          ),
          const SizedBox(height: 12),

          // ───────────── Decimals ─────────────
          DropdownButtonFormField<int>(
            value: s.decimals,
            decoration: const InputDecoration(
              labelText: 'Decimals',
              border: OutlineInputBorder(),
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

          // ───────────── Haptics ─────────────
          SwitchListTile(
            value: s.haptics,
            onChanged: (v) => state.updateSettings(s.copyWith(haptics: v)),
            title: const Text('Haptics'),
          ),

          // ───────────── Theme ─────────────
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(s.themeMode.name),
            trailing: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.system,
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  label: Text('Dark'),
                ),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (set) =>
                  state.updateSettings(s.copyWith(themeMode: set.first)),
            ),
          ),

          const Divider(height: 32),

          // ───────────── Privacy Policy ─────────────
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('View privacy policy'),
            onTap: () async {
              final uri = Uri.parse('https://davecyllc.github.io/conversion-hub-privacy/');
              final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open Privacy Policy')),
                );
              }
            },
          ),

          const SizedBox(height: 8),

          // ───────────── Done ─────────────
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
