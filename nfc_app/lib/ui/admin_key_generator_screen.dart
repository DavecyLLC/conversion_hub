import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../storage/admin_pin_store.dart';

class AdminKeyGeneratorScreen extends StatefulWidget {
  const AdminKeyGeneratorScreen({super.key});

  @override
  State<AdminKeyGeneratorScreen> createState() =>
      _AdminKeyGeneratorScreenState();
}

class _AdminKeyGeneratorScreenState extends State<AdminKeyGeneratorScreen> {
  final _pinStore = AdminPinStore();

  final _pinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _unlocked = false;
  String _status = "";
  String _currentPinHint = ""; // for display like "Default" vs "Custom"

  String? _generatedKey;

  static const _alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

  @override
  void initState() {
    super.initState();
    _loadPinHint();
  }

  Future<void> _loadPinHint() async {
    final pin = await _pinStore.getPin();
    final isDefault = pin == AdminPinStore.defaultPin;
    if (!mounted) return;
    setState(() {
      _currentPinHint = isDefault ? "Default PIN active" : "Custom PIN active";
    });
  }

  void _setStatus(String s) => setState(() => _status = s);

  String _makeKey() {
    final rnd = Random.secure();
    String block(int n) =>
        List.generate(n, (_) => _alphabet[rnd.nextInt(_alphabet.length)]).join();
    return "${block(4)}-${block(4)}-${block(4)}-${block(4)}-${block(4)}-${block(4)}-${block(4)}";
  }

  Future<void> _unlock() async {
    final entered = _pinController.text.trim();
    final actual = await _pinStore.getPin();

    if (entered == actual) {
      setState(() {
        _unlocked = true;
        _pinController.clear();
        _status = "Unlocked.";
      });
      await _loadPinHint();
    } else {
      _setStatus("Wrong PIN.");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wrong PIN")),
      );
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Copied to clipboard")),
    );
  }

  bool _isValidPin(String pin) {
    // Keep it simple and safe: 4–10 digits
    final p = pin.trim();
    if (p.length < 4 || p.length > 10) return false;
    final digitsOnly = RegExp(r'^\d+$');
    return digitsOnly.hasMatch(p);
  }

  Future<void> _changePin() async {
    final newPin = _newPinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (!_isValidPin(newPin)) {
      _setStatus("PIN must be 4–10 digits.");
      return;
    }
    if (newPin != confirm) {
      _setStatus("New PIN and confirm PIN do not match.");
      return;
    }

    await _pinStore.setPin(newPin);

    _newPinController.clear();
    _confirmPinController.clear();

    await _loadPinHint();
    _setStatus("✅ Admin PIN updated.");
  }

  Future<void> _resetPinToDefault() async {
    await _pinStore.resetToDefault();
    await _loadPinHint();
    _setStatus("✅ PIN reset to default (${AdminPinStore.defaultPin}).");
  }

  @override
  void dispose() {
    _pinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text("nfc_app — Admin")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Admin Access",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(_currentPinHint),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Enter Admin PIN (default ${AdminPinStore.defaultPin})",
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _unlock(),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _unlock,
                    child: const Text("Unlock"),
                  ),
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _status,
                      style: TextStyle(
                        color: _status.toLowerCase().contains("wrong")
                            ? Colors.red
                            : Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    final key = _generatedKey;
    final qrData = key == null ? null : "NFCAPPKEY:$key";

    return Scaffold(
      appBar: AppBar(
        title: const Text("nfc_app — Admin"),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _unlocked = false;
              _status = "";
              _generatedKey = null;
            }),
            child: const Text("Lock"),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- PIN Management ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Admin PIN",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(_currentPinHint),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "New PIN (4–10 digits)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _confirmPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Confirm new PIN",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _changePin,
                        icon: const Icon(Icons.lock_reset),
                        label: const Text("Change PIN"),
                      ),
                      OutlinedButton(
                        onPressed: _resetPinToDefault,
                        child: const Text("Reset to Default"),
                      ),
                    ],
                  ),
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_status),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // --- Key Generation ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Generate User Key",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _generatedKey = _makeKey()),
                    icon: const Icon(Icons.key),
                    label: const Text("Generate"),
                  ),
                  const SizedBox(height: 12),
                  if (key != null) ...[
                    SelectableText(
                      key,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _copy(key),
                          icon: const Icon(Icons.copy),
                          label: const Text("Copy Key"),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _copy(qrData!),
                          icon: const Icon(Icons.qr_code),
                          label: const Text("Copy QR Payload"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: QrImageView(
                        data: qrData!,
                        size: 220,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "QR payload format: NFCAPPKEY:<KEY>",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    )
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
