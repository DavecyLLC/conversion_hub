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

/// A minimal real FEA:
/// - 1D axial bar elements
/// - User sets: nodes (x positions), elements (node i->j, A, E), loads, fixed supports
/// - Solves K u = f for free DOFs
///
/// Units (recommended):
/// x in mm, A in mm^2, E in GPa, F in N
/// Internally uses MPa for stiffness: 1 GPa = 1000 MPa, and MPa = N/mm^2.

class AxialBarFeaToolScreen extends StatefulWidget {
  const AxialBarFeaToolScreen({super.key});

  @override
  State<AxialBarFeaToolScreen> createState() => _AxialBarFeaToolScreenState();
}

class _AxialBarFeaToolScreenState extends State<AxialBarFeaToolScreen> {
  // Simple default: 2 elements, 3 nodes
  final nodesCtrl = TextEditingController(text: '0, 50, 100'); // mm
  final areaCtrl = TextEditingController(text: '100'); // mm^2 (uniform)
  final eCtrl = TextEditingController(text: '200'); // GPa (steel)
  final loadsCtrl = TextEditingController(text: '0, 0, 1000'); // N nodal
  final fixedCtrl = TextEditingController(text: '0'); // fixed node indices (comma list)

  @override
  void dispose() {
    nodesCtrl.dispose();
    areaCtrl.dispose();
    eCtrl.dispose();
    loadsCtrl.dispose();
    fixedCtrl.dispose();
    super.dispose();
  }

  List<double>? _parseDoubles(String s) {
    final parts = s.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final out = <double>[];
    for (final p in parts) {
      final v = double.tryParse(p);
      if (v == null) return null;
      out.add(v);
    }
    return out;
  }

  List<int>? _parseInts(String s) {
    final parts = s.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    if (parts.isEmpty) return <int>[];
    final out = <int>[];
    for (final p in parts) {
      final v = int.tryParse(p);
      if (v == null) return null;
      out.add(v);
    }
    return out;
  }

  FeaOut? _compute() {
    final xs = _parseDoubles(nodesCtrl.text);
    if (xs == null || xs.length < 2) return null;

    final A = double.tryParse(areaCtrl.text.trim());
    final E = double.tryParse(eCtrl.text.trim());
    if (A == null || E == null || A <= 0 || E <= 0) return null;

    final loads = _parseDoubles(loadsCtrl.text);
    if (loads == null || loads.length != xs.length) return null;

    final fixed = _parseInts(fixedCtrl.text);
    if (fixed == null) return null;

    final n = xs.length;
    final K = List.generate(n, (_) => List<double>.filled(n, 0.0));
    final f = List<double>.from(loads);

    final E_mpa = E * 1000.0; // GPa -> MPa (N/mm^2)

    // Assemble stiffness (uniform A,E): element i = (i -> i+1)
    final steps = <String>[
      'Axial bar elements: k = A·E/L · [[1,-1],[-1,1]]',
      'Units: E(GPa)→MPa, A(mm²), L(mm), f(N) => u(mm)',
      'Solving K u = f with fixed supports removed',
    ];

    for (int i = 0; i < n - 1; i++) {
      final L = xs[i + 1] - xs[i];
      if (L <= 0) return null;

      final k = (A * E_mpa) / L; // N/mm

      // local -> global
      K[i][i] += k;
      K[i][i + 1] += -k;
      K[i + 1][i] += -k;
      K[i + 1][i + 1] += k;
    }

    // Apply boundary conditions by reducing system
    final fixedSet = fixed.toSet();
    for (final idx in fixedSet) {
      if (idx < 0 || idx >= n) return null;
    }

    final free = <int>[];
    for (int i = 0; i < n; i++) {
      if (!fixedSet.contains(i)) free.add(i);
    }
    if (free.isEmpty) return null;

    // Build reduced Kff and ff
    final Kff = List.generate(free.length, (_) => List<double>.filled(free.length, 0.0));
    final ff = List<double>.filled(free.length, 0.0);

    for (int i = 0; i < free.length; i++) {
      final gi = free[i];
      ff[i] = f[gi];

      for (int j = 0; j < free.length; j++) {
        final gj = free[j];
        Kff[i][j] = K[gi][gj];
      }
    }

    // Solve Kff * uf = ff (Gaussian elimination)
    final uf = _solveLinear(Kff, ff);
    if (uf == null) return null;

    final u = List<double>.filled(n, 0.0);
    for (int i = 0; i < free.length; i++) {
      u[free[i]] = uf[i];
    }

    // Element stress: sigma = E * strain ; strain = (u2-u1)/L
    final stresses = <double>[];
    for (int i = 0; i < n - 1; i++) {
      final L = xs[i + 1] - xs[i];
      final strain = (u[i + 1] - u[i]) / L;
      final sigmaMpa = E_mpa * strain;
      stresses.add(sigmaMpa);
    }

    // Report max displacement and max stress magnitude
    final umax = u.map((v) => v.abs()).reduce(math.max);
    final smax = stresses.map((v) => v.abs()).reduce(math.max);

    return FeaOut(
      u: u,
      stressesMpa: stresses,
      umax: umax,
      smax: smax,
      steps: steps,
    );
  }

  List<double>? _solveLinear(List<List<double>> A, List<double> b) {
    final n = b.length;
    // Augment
    final M = List.generate(n, (i) => [...A[i], b[i]]);

    for (int col = 0; col < n; col++) {
      // pivot
      int pivot = col;
      double best = M[col][col].abs();
      for (int r = col + 1; r < n; r++) {
        final v = M[r][col].abs();
        if (v > best) {
          best = v;
          pivot = r;
        }
      }
      if (best == 0) return null;

      if (pivot != col) {
        final tmp = M[col];
        M[col] = M[pivot];
        M[pivot] = tmp;
      }

      // normalize
      final diag = M[col][col];
      for (int c = col; c <= n; c++) {
        M[col][c] /= diag;
      }

      // eliminate
      for (int r = 0; r < n; r++) {
        if (r == col) continue;
        final factor = M[r][col];
        for (int c = col; c <= n; c++) {
          M[r][c] -= factor * M[col][c];
        }
      }
    }

    return List.generate(n, (i) => M[i][n]);
  }

  Future<void> _copyAll(AppState state, FeaOut out) async {
    final d = state.settings.decimals;
    final lines = <String>['FEA Lite: Axial Bar'];

    lines.add('Max |u| (mm): ${fmt(out.umax, d)}');
    lines.add('Max |σ| (MPa): ${fmt(out.smax, d)}');
    lines.add('');
    lines.add('Nodal displacements u (mm):');
    for (int i = 0; i < out.u.length; i++) {
      lines.add('u[$i] = ${fmt(out.u[i], d)}');
    }
    lines.add('');
    lines.add('Element stresses σ (MPa):');
    for (int e = 0; e < out.stressesMpa.length; e++) {
      lines.add('σ[e$e] = ${fmt(out.stressesMpa[e], d)}');
    }

    final text = lines.join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    state.addRecent(
      HistoryItem(
        toolId: 'fea_axial',
        at: DateTime.now(),
        summary: 'max|u|=${fmt(out.umax, d)} mm',
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
      appBar: AppBar(title: const Text('FEA Lite: Axial Bar (1D)')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Defaults are a simple 3-node bar. Keep units consistent (mm, N, GPa, mm²).'),
                const SizedBox(height: 12),
                TextField(
                  controller: nodesCtrl,
                  decoration: const InputDecoration(labelText: 'Node x positions (mm) e.g. 0,50,100'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: loadsCtrl,
                  decoration: const InputDecoration(labelText: 'Nodal loads f (N), same count as nodes'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fixedCtrl,
                  decoration: const InputDecoration(labelText: 'Fixed node indices e.g. 0'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: areaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Area A (mm²)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: eCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Young’s Modulus E (GPa)'),
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
                ResultRow(label: 'Max |u| (mm)', value: out == null ? '—' : fmt(out.umax, dec)),
                ResultRow(label: 'Max |σ| (MPa)', value: out == null ? '—' : fmt(out.smax, dec)),
                const SizedBox(height: 10),
                if (out != null) ...[
                  const Text('Nodal displacements u (mm):'),
                  const SizedBox(height: 6),
                  for (int i = 0; i < out.u.length; i++)
                    Text('u[$i] = ${fmt(out.u[i], dec)}'),
                  const SizedBox(height: 10),
                  const Text('Element stresses σ (MPa):'),
                  const SizedBox(height: 6),
                  for (int e = 0; e < out.stressesMpa.length; e++)
                    Text('σ[e$e] = ${fmt(out.stressesMpa[e], dec)}'),
                ],
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

class FeaOut {
  final List<double> u;
  final List<double> stressesMpa;
  final double umax;
  final double smax;
  final List<String> steps;

  FeaOut({
    required this.u,
    required this.stressesMpa,
    required this.umax,
    required this.smax,
    required this.steps,
  });
}

