import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:conversion_hub/state/app_state.dart';
import 'package:conversion_hub/utils/unit_parser.dart';
import 'package:conversion_hub/utils/format.dart';
import 'package:conversion_hub/widgets/card.dart';
import 'package:conversion_hub/utils/haptics.dart';

class BatchConverterScreen extends StatefulWidget {
  const BatchConverterScreen({super.key});

  @override
  State<BatchConverterScreen> createState() => _BatchConverterScreenState();
}

class _BatchConverterScreenState extends State<BatchConverterScreen> {
  final ctrl = TextEditingController();
  String _to = 'in';
  String _fromDefault = 'mm';

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  List<double?> _convertAll(AppState state) {
    final lines = ctrl.text.split(RegExp(r'\r?\n'));
    return lines.map((line) {
      final v = UnitParser.convertLength(
        input: line.trim(),
        defaultUnit: _fromDefault,
        toUnit: _to,
      );
      return v;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    _fromDefault = state.settings.defaultLengthUnit;

    final outs = _convertAll(state);
    final lines = ctrl.text.split(RegExp(r'\r?\n'));

    final outText = List.generate(lines.length, (i) {
      final v = outs[i];
      return v == null ? '' : fmt(v, state.settings.decimals);
    }).join('\n');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paste values (one per line). Units optional: "12.7mm", "3/8 in"'),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Input list',
                    border: OutlineInputBorder(),
                    hintText: '12.7mm\n25.4\n3/8 in',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _to,
                        decoration: const InputDecoration(
                          labelText: 'Convert to',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'µm', child: Text('µm')),
                          DropdownMenuItem(value: 'mm', child: Text('mm')),
                          DropdownMenuItem(value: 'cm', child: Text('cm')),
                          DropdownMenuItem(value: 'm', child: Text('m')),
                          DropdownMenuItem(value: 'in', child: Text('in')),
                        ],
                        onChanged: (v) => setState(() => _to = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.content_paste),
                      label: const Text('Paste'),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        setState(() => ctrl.text = (data?.text ?? '').trim());
                      },
                    )
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Output'),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Text(outText.isEmpty ? '—' : outText),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy output'),
                  onPressed: outText.trim().isEmpty
                      ? null
                      : () async {
                          await tapHaptic(state.settings.haptics);
                          await Clipboard.setData(ClipboardData(text: outText.trim()));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied output')),
                          );
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

