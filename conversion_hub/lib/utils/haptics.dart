import 'package:flutter/services.dart';

DateTime? _lastHaptic;

/// Lightweight haptic feedback helper.
///
/// - Respects user setting
/// - Debounced to avoid buzzing on rapid taps
/// - Safe on all platforms
Future<void> tapHaptic(
  bool enabled, {
  Duration debounce = const Duration(milliseconds: 60),
}) async {
  if (!enabled) return;

  final now = DateTime.now();
  if (_lastHaptic != null && now.difference(_lastHaptic!) < debounce) return;
  _lastHaptic = now;

  await HapticFeedback.selectionClick();
}
