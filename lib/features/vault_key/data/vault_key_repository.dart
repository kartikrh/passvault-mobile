// POST /vault/key/{params,setup,migrate} -- see PassVaultapi's
// services/vaultKey.js. Zero-knowledge: the vault key is derived on this
// device from the user's vault password (PBKDF2 + the account's kdfSalt) and
// checked against keyCheck locally; the server never receives or stores it.
// Forgetting the vault password means the vault can't be opened.
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/crypto/vault_crypto.dart' as vault_crypto;

class VaultKeyParams {
  final bool exists;
  final String? kdfSalt;
  final String? keyCheck;
  final bool needsMigration;

  const VaultKeyParams({required this.exists, this.kdfSalt, this.keyCheck, this.needsMigration = false});

  factory VaultKeyParams.fromJson(Map<String, dynamic> json) => VaultKeyParams(
        exists: json['exists'] == true,
        kdfSalt: json['kdfSalt'] as String?,
        keyCheck: json['keyCheck'] as String?,
        needsMigration: json['needsMigration'] == true,
      );
}

class IncorrectVaultPasswordException implements Exception {
  const IncorrectVaultPasswordException();
  @override
  String toString() => 'Incorrect vault password';
}

// PBKDF2 (210k iterations, pure Dart) takes long enough to freeze the UI --
// run it on a background isolate.
String _deriveInIsolate(List<String> args) => vault_crypto.deriveVaultKeyFromPassword(args[0], args[1]);

Future<String> _derive(String vaultPassword, String kdfSalt) => compute(_deriveInIsolate, [vaultPassword, kdfSalt]);

class VaultKeyRepository {
  VaultKeyRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<VaultKeyParams> fetchParams() async {
    // Needs an explicit body -- see whitelabel_repository.dart's fetch()
    // comment on why a bodyless POST fails Fastify's JSON body parser.
    final response = await _apiClient.dio.post('/vault/key/params', data: <String, dynamic>{});
    return VaultKeyParams.fromJson(response.data as Map<String, dynamic>);
  }

  /// First-time setup: only the salt and key check are sent. Returns the
  /// derived key for the caller to hold in memory.
  Future<String> setup(String vaultPassword) async {
    final kdfSalt = vault_crypto.generateKdfSalt();
    final vaultKey = await _derive(vaultPassword, kdfSalt);
    await _apiClient.dio.post('/vault/key/setup', data: {
      'kdfSalt': kdfSalt,
      'keyCheck': vault_crypto.createKeyCheck(vaultKey),
    });
    return vaultKey;
  }

  /// Derives the key from [vaultPassword] and verifies it. Accounts set up
  /// before the zero-knowledge change confirm the password once via
  /// /vault/key/migrate, which also deletes the server's escrowed copy.
  Future<String> unlock(String vaultPassword) async {
    final params = await fetchParams();
    if (!params.exists || params.kdfSalt == null) {
      throw StateError('Vault key is not set up yet.');
    }
    final vaultKey = await _derive(vaultPassword, params.kdfSalt!);

    if (params.needsMigration) {
      await _apiClient.dio.post('/vault/key/migrate', data: {
        'vaultKey': vaultKey,
        'keyCheck': vault_crypto.createKeyCheck(vaultKey),
      });
    } else if (params.keyCheck == null || !vault_crypto.verifyKeyCheck(vaultKey, params.keyCheck!)) {
      throw const IncorrectVaultPasswordException();
    }
    return vaultKey;
  }
}
