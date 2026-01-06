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

class BendingTorsionToolScreen extends StatefulWidget {
  const BendingTorsionToolScreen({super.key});

  @override
  State<BendingTorsionToolScreen> createState() => _BendingTorsionToolScreenState();
}

class _BendingTorsionToolScreenState extends State<BendingTorsionToolScreen> {
  // Beam (cantilever end load)
  final pCtrl = TextEditingController(); // N
  final lCtrl = TextEditingController(); // mm
  final bCtrl = TextEditingController(); // mm
  final hCtrl = TextEditingController(); // mm
  final eCtrl = TextEditingController(); // GPa

  // Torsion (solid circular shaft)
  final tCtrl = TextEditingController(); // N·mm
  final dCtrl = TextEditingController(); // mm
  final gCtrl = TextEditingController(); // GPa
  final ltCtrl = TextEditingController(); // mm (shaft length)

  @override
  void dispose() {
    pCtrl.dispose();
    lCtrl.dispose();
    bCtrl.dispose();
    hCtrl.dispose();
    eCtrl.dispose();
    tCtrl.dispose();
    dCtrl.dispose();
    gCtrl.dispose();
    ltCtrl.dispose();
    super.dispose();
  }

  double? _d(TextEditingController c) => double.tryParse(c.text.trim());

  Out? _compute() {
    // Beam: cantilever end load
    final P = _d(pCtrl);
    final L = _d(lCtrl);
    final b = _d(bCtrl);
    final h = _d(hCtrl);
    final E = _d(eCtrl);

    double? sigmaMpa;
    double? deflMm;

    final steps = <String>[
      'Cantilever end-load: Mmax = P·L',
      'Rectangular I = b·h³/12',
      'Bending stress: σ = M·c/I (c=h/2)',
      'Tip deflection: δ = P·L³/(3·E·I)',
    ];

    if (P != null && L != null && b != null && h != null && b > 0 && h > 0) {
      final M = P * L; // N·mm
      final I = b * math.pow(h, 3) / 12.0; // mm^4
      final c = h / 2.0; // mm
      sigmaMpa = (M * c) / I; // (N·mm * mm / mm^4) = N/mm^2 = MPa

      if (E != null && E > 0) {
        final E_mpa = E * 1000.0; // GPa -> kN/mm^2? Actually 1 GPa = 1000 MPa
        deflMm = (P * math.pow(L, 3)) / (3.0 * E_mpa * I);
      }
    }

    // Torsion: solid circular shaft
    final T = _d(tCtrl);
    final D = _d(dCtrl);
    final G = _d(gCtrl);
    final Lt = _d(ltCtrl);

    double? tauMpa;
    double? twistRad;
    double? twistDeg;

    if (T != null && D != null && D > 0) {
      final J = math.pi * math.pow(D, 4) / 32.0; // mm^4
      final r = D / 2.0;
      tauMpa = (T * r) / J; // N/mm^2 = MPa

      if (G != null && G > 0 && Lt != null && Lt > 0) {
        final G_mpa = G * 1000.0;
        twistRad = (T * Lt) / (G_mpa * J);
        twistDeg = twistRad * 180.0 / math.pi;
      }
    }

    return Out(
      sigmaMpa: sigmaMpa,
      deflMm: deflMm,
      tauMpa: tauMpa,
      twistDeg: twistDeg,
      steps: steps,
    );
  }

  Future<void> _copyAll(AppState state, Out out) async {
    final d = state.settings.decimals;
    final text = [
      'Bending & Torsion',
      'Bending σ (MPa): ${out.sigmaMpa == null ? '—' : fmt(out.sigmaMpa!, d)}',
      'Tip deflection δ (mm): ${out.deflMm == null ? '—' : fmt(out.deflMm!, d)}',
      'Torsion τ (MPa): ${out.tauMpa == null ? '—' : fmt(out.tauMpa!, d)}',
      'Twist θ (deg): ${out.twistDeg == null ? '—' : fmt(out.twistDeg!, d)}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    state.addRecent(
      HistoryItem(
        toolId: 'bending_torsion',
        at: DateTime.now(),
        summary: 'σ=${out.sigmaMpa == null ? '—' : fmt(out.sigmaMpa!, d)} MPa',
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
      appBar: AppBar(title: const Text('Bending & Torsion')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Beam (Cantilever End Load)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('Units: N, mm, E in GPa'),
                const SizedBox(height: 10),
                TextField(
                  controller: pCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Load P (N)'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: lCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Length L (mm)'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: bCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Width b (mm)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: hCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Height h (mm)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: eCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Young’s Modulus E (GPa)'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                const Divider(),
                Text('Torsion (Solid Circular Shaft)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('Units: T in N·mm, D in mm, G in GPa'),
                const SizedBox(height: 10),
                TextField(
                  controller: tCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Torque T (N·mm)'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Diameter D (mm)'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: gCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Shear Modulus G (GPa)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: ltCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Shaft length L (mm)'),
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
                ResultRow(label: 'Bending σ (MPa)', value: out?.sigmaMpa == null ? '—' : fmt(out!.sigmaMpa!, dec)),
                ResultRow(label: 'Tip deflection δ (mm)', value: out?.deflMm == null ? '—' : fmt(out!.deflMm!, dec)),
                ResultRow(label: 'Torsion τ (MPa)', value: out?.tauMpa == null ? '—' : fmt(out!.tauMpa!, dec)),
                ResultRow(label: 'Twist θ (deg)', value: out?.twistDeg == null ? '—' : fmt(out!.twistDeg!, dec)),
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

class Out {
  final double? sigmaMpa;
  final double? deflMm;
  final double? tauMpa;
  final double? twistDeg;
  final List<String> steps;

  Out({
    required this.sigmaMpa,
    required this.deflMm,
    required this.tauMpa,
    required this.twistDeg,
    required this.steps,
  });
}

