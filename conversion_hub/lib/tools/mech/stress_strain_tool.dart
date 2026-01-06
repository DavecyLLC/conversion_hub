import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:conversion_hub/state/app_state.dart';
import 'package:conversion_hub/state/models.dart';
import 'package:conversion_hub/utils/format.dart';
import 'package:conversion_hub/utils/haptics.dart';
import 'package:conversion_hub/widgets/card.dart';
import 'package:conversion_hub/widgets/result_row.dart';
import '../shared/steps_panel.dart';

class StressStrainToolScreen extends StatefulWidget {
  const StressStrainToolScreen({super.key});

  @override
  State<StressStrainToolScreen> createState() => _StressStrainToolScreenState();
}

class _StressStrainToolScreenState extends State<StressStrainToolScreen> {
  final forceCtrl = TextEditingController(); // N
  final areaCtrl = TextEditingController(); // mm^2
  final lengthCtrl = TextEditingController(); // mm
  final deltaCtrl = TextEditingController(); // mm
  final eCtrl = TextEditingController(); // GPa

  @override
  void dispose() {
    forceCtrl.dispose();
    areaCtrl.dispose();
    lengthCtrl.dispose();
    deltaCtrl.dispose();
    eCtrl.dispose();
    super.dispose();
  }

  double? _d(TextEditingController c) => double.tryParse(c.text.trim());

  Out? _compute() {
    final F = _d(forceCtrl); // N
    final A = _d(areaCtrl); // mm^2
    final L = _d(lengthCtrl); // mm
    final dL = _d(deltaCtrl); // mm
    final E = _d(eCtrl); // GPa

    // Stress: sigma = F / A. Convert mm^2 -> m^2? We'll keep MPa using N/mm^2 = MPa
    double? sigmaMpa;
    if (F != null && A != null && A > 0) sigmaMpa = F / A;

    // Strain: eps = dL / L
    double? eps;
    if (dL != null && L != null && L > 0) eps = dL / L;

    // Hooke: sigma = E * eps (E in GPa => MPa by *1000)
    double? sigmaFromEps;
    if (E != null && eps != null) sigmaFromEps = (E * 1000.0) * eps;

    double? epsFromSigma;
    if (E != null && sigmaMpa != null && E > 0) epsFromSigma = sigmaMpa / (E * 1000.0);

    final steps = <String>[
      'σ (MPa) = F(N) / A(mm²)  (since 1 N/mm² = 1 MPa)',
      'ε = ΔL / L',
      'Hooke: σ = E·ε (E in GPa → MPa by ×1000)',
    ];

    return Out(
      sigmaMpa: sigmaMpa,
      eps: eps,
      sigmaFromEps: sigmaFromEps,
      epsFromSigma: epsFromSigma,
      steps: steps,
    );
  }

  Future<void> _copyAll(AppState state, Out out) async {
    final d = state.settings.decimals;
    final text = [
      'Stress / Strain',
      'σ from F/A (MPa): ${out.sigmaMpa == null ? '—' : fmt(out.sigmaMpa!, d)}',
      'ε from ΔL/L: ${out.eps == null ? '—' : fmt(out.eps!, d)}',
      'σ from E·ε (MPa): ${out.sigmaFromEps == null ? '—' : fmt(out.sigmaFromEps!, d)}',
      'ε from σ/E: ${out.epsFromSigma == null ? '—' : fmt(out.epsFromSigma!, d)}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    state.addRecent(
      HistoryItem(
        toolId: 'stress_strain',
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
      appBar: AppBar(title: const Text('Stress / Strain')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Use consistent units: F in N, area in mm², length in mm, E in GPa.'),
                const SizedBox(height: 12),
                TextField(
                  controller: forceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Force F (N)'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: areaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Area A (mm²)'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: lengthCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Original length L (mm)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: deltaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Elongation ΔL (mm)'),
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
                ResultRow(label: 'σ = F/A (MPa)', value: out?.sigmaMpa == null ? '—' : fmt(out!.sigmaMpa!, dec)),
                ResultRow(label: 'ε = ΔL/L', value: out?.eps == null ? '—' : fmt(out!.eps!, dec)),
                ResultRow(label: 'σ = E·ε (MPa)', value: out?.sigmaFromEps == null ? '—' : fmt(out!.sigmaFromEps!, dec)),
                ResultRow(label: 'ε = σ/E', value: out?.epsFromSigma == null ? '—' : fmt(out!.epsFromSigma!, dec)),
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
  final double? eps;
  final double? sigmaFromEps;
  final double? epsFromSigma;
  final List<String> steps;

  Out({
    required this.sigmaMpa,
    required this.eps,
    required this.sigmaFromEps,
    required this.epsFromSigma,
    required this.steps,
  });
}

