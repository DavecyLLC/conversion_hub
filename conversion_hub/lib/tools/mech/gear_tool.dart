import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:conversion_hub/state/app_state.dart';
import 'package:conversion_hub/state/models.dart';
import 'package:conversion_hub/utils/format.dart';
import 'package:conversion_hub/utils/haptics.dart';
import 'package:conversion_hub/widgets/card.dart';
import 'package:conversion_hub/widgets/result_row.dart';
import '../shared/steps_panel.dart';

class GearToolScreen extends StatefulWidget {
  const GearToolScreen({super.key});

  @override
  State<GearToolScreen> createState() => _GearToolScreenState();
}

class _GearToolScreenState extends State<GearToolScreen> {
  final z1Ctrl = TextEditingController(); // driver teeth
  final z2Ctrl = TextEditingController(); // driven teeth
  final n1Ctrl = TextEditingController(); // driver rpm
  final t1Ctrl = TextEditingController(); // driver torque

  final moduleCtrl = TextEditingController(); // mm module (optional)
  final dpCtrl = TextEditingController(); // diametral pitch (optional)

  @override
  void dispose() {
    z1Ctrl.dispose();
    z2Ctrl.dispose();
    n1Ctrl.dispose();
    t1Ctrl.dispose();
    moduleCtrl.dispose();
    dpCtrl.dispose();
    super.dispose();
  }

  double? _d(TextEditingController c) => double.tryParse(c.text.trim());
  int? _i(TextEditingController c) => int.tryParse(c.text.trim());

  GearOut? _compute() {
    final z1 = _i(z1Ctrl);
    final z2 = _i(z2Ctrl);
    if (z1 == null || z2 == null || z1 <= 0 || z2 <= 0) return null;

    final ratio = z2 / z1; // speed reduction ratio (driven/driver)

    final n1 = _d(n1Ctrl);
    final n2 = (n1 == null) ? null : n1 / ratio;

    final t1 = _d(t1Ctrl);
    final t2 = (t1 == null) ? null : t1 * ratio;

    // geometry helpers
    final m = _d(moduleCtrl); // mm
    final dp = _d(dpCtrl); // teeth per inch

    double? d1mm;
    double? d2mm;
    double? centerMm;

    final steps = <String>[
      'Gear ratio (reduction) = Z2 / Z1',
      'Speed: N2 = N1 / ratio',
      'Torque: T2 ≈ T1 * ratio (ideal, no losses)',
    ];

    if (m != null && m > 0) {
      d1mm = m * z1;
      d2mm = m * z2;
      centerMm = (d1mm + d2mm) / 2.0;
      steps.add('Module mode (mm): d = m·Z, center = (d1+d2)/2');
    } else if (dp != null && dp > 0) {
      // dp uses inches: d_in = Z / DP. Convert to mm for display.
      final d1in = z1 / dp;
      final d2in = z2 / dp;
      d1mm = d1in * 25.4;
      d2mm = d2in * 25.4;
      centerMm = (d1mm + d2mm) / 2.0;
      steps.add('DP mode: d_in = Z/DP → mm, center=(d1+d2)/2');
    }

    return GearOut(
      z1: z1,
      z2: z2,
      ratio: ratio,
      n2: n2,
      t2: t2,
      d1mm: d1mm,
      d2mm: d2mm,
      centerMm: centerMm,
      steps: steps,
    );
  }

  Future<void> _copyAll(AppState state, GearOut out) async {
    final d = state.settings.decimals;
    final text = [
      'Gears',
      'Z1: ${out.z1}',
      'Z2: ${out.z2}',
      'Ratio (Z2/Z1): ${fmt(out.ratio, d)}',
      'Driven RPM (N2): ${out.n2 == null ? '—' : fmt(out.n2!, d)}',
      'Driven Torque (T2): ${out.t2 == null ? '—' : fmt(out.t2!, d)}',
      'Pitch dia d1 (mm): ${out.d1mm == null ? '—' : fmt(out.d1mm!, d)}',
      'Pitch dia d2 (mm): ${out.d2mm == null ? '—' : fmt(out.d2mm!, d)}',
      'Center dist (mm): ${out.centerMm == null ? '—' : fmt(out.centerMm!, d)}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    state.addRecent(
      HistoryItem(
        toolId: 'gears',
        at: DateTime.now(),
        summary: 'Ratio=${fmt(out.ratio, d)}',
        copyText: text,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final out = _compute();
    final dec = state.settings.decimals;

    return Scaffold(
      appBar: AppBar(title: const Text('Gears: Driver / Driven')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter teeth counts. RPM/Torque optional. Module or DP optional for geometry.'),
                const SizedBox(height: 12),
                TextField(
                  controller: z1Ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Driver teeth (Z1)'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: z2Ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Driven teeth (Z2)'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: n1Ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Driver RPM (N1)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: t1Ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Driver torque (T1)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: moduleCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Module m (mm, optional)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: dpCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Diametral Pitch DP (optional)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
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
                const Text('Results'),
                const SizedBox(height: 10),
                ResultRow(label: 'Ratio (Z2/Z1)', value: out == null ? '—' : fmt(out.ratio, dec)),
                ResultRow(label: 'Driven RPM (N2)', value: out?.n2 == null ? '—' : fmt(out!.n2!, dec)),
                ResultRow(label: 'Driven Torque (T2)', value: out?.t2 == null ? '—' : fmt(out!.t2!, dec)),
                ResultRow(label: 'Pitch dia d1 (mm)', value: out?.d1mm == null ? '—' : fmt(out!.d1mm!, dec)),
                ResultRow(label: 'Pitch dia d2 (mm)', value: out?.d2mm == null ? '—' : fmt(out!.d2mm!, dec)),
                ResultRow(label: 'Center dist (mm)', value: out?.centerMm == null ? '—' : fmt(out!.centerMm!, dec)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy All'),
                  onPressed: out == null
                      ? null
                      : () async {
                          await tapHaptic(state.settings.haptics);
                          await _copyAll(state, out);
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (out != null) AppCard(child: StepsPanel(lines: out.steps)),
        ],
      ),
    );
  }
}

class GearOut {
  final int z1;
  final int z2;
  final double ratio;
  final double? n2;
  final double? t2;
  final double? d1mm;
  final double? d2mm;
  final double? centerMm;
  final List<String> steps;

  GearOut({
    required this.z1,
    required this.z2,
    required this.ratio,
    required this.n2,
    required this.t2,
    required this.d1mm,
    required this.d2mm,
    required this.centerMm,
    required this.steps,
  });
}

