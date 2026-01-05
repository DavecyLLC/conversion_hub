import 'dart:math' as math;

/// Formats numbers for engineering-style display.
///
/// Features:
/// - trims trailing zeros by default
/// - optional scientific notation
/// - safe for very large / small values
/// - consistent rounding
String fmt(
  double v,
  int decimals, {
  bool trimZeros = true,
  bool scientific = false,
  double sciUpper = 1e6,
  double sciLower = 1e-4,
}) {
  if (v.isNaN || v.isInfinite) return '—';

  final abs = v.abs();

  // Auto scientific notation if requested or out of bounds
  if (scientific || (abs != 0 && (abs >= sciUpper || abs < sciLower))) {
    return _fmtSci(v, decimals);
  }

  final s = v.toStringAsFixed(decimals);
  return trimZeros ? _trimZeros(s) : s;
}

String _trimZeros(String s) {
  if (!s.contains('.')) return s;
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _fmtSci(double v, int decimals) {
  final exp = v == 0 ? 0 : (math.log(v.abs()) / math.ln10).floor();
  final mantissa = v / math.pow(10, exp);
  final m = mantissa.toStringAsFixed(decimals).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$m×10^$exp';
}
