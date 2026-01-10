import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminPinStore {
  static const String kAdminPin = "nfc_app_admin_pin_v1";
  static const String defaultPin = "2468";

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Returns saved PIN if set, otherwise defaultPin.
  Future<String> getPin() async {
    final v = await _storage.read(key: kAdminPin);
    return (v == null || v.trim().isEmpty) ? defaultPin : v.trim();
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: kAdminPin, value: pin);
  }

  Future<void> resetToDefault() async {
    await _storage.delete(key: kAdminPin);
  }
}

