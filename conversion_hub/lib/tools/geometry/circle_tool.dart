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

enum CircleKnown { diameter, radius, circumference }

class CircleTool extends StatefulWidget {
  const CircleTool({super.key});

  @override
  State<CircleTool> createState() => _CircleToolState();
}

class _CircleToolState extends State<CircleTool> {
  CircleKnown _known = CircleKnown.diameter;

  final TextEditingController _input = TextEditingController();
  String _unit = 'mm'; // user-selected display unit

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String _label() {
    switch (_known) {
      case CircleKnown.diameter:
        return 'Diameter (D)';
      case CircleKnown.radius:
        return 'Radius (R)';
      case CircleKnown.circumference:
        return 'Circumference (C)';
    }
  }

  /// Returns:
  /// - out: computed values in display unit
  /// - displayUnit: unit we should show next to results
  _CircleComputeResult? _compute(AppState state) {
    final raw = _input.text.trim();
    if (raw.isEmpty) return null;

    final defaultU = state.settings.defaultLengthUnit;

    // Try parse "12.7mm", "3/8 in", "25.4"
    final pv = UnitParser.parse(raw);
    if (pv == null) return null;

    // If the user typed a unit, use it for *display* (but don't mutate state here).
    final typedUnit = (pv.unit == null || pv.unit!.isEmpty) ? null : pv.unit!;
    final displayUnit = typedUnit ?? _unit;

    final v = UnitParser.convertLength(
      input: raw,
      defaultUnit: defaultU,
      toUnit: displayUnit,
    );
    if (v == null || v.isNaN || v.isInfinite || v < 0) return null;

    final pi = math.pi;
    late double d, r, c;

    switch (_known) {
      case CircleKnown.diameter:
        d = v;
        r = d / 2.0;
        c = pi * d;
        break;
      case CircleKnown.radius:
        r = v;
        d = 2.0 * r;
        c = 2.0 * pi * r;
        break;
      case CircleKnown.circumference:
        c = v;
        d = c / pi;
        r = d / 2.0;
        break;
    }

    final dec = state.settings.decimals;
    final steps = _buildSteps(
      known: _known,
      inputValue: v,
      unit: displayUnit,
      d: d,
      r: r,
      c: c,
      decimals: dec,
    );

    return _CircleComputeResult(
      out: CircleOut(d: d, r: r, c: c, steps: steps),
      displayUnit: displayUnit,
      typedUnit: typedUnit,
    );
  }

  List<String> _buildSteps({
    required CircleKnown known,
    required double inputValue,
    required String unit,
    required double d,
    required double r,
    required double c,
    required int decimals,
  }) {
    final f = (double x) => '${fmt(x, decimals)} $unit';
    final pi = math.pi;

    final lines = <String>[];

    // Given
    switch (known) {
      case CircleKnown.diameter:
        lines.add('Given: D = ${f(inputValue)}');
        lines.add('R = D / 2 = ${f(d)} / 2 = ${f(r)}');
        lines.add('C = πD = π × ${f(d)} = ${f(c)}');
        break;
      case CircleKnown.radius:
        lines.add('Given: R = ${f(inputValue)}');
        lines.add('D = 2R = 2 × ${f(r)} = ${f(d)}');
        lines.add('C = 2πR = 2π × ${f(r)} = ${f(c)}');
        break;
      case CircleKnown.circumference:
        lines.add('Given: C = ${f(inputValue)}');
        lines.add('D = C / π = ${f(c)} / π = ${f(d)}');
        lines.add('R = D / 2 = ${f(d)} / 2 = ${f(r)}');
        break;
    }

    // Formulas (compact)
    lines.add('');
    lines.add('Formulas:');
    lines.add('D = 2R');
    lines.add('C = πD');
    lines.add('C = 2πR');
    lines.add('π ≈ ${fmt(pi, decimals)}');

    return lines;
  }

  Future<void> _copyAll(AppState state, CircleOut out, String unit) async {
    final d = state.settings.decimals;
    final text = [
      'Circle Geometry',
      'R: ${fmt(out.r, d)} $unit',
      'D: ${fmt(out.d, d)} $unit',
      'C: ${fmt(out.c, d)} $unit',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));

    state.addRecent(
      HistoryItem(
        toolId: 'circle',
        at: DateTime.now(),
        summary: 'R=${fmt(out.r, d)} $unit, D=${fmt(out.d, d)} $unit',
        copyText: text,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  Future<void> _copyValue(AppState state, String text) async {
    await tapHaptic(state.settings.haptics);
    await Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final computed = _compute(state);
    final out = computed?.out;
    final dec = state.settings.decimals;

    // If the user typed a unit, adopt it into the UI *after* build (safe).
    // This keeps your dropdown aligned with what user typed.
    if (computed?.typedUnit != null && computed!.typedUnit != _unit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _unit = computed.typedUnit!);
      });
    }

    final unit = computed?.displayUnit ?? _unit;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Circle Geometry')),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter one value. Units supported: "12.7mm", "3/8 in", "25.4"'),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<CircleKnown>(
                    value: _known,
                    decoration: const InputDecoration(
                      labelText: 'I know',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: CircleKnown.diameter, child: Text('Diameter (D)')),
                      DropdownMenuItem(value: CircleKnown.radius, child: Text('Radius (R)')),
                      DropdownMenuItem(value: CircleKnown.circumference, child: Text('Circumference (C)')),
                    ],
                    onChanged: (v) => setState(() => _known = v!),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _input,
                          decoration: InputDecoration(
                            labelText: _label(),
                            border: const OutlineInputBorder(),
                            hintText: 'e.g. 12.7mm  |  3/8 in  |  25.4',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
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
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.content_paste),
                          label: const Text('Paste'),
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            setState(() => _input.text = (data?.text ?? '').trim());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                          onPressed: () => setState(() => _input.clear()),
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
                    label: 'Radius (R)',
                    value: out == null ? '—' : '${fmt(out.r, dec)} $unit',
                    onCopy: out == null ? null : () => _copyValue(state, '${fmt(out.r, dec)} $unit'),
                  ),
                  ResultRow(
                    label: 'Diameter (D)',
                    value: out == null ? '—' : '${fmt(out.d, dec)} $unit',
                    onCopy: out == null ? null : () => _copyValue(state, '${fmt(out.d, dec)} $unit'),
                  ),
                  ResultRow(
                    label: 'Circumference (C)',
                    value: out == null ? '—' : '${fmt(out.c, dec)} $unit',
                    onCopy: out == null ? null : () => _copyValue(state, '${fmt(out.c, dec)} $unit'),
                  ),

                  const SizedBox(height: 12),

                  FilledButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy All'),
                    onPressed: out == null ? null : () => _copyAll(state, out, unit),
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

class CircleOut {
  final double d;
  final double r;
  final double c;
  final List<String> steps;

  CircleOut({
    required this.d,
    required this.r,
    required this.c,
    required this.steps,
  });
}

class _CircleComputeResult {
  final CircleOut out;
  final String displayUnit;
  final String? typedUnit;

  _CircleComputeResult({
    required this.out,
    required this.displayUnit,
    required this.typedUnit,
  });
}
