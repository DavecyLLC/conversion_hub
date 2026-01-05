import 'dart:math' as math;

class ParsedValue {
  final double value;
  final String? unit; // normalized (e.g. "mm", "in", "m")
  const ParsedValue(this.value, this.unit);
}

class UnitParser {
  /// Canonical length units -> meters factor
  static const Map<String, double> _toMeters = {
    'µm': 1e-6,
    'mm': 1e-3,
    'cm': 1e-2,
    'm': 1.0,
    'in': 0.0254,
  };

  /// Unit aliases -> canonical units
  static const Map<String, String> _aliases = {
    // micron
    'um': 'µm',
    'micron': 'µm',
    'microns': 'µm',
    // mm
    'millimeter': 'mm',
    'millimeters': 'mm',
    // cm
    'centimeter': 'cm',
    'centimeters': 'cm',
    // m
    'meter': 'm',
    'meters': 'm',
    'metre': 'm',
    'metres': 'm',
    // in
    'inch': 'in',
    'inches': 'in',
    '"': 'in',
    '”': 'in',
    '″': 'in',
  };

  /// Unicode fractions often typed on iOS keyboards
  static const Map<String, double> _unicodeFractions = {
    '¼': 0.25,
    '½': 0.5,
    '¾': 0.75,
    '⅐': 1 / 7,
    '⅑': 1 / 9,
    '⅒': 0.1,
    '⅓': 1 / 3,
    '⅔': 2 / 3,
    '⅕': 0.2,
    '⅖': 0.4,
    '⅗': 0.6,
    '⅘': 0.8,
    '⅙': 1 / 6,
    '⅚': 5 / 6,
    '⅛': 0.125,
    '⅜': 0.375,
    '⅝': 0.625,
    '⅞': 0.875,
  };

  static List<String> supportedLengthUnits() => _toMeters.keys.toList(growable: false);

  /// Examples supported:
  /// "12.7mm", "0.5 in", "3/8 in", "1 3/8 in", "1e-3 m", "-25.4", "½ in"
  static ParsedValue? parse(String raw) {
    final s0 = raw.trim();
    if (s0.isEmpty) return null;

    // Normalize spacing and smart quotes
    final s = s0.replaceAll('“', '"').replaceAll('”', '"').replaceAll('′', "'").trim();

    // Split numeric part and unit part:
    // numeric may contain: digits, ., +/-, e/E, spaces (for mixed fraction), /, unicode fraction chars
    // unit may contain: letters, µ, "
    final match = RegExp(r'^\s*([+\-]?[0-9eE\.\s\/¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]+)\s*([a-zA-Zµ"″”]+)?\s*$')
        .firstMatch(s);
    if (match == null) return null;

    final numPart = (match.group(1) ?? '').trim();
    final unitRaw = (match.group(2) ?? '').trim();

    final value = _parseNumber(numPart);
    if (value == null || value.isNaN || value.isInfinite) return null;

    final unit = unitRaw.isEmpty ? null : _normalizeUnit(unitRaw);
    if (unitRaw.isNotEmpty && unit == null) return null; // unknown unit

    return ParsedValue(value, unit);
  }

  static String? _normalizeUnit(String u) {
    final key = u.trim().toLowerCase();
    final mapped = _aliases[key] ?? key;
    return _toMeters.containsKey(mapped) ? mapped : null;
  }

  static double? _parseNumber(String s) {
    if (s.isEmpty) return null;

    // Replace unicode fractions that appear alone (e.g. "½") or in mixed forms "1½"
    // Handle "1½" => "1 + 0.5"
    final replaced = _replaceUnicodeFractions(s);

    // Mixed fraction support: "1 3/8" or "1 + 3/8"
    final parts = replaced.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2 && parts.any((p) => p.contains('/'))) {
      double total = 0;
      for (final p in parts) {
        final v = _parseSimpleNumberOrFraction(p);
        if (v == null) return null;
        total += v;
      }
      return total;
    }

    return _parseSimpleNumberOrFraction(replaced.trim());
  }

  static double? _parseSimpleNumberOrFraction(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;

    if (t.contains('/')) {
      // fraction support "3/8" with optional sign on numerator
      final parts = t.split('/');
      if (parts.length != 2) return null;
      final a = double.tryParse(parts[0]);
      final b = double.tryParse(parts[1]);
      if (a == null || b == null || b == 0) return null;
      return a / b;
    }

    return double.tryParse(t);
  }

  static String _replaceUnicodeFractions(String s) {
    var out = s;
    // "1½" style
    for (final e in _unicodeFractions.entries) {
      out = out.replaceAllMapped(
        RegExp(r'(\d+)\s*' + RegExp.escape(e.key)),
        (m) => '${m.group(1)} ${e.value}',
      );
    }
    // standalone "½" style
    for (final e in _unicodeFractions.entries) {
      out = out.replaceAll(e.key, '${e.value}');
    }
    return out;
  }

  /// Convert length to another length unit (unit inferred or defaulted).
  static double? convertLength({
    required String input,
    required String defaultUnit,
    required String toUnit,
  }) {
    final pv = parse(input);
    if (pv == null) return null;

    final fromU = (pv.unit == null || pv.unit!.isEmpty) ? _normalizeUnit(defaultUnit) : pv.unit;
    final toU = _normalizeUnit(toUnit);
    if (fromU == null || toU == null) return null;

    final fFrom = _toMeters[fromU];
    final fTo = _toMeters[toU];
    if (fFrom == null || fTo == null) return null;

    final meters = pv.value * fFrom;
    return meters / fTo;
  }

  /// Convert input length string to meters.
  static double? lengthToMeters(String input, {required String defaultUnit}) {
    final pv = parse(input);
    if (pv == null) return null;

    final fromU = (pv.unit == null || pv.unit!.isEmpty) ? _normalizeUnit(defaultUnit) : pv.unit;
    if (fromU == null) return null;

    final f = _toMeters[fromU];
    if (f == null) return null;

    return pv.value * f;
  }

  static double metersToUnit(double meters, String unit) {
    final u = _normalizeUnit(unit) ?? unit;
    final f = _toMeters[u] ?? 1.0;
    return meters / f;
  }

  static double degToRad(double deg) => deg * math.pi / 180.0;
  static double radToDeg(double rad) => rad * 180.0 / math.pi;
}
