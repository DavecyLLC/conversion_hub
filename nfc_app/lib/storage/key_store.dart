import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyStore {
  static const String _kUserKey = "nfc_app_user_key_v2";

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveUserKey(String key) async {
    await _storage.write(key: _kUserKey, value: key);
  }

  Future<String?> readUserKey() async {
    return _storage.read(key: _kUserKey);
  }

  Future<void> clearUserKey() async {
    await _storage.delete(key: _kUserKey);
  }
}
