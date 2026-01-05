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

class FovTool extends StatefulWidget {
  const FovTool({super.key});

  @override
  State<FovTool> createState() => _FovToolState();
}

class _FovToolState extends State<FovTool> {
  final focalCtrl = TextEditingController(); // focal length
  final widthCtrl = TextEditingController();
  final heightCtrl = TextEditingController();

  String _sensorPreset = 'Custom';
  String _displayUnit = 'mm'; // for showing sensor dims (inputs accepted in any unit)

  static const presets = <String, (double wMm, double hMm)>{
    'Custom': (0, 0),
    'Full Frame (36×24)': (36, 24),
    'APS-C (23.6×15.7)': (23.6, 15.7),
    '1" (13.2×8.8)': (13.2, 8.8),
    'Micro 4/3 (17.3×13.0)': (17.3, 13.0),
  };

  @override
  void dispose() {
    focalCtrl.dispose();
    widthCtrl.dispose();
    heightCtrl.dispose();
    super.dispose();
  }

  _ParsedLenMm? _lenMm(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;

    // For optics we keep base unit mm.
    const defaultU = 'mm';
    final pv = UnitParser.parse(t);
    if (pv == null) return null;

    final typedUnit = (pv.unit == null || pv.unit!.isEmpty) ? null : pv.unit!;
    final vmm = UnitParser.convertLength(input: t, defaultUnit: defaultU, toUnit: 'mm');
    if (vmm == null || vmm.isNaN || vmm.isInfinite || vmm <= 0) return null;

    return _ParsedLenMm(mm: vmm, typedUnit: typedUnit);
  }

  _FovComputeResult _compute(AppState state) {
    final f = _lenMm(focalCtrl);
    if (f == null) {
      return _FovComputeResult(out: null, typedUnit: null);
    }

    double? wMm;
    double? hMm;
    String? typedUnit = f.typedUnit;

    if (_sensorPreset != 'Custom') {
      final p = presets[_sensorPreset]!;
      wMm = p.$1;
      hMm = p.$2;
    } else {
      final w = _lenMm(widthCtrl);
      final h = _lenMm(heightCtrl);
      if (w == null || h == null) return _FovComputeResult(out: null, typedUnit: typedUnit);
      wMm = w.mm;
      hMm = h.mm;
      typedUnit ??= w.typedUnit ?? h.typedUnit;
    }

    final fMm = f.mm;

    // FOV formula: 2 * atan(sensor_dim / (2*f))
    final hRad = 2 * math.atan(wMm / (2 * fMm));
    final vRad = 2 * math.atan(hMm / (2 * fMm));
    final dMm = math.sqrt(wMm * wMm + hMm * hMm);
    final dRad = 2 * math.atan(dMm / (2 * fMm));

    final hDeg = UnitParser.radToDeg(hRad);
    final vDeg = UnitParser.radToDeg(vRad);
    final dDeg = UnitParser.radToDeg(dRad);

    // Extra: 35mm-equivalent focal length when using presets (based on diagonal crop factor)
    double? fEqMm;
    if (_sensorPreset != 'Custom') {
      final ffDiag = math.sqrt(36 * 36 + 24 * 24);
      final sensorDiag = dMm;
      if (sensorDiag > 0) {
        final crop = ffDiag / sensorDiag;
        fEqMm = fMm * crop;
      }
    }

    final steps = <String>[
      'Internal units: mm',
      'Formula: FOV = 2·atan(sensor / (2·f))',
      'Horizontal uses width, Vertical uses height, Diagonal uses √(w²+h²)',
      'h(rad) = ${hRad.toStringAsPrecision(6)}',
      'v(rad) = ${vRad.toStringAsPrecision(6)}',
      'd(rad) = ${dRad.toStringAsPrecision(6)}',
      if (fEqMm != null) '35mm-equivalent focal ≈ ${fEqMm.toStringAsPrecision(6)} mm',
    ];

    return _FovComputeResult(
      typedUnit: typedUnit,
      out: FovOut(
        focalMm: fMm,
        widthMm: wMm,
        heightMm: hMm,
        hDeg: hDeg,
        vDeg: vDeg,
        dDeg: dDeg,
        fEqMm: fEqMm,
        steps: steps,
      ),
    );
  }

  double _mmToDisplay(double mm, String u) {
    // UnitParser may already have helpers; keeping it explicit & stable here.
    switch (u) {
      case 'mm':
        return mm;
      case 'cm':
        return mm / 10.0;
      case 'm':
        return mm / 1000.0;
      case 'in':
        return mm / 25.4;
      default:
        return mm;
    }
  }

  String _unitLabel(String u) => u;

  Future<void> _copyValue(AppState state, String text) async {
    await tapHaptic(state.settings.haptics);
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _copyAll(AppState state, FovOut out) async {
    final d = state.settings.decimals;
    final text = [
      'FOV',
      'Preset: $_sensorPreset',
      'f: ${fmt(out.focalMm, d)} mm',
      'sensor: ${fmt(out.widthMm, d)}×${fmt(out.heightMm, d)} mm',
      'Horizontal: ${fmt(out.hDeg, d)}°',
      'Vertical: ${fmt(out.vDeg, d)}°',
      'Diagonal: ${fmt(out.dDeg, d)}°',
      if (out.fEqMm != null) '35mm-eq focal: ${fmt(out.fEqMm!, d)} mm',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    state.addRecent(
      HistoryItem(
        toolId: 'fov',
        at: DateTime.now(),
        summary: 'H=${fmt(out.hDeg, d)}°, V=${fmt(out.vDeg, d)}°',
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

    // If user typed a unit (e.g., "1 in"), adopt it for display post-frame (optional).
    // We don't force it—just sync if different.
    if (computed.typedUnit != null && computed.typedUnit != _displayUnit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _displayUnit = computed.typedUnit!);
      });
    }

    final sensorW = out == null ? null : _mmToDisplay(out.widthMm, _displayUnit);
    final sensorH = out == null ? null : _mmToDisplay(out.heightMm, _displayUnit);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Field of View (FOV)')),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FOV from sensor size and focal length. Inputs accept units (mm/cm/m/in).'),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _displayUnit,
                    decoration: const InputDecoration(
                      labelText: 'Display unit (sensor dims)',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'mm', child: Text('mm')),
                      DropdownMenuItem(value: 'cm', child: Text('cm')),
                      DropdownMenuItem(value: 'm', child: Text('m')),
                      DropdownMenuItem(value: 'in', child: Text('in')),
                    ],
                    onChanged: (v) => setState(() => _displayUnit = v!),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _sensorPreset,
                    decoration: const InputDecoration(
                      labelText: 'Sensor preset',
                      border: OutlineInputBorder(),
                    ),
                    items: presets.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                    onChanged: (v) => setState(() => _sensorPreset = v!),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: focalCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Focal length (f)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. 25mm  |  1in',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 10),

                  if (_sensorPreset == 'Custom') ...[
                    TextField(
                      controller: widthCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sensor width',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. 36mm',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: heightCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sensor height',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. 24mm',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                  ] else if (out != null) ...[
                    // Show preset dims in display unit for clarity
                    Text(
                      'Preset sensor: ${fmt(sensorW!, dec)}×${fmt(sensorH!, dec)} ${_unitLabel(_displayUnit)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.content_paste),
                          label: const Text('Paste f'),
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            setState(() => focalCtrl.text = (data?.text ?? '').trim());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                          onPressed: () => setState(() {
                            focalCtrl.clear();
                            widthCtrl.clear();
                            heightCtrl.clear();
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
                    label: 'Horizontal FOV',
                    value: out == null ? '—' : '${fmt(out.hDeg, dec)}°',
                    onCopy: out == null ? null : () => _copyValue(state, '${fmt(out.hDeg, dec)}°'),
                  ),
                  ResultRow(
                    label: 'Vertical FOV',
                    value: out == null ? '—' : '${fmt(out.vDeg, dec)}°',
                    onCopy: out == null ? null : () => _copyValue(state, '${fmt(out.vDeg, dec)}°'),
                  ),
                  ResultRow(
                    label: 'Diagonal FOV',
                    value: out == null ? '—' : '${fmt(out.dDeg, dec)}°',
                    onCopy: out == null ? null : () => _copyValue(state, '${fmt(out.dDeg, dec)}°'),
                  ),

                  if (out?.fEqMm != null) ...[
                    const SizedBox(height: 8),
                    ResultRow(
                      label: '35mm-eq focal (diag)',
                      value: '${fmt(out!.fEqMm!, dec)} mm',
                      onCopy: () => _copyValue(state, '${fmt(out.fEqMm!, dec)} mm'),
                    ),
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
      ),
    );
  }
}

class FovOut {
  final double focalMm;
  final double widthMm;
  final double heightMm;
  final double hDeg;
  final double vDeg;
  final double dDeg;
  final double? fEqMm;
  final List<String> steps;

  FovOut({
    required this.focalMm,
    required this.widthMm,
    required this.heightMm,
    required this.hDeg,
    required this.vDeg,
    required this.dDeg,
    required this.fEqMm,
    required this.steps,
  });
}

class _ParsedLenMm {
  final double mm;
  final String? typedUnit;

  _ParsedLenMm({required this.mm, required this.typedUnit});
}

class _FovComputeResult {
  final FovOut? out;
  final String? typedUnit;

  _FovComputeResult({required this.out, required this.typedUnit});
}
