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

class ThinLensTool extends StatefulWidget {
  const ThinLensTool({super.key});

  @override
  State<ThinLensTool> createState() => _ThinLensToolState();
}

class _ThinLensToolState extends State<ThinLensTool> {
  final fCtrl = TextEditingController();
  final doCtrl = TextEditingController();
  final diCtrl = TextEditingController();

  String _unit = 'mm'; // display unit

  @override
  void dispose() {
    fCtrl.dispose();
    doCtrl.dispose();
    diCtrl.dispose();
    super.dispose();
  }

  _ParsedLenM? _lenMeters(AppState state, TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;

    final defaultU = state.settings.defaultLengthUnit;
    final pv = UnitParser.parse(t);
    if (pv == null) return null;

    final typedUnit = (pv.unit == null || pv.unit!.isEmpty) ? null : pv.unit!;
    final meters = UnitParser.lengthToMeters(t, defaultUnit: defaultU);
    if (meters == null || meters.isNaN || meters.isInfinite) return null;

    return _ParsedLenM(meters: meters, typedUnit: typedUnit);
  }

  _ThinLensComputeResult _compute(AppState state) {
    final fM = _lenMeters(state, fCtrl);
    final doM = _lenMeters(state, doCtrl);
    final diM = _lenMeters(state, diCtrl);

    final typedUnit = fM?.typedUnit ?? doM?.typedUnit ?? diM?.typedUnit;
    final displayUnit = typedUnit ?? _unit;

    double? f = fM?.meters;
    double? doDist = doM?.meters;
    double? diDist = diM?.meters;

    final steps = <String>[];
    steps.add('Thin lens equation:  1/f = 1/do + 1/di');
    steps.add('Magnification:        m = −di/do');
    steps.add('');

    final known = [f, doDist, diDist].whereType<double>().length;

    if (known >= 2) {
      if (f == null && doDist != null && diDist != null) {
        final denom = (1 / doDist) + (1 / diDist);
        if (denom != 0) {
          f = 1 / denom;
          steps.add('Solve f:  f = 1 / (1/do + 1/di)');
        }
      } else if (doDist == null && f != null && diDist != null) {
        final rhs = (1 / f) - (1 / diDist);
        if (rhs != 0) {
          doDist = 1 / rhs;
          steps.add('Solve do: do = 1 / (1/f − 1/di)');
        }
      } else if (diDist == null && f != null && doDist != null) {
        final rhs = (1 / f) - (1 / doDist);
        if (rhs != 0) {
          diDist = 1 / rhs;
          steps.add('Solve di: di = 1 / (1/f − 1/do)');
        }
      }
    } else {
      steps.add('Enter any two values to solve the third.');
    }

    double? m;
    if (doDist != null && diDist != null && doDist != 0) {
      m = -diDist / doDist;
      steps.add('m = −di/do');
    }

    // Convert meters -> display unit
    final fDisp = f == null ? null : UnitParser.metersToUnit(f, displayUnit);
    final doDisp = doDist == null ? null : UnitParser.metersToUnit(doDist, displayUnit);
    final diDisp = diDist == null ? null : UnitParser.metersToUnit(diDist, displayUnit);

    return _ThinLensComputeResult(
      out: ThinLensOut(
        f: fDisp,
        doDist: doDisp,
        diDist: diDisp,
        mag: m,
        steps: steps,
      ),
      displayUnit: displayUnit,
      typedUnit: typedUnit,
    );
  }

  Future<void> _copyValue(AppState state, String text) async {
    await tapHaptic(state.settings.haptics);
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _copyAll(AppState state, ThinLensOut out, String unit) async {
    final d = state.settings.decimals;
    final text = [
      'Thin Lens',
      'f: ${out.f == null ? '—' : '${fmt(out.f!, d)} $unit'}',
      'do: ${out.doDist == null ? '—' : '${fmt(out.doDist!, d)} $unit'}',
      'di: ${out.diDist == null ? '—' : '${fmt(out.diDist!, d)} $unit'}',
      'm: ${out.mag == null ? '—' : fmt(out.mag!, d)}',
      'Formula: 1/f = 1/do + 1/di',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    state.addRecent(
      HistoryItem(
        toolId: 'thin_lens',
        at: DateTime.now(),
        summary: 'm=${out.mag == null ? '—' : fmt(out.mag!, d)}',
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
    final out = computed.out;
    final dec = state.settings.decimals;

    // Adopt typed unit into dropdown safely post-frame
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
        appBar: AppBar(title: const Text('Thin Lens')),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter any two values. Units supported ("mm", "cm", "m", "in").'),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _unit,
                    decoration: const InputDecoration(
                      labelText: 'Display unit',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'mm', child: Text('mm')),
                      DropdownMenuItem(value: 'cm', child: Text('cm')),
                      DropdownMenuItem(value: 'm', child: Text('m')),
                      DropdownMenuItem(value: 'in', child: Text('in')),
                    ],
                    onChanged: (v) => setState(() => _unit = v!),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: fCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Focal length (f)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. 50mm',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: doCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Object distance (do)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. 200mm',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: diCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Image distance (di)',
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
                          label: const Text('Paste f'),
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            setState(() => fCtrl.text = (data?.text ?? '').trim());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                          onPressed: () => setState(() {
                            fCtrl.clear();
                            doCtrl.clear();
                            diCtrl.clear();
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
                    label: 'f',
                    value: out.f == null ? '—' : '${fmt(out.f!, dec)} $unit',
                    onCopy: out.f == null ? null : () => _copyValue(state, '${fmt(out.f!, dec)} $unit'),
                  ),
                  ResultRow(
                    label: 'do',
                    value: out.doDist == null ? '—' : '${fmt(out.doDist!, dec)} $unit',
                    onCopy:
                        out.doDist == null ? null : () => _copyValue(state, '${fmt(out.doDist!, dec)} $unit'),
                  ),
                  ResultRow(
                    label: 'di',
                    value: out.diDist == null ? '—' : '${fmt(out.diDist!, dec)} $unit',
                    onCopy:
                        out.diDist == null ? null : () => _copyValue(state, '${fmt(out.diDist!, dec)} $unit'),
                  ),
                  ResultRow(
                    label: 'Magnification (m)',
                    value: out.mag == null ? '—' : fmt(out.mag!, dec),
                    onCopy: out.mag == null ? null : () => _copyValue(state, fmt(out.mag!, dec)),
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

class ThinLensOut {
  final double? f;
  final double? doDist;
  final double? diDist;
  final double? mag;
  final List<String> steps;

  ThinLensOut({
    required this.f,
    required this.doDist,
    required this.diDist,
    required this.mag,
    required this.steps,
  });
}

class _ParsedLenM {
  final double meters;
  final String? typedUnit;

  _ParsedLenM({
    required this.meters,
    required this.typedUnit,
  });
}

class _ThinLensComputeResult {
  final ThinLensOut out;
  final String displayUnit;
  final String? typedUnit;

  _ThinLensComputeResult({
    required this.out,
    required this.displayUnit,
    required this.typedUnit,
  });
}
