import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Fingerprint / Face ID unlock.
///
/// When enabled, the vault key (derived from the vault password at the last
/// password unlock) is kept in Android Keystore / iOS Keychain via
/// flutter_secure_storage, and only read back after [authenticate] succeeds.
/// That lets the app reopen -- and reveal saved passwords -- with a
/// biometric check instead of re-typing the vault password or a 2FA code.
/// Signing out wipes it (see SessionController.logout).
class BiometricService {
  BiometricService(this._storage, [LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  static const _vaultKeyKey = 'passvault.biometricVaultKey';

  /// The device has enrolled fingerprint/face biometrics the app can use.
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      // PlatformException, LocalAuthException, MissingPluginException (no
      // plugin on this platform) -- all mean biometrics aren't usable.
      return false;
    }
  }

  /// Shows the system biometric prompt. False if the user cancelled, the
  /// biometric didn't match, or biometrics are unavailable/locked out.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async => (await _storage.read(key: _vaultKeyKey)) != null;

  /// Stores [vaultKey] for biometric unlock (or refreshes it after a vault
  /// password change).
  Future<void> enable(String vaultKey) => _storage.write(key: _vaultKeyKey, value: vaultKey);

  Future<void> disable() => _storage.delete(key: _vaultKeyKey);

  /// Prompts for biometrics and, on success, returns the stored vault key.
  /// Null if biometric unlock isn't enabled or the check failed/was cancelled.
  Future<String?> unlockVaultKey(String reason) async {
    if (!await isEnabled()) return null;
    if (!await authenticate(reason)) return null;
    return _storage.read(key: _vaultKeyKey);
  }
}
