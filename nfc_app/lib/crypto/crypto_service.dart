import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  // ✅ Replace with your generated secret.
  // Keep private. Best practice later: fetch from server after auth.
  static const String ORG_SECRET = "m0QeK9v9B5Yq5o0k3Lx3mQh2dGkqZpYt8z8y2u3v4wA";

  final AesGcm _cipher = AesGcm.with256bits();
  final Hkdf _hkdf = Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32, // AES-256 key
  );

  Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

  Uint8List _randBytes(int length) {
    final rnd = Random.secure();
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = rnd.nextInt(256);
    }
    return out;
  }

  Future<SecretKey> _deriveFinalKey({
    required String userKey,
    required Uint8List salt,
  }) async {
    if (ORG_SECRET == "REPLACE_WITH_YOUR_ORG_SECRET") {
      throw Exception("Org secret not set. Update CryptoService.ORG_SECRET.");
    }

    // HKDF input key material: userKey bytes
    final ikm = SecretKey(_utf8(userKey));

    // HKDF info: ties derivation to this app/org + prevents cross-app reuse
    final info = Uint8List.fromList([
      ..._utf8("nfc_app:v2|"),
      ..._utf8(ORG_SECRET),
    ]);

    // cryptography HKDF uses `nonce` as the salt
    return _hkdf.deriveKey(
      secretKey: ikm,
      nonce: salt,
      info: info,
    );
  }

  /// Writes v=2 envelope with HKDF-derived AES-GCM key.
  Future<String> encryptEnvelope({
    required String plaintext,
    required String userKey,
  }) async {
    final salt = _randBytes(16);
    final nonce = _randBytes(12);

    final finalKey = await _deriveFinalKey(userKey: userKey, salt: salt);

    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: finalKey,
      nonce: nonce,
    );

    final env = <String, dynamic>{
      "v": 2,
      "alg": "HKDF-SHA256+A256GCM",
      "salt": base64Encode(salt),
      "nonce": base64Encode(nonce),
      "ct": base64Encode(box.cipherText),
      "tag": base64Encode(box.mac.bytes),
    };

    return jsonEncode(env);
  }

  Future<String> decryptEnvelope({
    required String envelopeJson,
    required String userKey,
  }) async {
    final obj = jsonDecode(envelopeJson);
    if (obj is! Map<String, dynamic>) {
      throw Exception("Invalid tag data (not JSON object).");
    }

    if (obj["v"] != 2) {
      throw Exception("Unsupported tag version: ${obj["v"]}");
    }

    final salt = base64Decode(obj["salt"] as String);
    final nonce = base64Decode(obj["nonce"] as String);
    final ct = base64Decode(obj["ct"] as String);
    final tag = base64Decode(obj["tag"] as String);

    final finalKey = await _deriveFinalKey(
      userKey: userKey,
      salt: Uint8List.fromList(salt),
    );

    final box = SecretBox(
      ct,
      nonce: nonce,
      mac: Mac(tag),
    );

    final clearBytes = await _cipher.decrypt(box, secretKey: finalKey);
    return utf8.decode(clearBytes);
  }
}
