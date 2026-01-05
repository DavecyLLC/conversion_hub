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

class PythagorasToolScreen extends StatefulWidget {
  const PythagorasToolScreen({super.key});

  @override
  State<PythagorasToolScreen> createState() => _PythagorasToolScreenState();
}

class _PythagorasToolScreenState extends State<PythagorasToolScreen> {
  final aCtrl = TextEditingController();
  final bCtrl = TextEditingController();
  final cCtrl = TextEditingController();

  String _unit = 'mm'; // display unit

  @override
  void dispose() {
    aCtrl.dispose();
    bCtrl.dispose();
    cCtrl.dispose();
    super.dispose();
  }

  _ParsedLen? _parseLen(AppState state, TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;

    final defaultU = state.settings.defaultLengthUnit;
    final pv = UnitParser.parse(t);
    if (pv == null) return null;

    final typedUnit = (pv.unit == null || pv.unit!.isEmpty) ? null : pv.unit!;
    final displayUnit = typedUnit ?? _unit;

    final v = UnitParser.convertLength(
      input: t,
      defaultUnit: defaultU,
      toUnit: displayUnit,
    );
    if (v == null || v.isNaN || v.isInfinite || v < 0) return null;

    return _ParsedLen(value: v, displayUnit: displayUnit, typedUnit: typedUnit);
  }

  _PythComputeResult _compute(AppState state) {
    final aP = _parseLen(state, aCtrl);
    final bP = _parseLen(state, bCtrl);
    final cP = _parseLen(state, cCtrl);

    // Decide the unit to display:
    // prefer any typed unit, otherwise use current dropdown unit.
    final typedUnit = aP?.typedUnit ?? bP?.typedUnit ?? cP?.typedUnit;
    final unit = typedUnit ?? _unit;

    double? a = aP?.value;
    double? b = bP?.value;
    double? c = cP?.value;

    final knownCount = [a, b, c].whereType<double>().length;
    final steps = <String>[];

    steps.add('Formula: a² + b² = c²');
    steps.add('Units: $unit');

    if (knownCount < 2) {
      return _PythComputeResult(
        out: PythOut(a: a, b: b, c: c, angleA: null, angleB: null, steps: steps),
        displayUnit: unit,
        typedUnit: typedUnit,
      );
    }

    // Solve missing side (if possible)
    if (c == null && a != null && b != null) {
      c = math.sqrt(a * a + b * b);
      steps.add('');
      steps.add('Solve c:  c = √(a² + b²)');
    } else if (a == null && b != null && c != null) {
      final v = c * c - b * b;
      a = v >= 0 ? math.sqrt(v) : null;
      steps.add('');
      steps.add('Solve a:  a = √(c² − b²)');
    } else if (b == null && a != null && c != null) {
      final v = c * c - a * a;
      b = v >= 0 ? math.sqrt(v) : null;
      steps.add('');
      steps.add('Solve b:  b = √(c² − a²)');
    }

    // Angles (degrees) — stable using atan2
    double? angleA;
    double? angleB;
    if (a != null && b != null && c != null && c > 0) {
      // angle opposite side a
      angleA = UnitParser.radToDeg(math.atan2(a, b));
      // angle opposite side b
      angleB = UnitParser.radToDeg(math.atan2(b, a));
      steps.add('');
      steps.add('Angles:');
      steps.add('A = atan2(a, b)');
      steps.add('B = atan2(b, a)');
      steps.add('A + B = 90° (right triangle)');
    }

    final out = PythOut(a: a, b: b, c: c, angleA: angleA, angleB: angleB, steps: steps);

    return _PythComputeResult(
      out: out,
      displayUnit: unit,
      typedUnit: typedUnit,
    );
  }

  Future<void> _copyAll(AppState state, PythOut out, String unit) async {
    final d = state.settings.decimals;

    final text = [
      'Right Triangle (Pythagoras)',
      'a: ${out.a == null ? '—' : '${fmt(out.a!, d)} $unit'}',
      'b: ${out.b == null ? '—' : '${fmt(out.b!, d)} $unit'}',
      'c: ${out.c == null ? '—' : '${fmt(out.c!, d)} $unit'}',
      'A: ${out.angleA == null ? '—' : '${fmt(out.angleA!, d)}°'}',
      'B: ${out.angleB == null ? '—' : '${fmt(out.angleB!, d)}°'}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));

    state.addRecent(
      HistoryItem(
        toolId: 'pythagoras',
        at: DateTime.now(),
        summary:
            'a=${out.a == null ? '—' : fmt(out.a!, d)} $unit, c=${out.c == null ? '—' : fmt(out.c!, d)} $unit',
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
    final out = computed.out;
    final dec = state.settings.decimals;

    // Adopt typed unit into the dropdown safely (post-frame)
    if (computed.typedUnit != null && computed.typedUnit != _unit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _unit = computed.typedUnit!);
      });
    }

    final unit = computed.displayUnit;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Right Triangle Solver')),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter any two of a, b, c. Units supported: "12.7mm", "3/8 in"'),
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
                    controller: aCtrl,
                    decoration: const InputDecoration(
                      labelText: 'a (leg)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. 12.7mm',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bCtrl,
                    decoration: const InputDecoration(
                      labelText: 'b (leg)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. 3/8 in',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cCtrl,
                    decoration: const InputDecoration(
                      labelText: 'c (hypotenuse)',
                      border: OutlineInputBorder(),
                      hintText: 'leave blank to solve',
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
                          label: const Text('Paste a'),
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            setState(() => aCtrl.text = (data?.text ?? '').trim());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                          onPressed: () => setState(() {
                            aCtrl.clear();
                            bCtrl.clear();
                            cCtrl.clear();
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
                    label: 'a',
                    value: out.a == null ? '—' : '${fmt(out.a!, dec)} $unit',
                    onCopy: out.a == null ? null : () => _copyValue(state, '${fmt(out.a!, dec)} $unit'),
                  ),
                  ResultRow(
                    label: 'b',
                    value: out.b == null ? '—' : '${fmt(out.b!, dec)} $unit',
                    onCopy: out.b == null ? null : () => _copyValue(state, '${fmt(out.b!, dec)} $unit'),
                  ),
                  ResultRow(
                    label: 'c',
                    value: out.c == null ? '—' : '${fmt(out.c!, dec)} $unit',
                    onCopy: out.c == null ? null : () => _copyValue(state, '${fmt(out.c!, dec)} $unit'),
                  ),
                  ResultRow(
                    label: 'Angle A',
                    value: out.angleA == null ? '—' : '${fmt(out.angleA!, dec)}°',
                    onCopy: out.angleA == null ? null : () => _copyValue(state, '${fmt(out.angleA!, dec)}°'),
                  ),
                  ResultRow(
                    label: 'Angle B',
                    value: out.angleB == null ? '—' : '${fmt(out.angleB!, dec)}°',
                    onCopy: out.angleB == null ? null : () => _copyValue(state, '${fmt(out.angleB!, dec)}°'),
                  ),

                  const SizedBox(height: 12),

                  FilledButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy All'),
                    onPressed: () async {
                      await tapHaptic(state.settings.haptics);
                      await _copyAll(state, out, unit);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            AppCard(child: StepsPanel(lines: out.steps)),
          ],
        ),
      ),
    );
  }
}

class PythOut {
  final double? a;
  final double? b;
  final double? c;
  final double? angleA;
  final double? angleB;
  final List<String> steps;

  PythOut({
    required this.a,
    required this.b,
    required this.c,
    required this.angleA,
    required this.angleB,
    required this.steps,
  });
}

class _ParsedLen {
  final double value;
  final String displayUnit;
  final String? typedUnit;

  _ParsedLen({
    required this.value,
    required this.displayUnit,
    required this.typedUnit,
  });
}

class _PythComputeResult {
  final PythOut out;
  final String displayUnit;
  final String? typedUnit;

  _PythComputeResult({
    required this.out,
    required this.displayUnit,
    required this.typedUnit,
  });
}
