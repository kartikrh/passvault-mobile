import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class VaultKeyReady extends VaultKeyState {
  final String vaultKey; // base64, kept in memory only for this app session
  const VaultKeyReady(this.vaultKey);
}

/// Deliberately in-memory only, not secure storage -- same lifetime as
/// passvault-client's sessionStorage cache (cleared on app close/logout),
/// so every fresh app launch does a real /vault/key/recover round-trip
/// rather than trusting a long-lived local copy of the encryption key.
class VaultKeyController extends StateNotifier<VaultKeyState> {
  VaultKeyController(this._repository) : super(const VaultKeyUnknown());

  final VaultKeyRepository _repository;

  Future<void> checkStatus() async {
    state = const VaultKeyUnknown();
    final vaultKey = await _repository.recover();
    state = vaultKey == null ? const VaultKeyMissing() : VaultKeyReady(vaultKey);
  }

  Future<void> setup(String vaultPassword) async {
    final vaultKey = await _repository.setup(vaultPassword);
    state = VaultKeyReady(vaultKey);
  }

  void clear() {
    state = const VaultKeyUnknown();
  }
}
