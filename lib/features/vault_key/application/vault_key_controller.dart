import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/biometrics/biometric_service.dart';
import '../../../core/crypto/vault_crypto.dart' as vault_crypto;
import '../data/vault_key_repository.dart';

sealed class VaultKeyState {
  const VaultKeyState();
}

class VaultKeyUnknown extends VaultKeyState {
  const VaultKeyUnknown();
}

class VaultKeyMissing extends VaultKeyState {
  const VaultKeyMissing();
}

/// A vault key is set up for this account but isn't in memory yet --
/// needs the vault password (or biometrics) to unlock.
class VaultKeyLocked extends VaultKeyState {
  const VaultKeyLocked();
}

class VaultKeyReady extends VaultKeyState {
  final String vaultKey; // base64, kept in memory only for this app session
  const VaultKeyReady(this.vaultKey);
}

/// The vault key lives in memory only (plus, if the user opted in, in the
/// Keystore/Keychain behind a biometric check -- see [BiometricService]).
class VaultKeyController extends StateNotifier<VaultKeyState> {
  VaultKeyController(this._repository, this._biometrics) : super(const VaultKeyUnknown());

  final VaultKeyRepository _repository;
  final BiometricService _biometrics;

  Future<void> checkStatus() async {
    if (state is VaultKeyReady) return;
    state = const VaultKeyUnknown();
    final params = await _repository.fetchParams();
    state = params.exists ? const VaultKeyLocked() : const VaultKeyMissing();
  }

  Future<void> setup(String vaultPassword) async {
    final vaultKey = await _repository.setup(vaultPassword);
    state = VaultKeyReady(vaultKey);
  }

  /// Throws [IncorrectVaultPasswordException] for a wrong password.
  Future<void> unlockWithPassword(String vaultPassword) async {
    final vaultKey = await _repository.unlock(vaultPassword);
    // Keep the biometric copy in step if the vault password was changed elsewhere.
    if (await _biometrics.isEnabled()) await _biometrics.enable(vaultKey);
    state = VaultKeyReady(vaultKey);
  }

  /// Returns false if biometrics are off, cancelled or failed. A stored key
  /// that no longer matches the account's key check (vault password changed
  /// on another device) is discarded, so the user falls back to the password.
  Future<bool> unlockWithBiometrics() async {
    final vaultKey = await _biometrics.unlockVaultKey('Unlock your PassVault vault');
    if (vaultKey == null) return false;
    final params = await _repository.fetchParams();
    if (params.needsMigration || params.keyCheck == null || !vault_crypto.verifyKeyCheck(vaultKey, params.keyCheck!)) {
      await _biometrics.disable();
      return false;
    }
    state = VaultKeyReady(vaultKey);
    return true;
  }

  /// Opt in to biometric unlock -- needs the vault unlocked (key in memory).
  Future<void> enableBiometrics() async {
    final current = state;
    if (current is! VaultKeyReady) throw StateError('Unlock the vault first.');
    await _biometrics.enable(current.vaultKey);
  }

  Future<void> disableBiometrics() => _biometrics.disable();

  /// Drops the in-memory key (logout / app lock). The biometric copy, if any,
  /// is handled by the caller.
  void clear() {
    state = const VaultKeyUnknown();
  }
}
