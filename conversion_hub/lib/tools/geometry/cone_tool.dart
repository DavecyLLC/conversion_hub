import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:conversion_hub/state/app_state.dart';
import 'package:conversion_hub/state/models.dart';
import 'package:conversion_hub/utils/unit_parser.dart';
import 'package:conversion_hub/utils/format.dart';
import 'package:conversion_hub/utils/haptics.dart';
import 'package:conversion_hub/widgets/card.dart';
import 'package:conversion_hub/widgets/result_row.dart';

import '../shared/steps_panel.dart';

enum ConeMode { cone, frustum }

class ConeToolScreen extends StatefulWidget {
  const ConeToolScreen({super.key});

  @override
  State<ConeToolScreen> createState() => _ConeToolScreenState();
}

class _ConeToolScreenState extends State<ConeToolScreen> {
  ConeMode _mode = ConeMode.cone;

  final r1Ctrl = TextEditingController(); // base radius
  final hCtrl = TextEditingController(); // height
  final r2Ctrl = TextEditingController(); // top radius (frustum only)

  String _unit = 'mm'; // display unit

  @override
  void dispose() {
    r1Ctrl.dispose();
    hCtrl.dispose();
    r2Ctrl.dispose();
    super.dispose();
  }

  _ParsedLen? _parseLen(AppState state, TextEditingController c, String displayUnit) {
    final t = c.text.trim();
    if (t.isEmpty) return null;

    final defaultU = state.settings.defaultLengthUnit;
    final pv = UnitParser.parse(t);
    if (pv == null) return null;

    final typedUnit = (pv.unit == null || pv.unit!.isEmpty) ? null : pv.unit!;
    final finalUnit = typedUnit ?? displayUnit;

    final v = UnitParser.convertLength(
      input: t,
      defaultUnit: defaultU,
      toUnit: finalUnit,
    );
    if (v == null || v.isNaN || v.isInfinite || v < 0) return null;

    return _ParsedLen(value: v, typedUnit: typedUnit, usedUnit: finalUnit);
  }

  _ConeComputeResult? _compute(AppState state) {
    // Decide display unit: typed unit wins, otherwise dropdown unit.
    // We'll parse with dropdown unit first, then update if typed unit exists.
    final displayUnitGuess = _unit;

    final r1P = _parseLen(state, r1Ctrl, displayUnitGuess);
    final hP = _parseLen(state, hCtrl, displayUnitGuess);
    final r2P = _mode == ConeMode.frustum ? _parseLen(state, r2Ctrl, displayUnitGuess) : null;

    // If nothing is entered yet, keep screen blank.
    if (r1P == null && hP == null && r2P == null) return null;

    final typedUnit = r1P?.typedUnit ?? hP?.typedUnit ?? r2P?.typedUnit;
    final unit = typedUnit ?? _unit;

    // Re-parse using final unit if needed (so all values match one unit)
    final r1 = _parseLen(state, r1Ctrl, unit)?.value;
    final h = _parseLen(state, hCtrl, unit)?.value;
    final r2 = _mode == ConeMode.frustum ? _parseLen(state, r2Ctrl, unit)?.value : null;

    if (r1 == null || h == null) {
      return _ConeComputeResult(
        out: null,
        displayUnit: unit,
        typedUnit: typedUnit,
      );
    }
    if (_mode == ConeMode.frustum && r2 == null) {
      return _ConeComputeResult(
        out: null,
        displayUnit: unit,
        typedUnit: typedUnit,
      );
    }

    final pi = math.pi;
    final steps = <String>[];
    steps.add('Units: $unit');
    steps.add(_mode == ConeMode.cone ? 'Mode: Cone' : 'Mode: Frustum');
    steps.add('');

    if (_mode == ConeMode.cone) {
      // Cone:
      // s = √(r² + h²)
      // V = (1/3)πr²h
      // A_l = πrs
      // A_t = πr(r + s)
      final s = math.sqrt(r1 * r1 + h * h);
      final v = (pi * r1 * r1 * h) / 3.0;
      final al = pi * r1 * s;
      final at = pi * r1 * (r1 + s);

      steps.add('Given: r = ${_fmtLen(state, r1)} $unit, h = ${_fmtLen(state, h)} $unit');
      steps.add('s = √(r² + h²)');
      steps.add('V = (1/3)πr²h');
      steps.add('Aₗ = πrs');
      steps.add('Aₜ = πr(r + s)');

      return _ConeComputeResult(
        out: ConeOut(
          slant: s,
          volume: v,
          lateralArea: al,
          totalArea: at,
          steps: steps,
        ),
        displayUnit: unit,
        typedUnit: typedUnit,
      );
    } else {
      final rr2 = r2!;
      // Frustum:
      // s = √((r1 − r2)² + h²)
      // V = (1/3)πh(r1² + r1r2 + r2²)
      // A_l = π(r1 + r2)s
      // A_t = A_l + πr1² + πr2²
      final s = math.sqrt((r1 - rr2) * (r1 - rr2) + h * h);
      final v = (pi * h * (r1 * r1 + r1 * rr2 + rr2 * rr2)) / 3.0;
      final al = pi * (r1 + rr2) * s;
      final at = al + pi * r1 * r1 + pi * rr2 * rr2;

      steps.add('Given: r1 = ${_fmtLen(state, r1)} $unit, r2 = ${_fmtLen(state, rr2)} $unit, h = ${_fmtLen(state, h)} $unit');
      steps.add('s = √((r1 − r2)² + h²)');
      steps.add('V = (1/3)πh(r1² + r1r2 + r2²)');
      steps.add('Aₗ = π(r1 + r2)s');
      steps.add('Aₜ = Aₗ + πr1² + πr2²');

      return _ConeComputeResult(
        out: ConeOut(
          slant: s,
          volume: v,
          lateralArea: al,
          totalArea: at,
          steps: steps,
        ),
        displayUnit: unit,
        typedUnit: typedUnit,
      );
    }
  }

  String _fmtLen(AppState state, double v) => fmt(v, state.settings.decimals);

  Future<void> _copyValue(AppState state, String text) async {
    await tapHaptic(state.settings.haptics);
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _copyAll(AppState state, ConeOut out, String unit) async {
    final d = state.settings.decimals;
    final u2 = '$unit²';
    final u3 = '$unit³';

    final text = [
      _mode == ConeMode.cone ? 'Cone' : 'Frustum',
      's: ${fmt(out.slant, d)} $unit',
      'V: ${fmt(out.volume, d)} $u3',
      'A_l: ${fmt(out.lateralArea, d)} $u2',
      'A_t: ${fmt(out.totalArea, d)} $u2',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    state.addRecent(
      HistoryItem(
        toolId: 'cone',
        at: DateTime.now(),
        summary: 'V=${fmt(out.volume, d)} $u3',
        copyText: text,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final computed = _compute(state);
    final out = computed?.out;
    final dec = state.settings.decimals;

    // If user typed a unit in any field, adopt it into dropdown safely post-frame
    final typedUnit = computed?.typedUnit;
    if (typedUnit != null && typedUnit != _unit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _unit = typedUnit);
      });
    }

    final unit = computed?.displayUnit ?? _unit;
    final u2 = '$unit²';
    final u3 = '$unit³';

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Cone / Frustum')),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Supports unit-aware input (µm/mm/cm/m/in).'),
                  const SizedBox(height: 12),

                  SegmentedButton<ConeMode>(
                    segments: const [
                      ButtonSegment(value: ConeMode.cone, label: Text('Cone')),
                      ButtonSegment(value: ConeMode.frustum, label: Text('Frustum')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _unit,
                    decoration: const InputDecoration(
                      labelText: 'Display unit',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'µm', child: Text('µm')),
                      DropdownMenuItem(value: 'mm', child: Text('mm')),
                      DropdownMenuItem(value: 'cm', child: Text('cm')),
                      DropdownMenuItem(value: 'm', child: Text('m')),
                      DropdownMenuItem(value: 'in', child: Text('in')),
                    ],
                    onChanged: (v) => setState(() => _unit = v!),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: r1Ctrl,
                    decoration: const InputDecoration(
                      labelText: 'Base radius r1',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. 10mm',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 10),

                  if (_mode == ConeMode.frustum) ...[
                    TextField(
                      controller: r2Ctrl,
                      decoration: const InputDecoration(
                        labelText: 'Top radius r2',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. 6mm',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                  ],

                  TextField(
                    controller: hCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Height h',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. 25mm',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.content_paste),
                          label: const Text('Paste r1'),
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            setState(() => r1Ctrl.text = (data?.text ?? '').trim());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                          onPressed: () => setState(() {
                            r1Ctrl.clear();
                            r2Ctrl.clear();
                            hCtrl.clear();
                          }),
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

                  ResultRow(
                    label: 'Slant (s)',
                    value: out == null ? '—' : '${fmt(out.slant, dec)} $unit',
                    onCopy: out == null ? null : () => _copyValue(state, '${fmt(out.slant, dec)} $unit'),
                  ),
                  ResultRow(
                    label: 'Volume (V)',
                    value: out == null ? '—' : '${fmt(out.volume, dec)} $u3',
                    onCopy: out == null ? null : () => _copyValue(state, '${fmt(out.volume, dec)} $u3'),
                  ),
                  ResultRow(
                    label: 'Lateral Area (Aₗ)',
                    value: out == null ? '—' : '${fmt(out.lateralArea, dec)} $u2',
                    onCopy: out == null ? null : () => _copyValue(state, '${fmt(out.lateralArea, dec)} $u2'),
                  ),
                  ResultRow(
                    label: 'Total Area (Aₜ)',
                    value: out == null ? '—' : '${fmt(out.totalArea, dec)} $u2',
                    onCopy: out == null ? null : () => _copyValue(state, '${fmt(out.totalArea, dec)} $u2'),
                  ),

                  const SizedBox(height: 12),

                  FilledButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy All'),
                    onPressed: out == null
                        ? null
                        : () async {
                            await tapHaptic(state.settings.haptics);
                            await _copyAll(state, out, unit);
                          },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            if (out != null) AppCard(child: StepsPanel(lines: out.steps)),
          ],
        ),
      ),
    );
  }
}

class ConeOut {
  final double slant;
  final double volume;
  final double lateralArea;
  final double totalArea;
  final List<String> steps;

  ConeOut({
    required this.slant,
    required this.volume,
    required this.lateralArea,
    required this.totalArea,
    required this.steps,
  });
}

class _ParsedLen {
  final double value;
  final String? typedUnit;
  final String usedUnit;

  _ParsedLen({
    required this.value,
    required this.typedUnit,
    required this.usedUnit,
  });
}

class _ConeComputeResult {
  final ConeOut? out;
  final String displayUnit;
  final String? typedUnit;

  _ConeComputeResult({
    required this.out,
    required this.displayUnit,
    required this.typedUnit,
  });
}
