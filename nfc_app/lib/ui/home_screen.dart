import 'package:flutter/material.dart';

import '../crypto/crypto_service.dart';
import '../nfc/nfc_service.dart';
import '../storage/key_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = KeyStore();
  final _crypto = CryptoService();
  final _nfc = NfcService();

  final _keyController = TextEditingController();
  final _msgController = TextEditingController();

  String _status = "Ready.";
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _refreshKeyStatus();
  }

  Future<void> _refreshKeyStatus() async {
    final k = await _store.readUserKey();
    if (!mounted) return;
    setState(() => _hasKey = (k != null && k.trim().isNotEmpty));
  }

  void _setStatus(String s) {
    if (!mounted) return;
    setState(() => _status = s);
  }

  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      _setStatus("Enter the admin-provided user key first.");
      return;
    }
    await _store.saveUserKey(key);
    _keyController.clear();
    await _refreshKeyStatus();
    _setStatus("✅ Key saved to Keychain.");
  }

  Future<void> _clearKey() async {
    await _store.clearUserKey();
    await _refreshKeyStatus();
    _setStatus("🧹 Key cleared.");
  }

  Future<String?> _requireKey() async {
    final key = await _store.readUserKey();
    final k = key?.trim() ?? "";
    if (k.isEmpty) {
      _setStatus("❌ No user key saved. Set the admin key first.");
      return null;
    }
    return k;
  }

  Future<void> _writeTag() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    final key = await _requireKey();
    if (key == null) return;

    final msg = _msgController.text.trim();
    if (msg.isEmpty) {
      _setStatus("Enter a message to write.");
      return;
    }

    try {
      _setStatus("Encrypting…");
      final envelope = await _crypto.encryptEnvelope(
        plaintext: msg,
        userKey: key,
      );

      _setStatus("Hold tag near top of iPhone to WRITE…");
      await _nfc.writeNdefText(envelope);

      _setStatus("✅ Written encrypted payload.");
    } catch (e) {
      _setStatus("❌ Write failed: $e");
    }
  }

  Future<void> _readTag() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    final key = await _requireKey();
    if (key == null) return;

    try {
      _setStatus("Hold tag near top of iPhone to READ…");
      final envelope = await _nfc.readFirstNdefText();

      _setStatus("Decrypting…");
      final clear = await _crypto.decryptEnvelope(
        envelopeJson: envelope,
        userKey: key,
      );

      if (!mounted) return;
      _setStatus("✅ Decrypted.");

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Decrypted Message"),
          content: SelectableText(clear),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      _setStatus("❌ Read/decrypt failed: $e");
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyStatus = _hasKey ? "Saved (Keychain)" : "None";

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("nfc_app — User"),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "User Key (from Admin)",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text("Current: $keyStatus"),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _keyController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      decoration: const InputDecoration(
                        labelText: "Enter admin-provided key",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton(
                          onPressed: _saveKey,
                          child: const Text("Save Key"),
                        ),
                        OutlinedButton(
                          onPressed: _clearKey,
                          child: const Text("Clear Key"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Write (Encrypt → NFC)",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _msgController,
                      minLines: 2,
                      maxLines: 6,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      decoration: const InputDecoration(
                        labelText: "Message",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _writeTag,
                      icon: const Icon(Icons.nfc),
                      label: const Text("Write to Tag"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Read (NFC → Decrypt)",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _readTag,
                      icon: const Icon(Icons.nfc_rounded),
                      label: const Text("Read from Tag"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: TextStyle(
                fontSize: 14,
                color: _status.startsWith("❌") ? Colors.red : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Tip: iPhone reads NFC near the top edge. Use NDEF-capable tags (e.g., NTAG213/215/216).",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
