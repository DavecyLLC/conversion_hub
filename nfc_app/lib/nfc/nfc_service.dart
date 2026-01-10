import 'dart:async';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';

class NfcService {
  Future<bool> isAvailable() => NfcManager.instance.isAvailable();

  Future<void> writeNdefText(String text) async {
    final ok = await isAvailable();
    if (!ok) throw Exception("NFC not available on this device.");

    final completer = Completer<void>();

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) throw Exception("Tag is not NDEF formatted.");
          if (!ndef.isWritable) throw Exception("Tag is not writable.");

          final record = NdefRecord.createText(text);
          final message = NdefMessage([record]);

          // Rough size check (helps diagnose capacity issues)
          final bytes = _estimateNdefMessageSize(message);
          final maxSize = ndef.maxSize;
          if (bytes > maxSize) {
            throw Exception(
              "Data too large for tag. Need ~${bytes}B but tag supports ${maxSize}B. "
              "Use NTAG215/216 or shorten message.",
            );
          }

          await ndef.write(message);

          NfcManager.instance.stopSession(alertMessage: "Write successful ✅");
          completer.complete();
        } catch (e) {
          NfcManager.instance.stopSession(errorMessage: e.toString());
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
    );

    return completer.future;
  }

  Future<String> readFirstNdefText() async {
    final ok = await isAvailable();
    if (!ok) throw Exception("NFC not available on this device.");

    final completer = Completer<String>();

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) throw Exception("Tag is not NDEF formatted.");

          // ✅ IMPORTANT: actively read the tag (don’t rely on cachedMessage)
          final msg = await ndef.read();
          if (msg.records.isEmpty) throw Exception("No NDEF records found.");

          final record = msg.records.first;

          // Text record payload format: [status][lang...][text...]
          final payload = record.payload;
          if (payload.isEmpty) throw Exception("Empty NDEF record payload.");

          final status = payload[0];
          final langLen = status & 0x3F;
          if (payload.length < 1 + langLen) {
            throw Exception("Malformed text record payload.");
          }

          final textBytes = payload.sublist(1 + langLen);
          final text = String.fromCharCodes(textBytes);

          NfcManager.instance.stopSession(alertMessage: "Read successful ✅");
          completer.complete(text);
        } catch (e) {
          NfcManager.instance.stopSession(errorMessage: e.toString());
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
    );

    return completer.future;
  }

  int _estimateNdefMessageSize(NdefMessage message) {
    // A simple estimate: sum payload lengths + small overhead.
    // Good enough to catch “way too big” cases.
    var total = 0;
    for (final r in message.records) {
      total += r.payload.length + 20; // record overhead estimate
    }
    return total + 10; // message overhead estimate
  }
}
