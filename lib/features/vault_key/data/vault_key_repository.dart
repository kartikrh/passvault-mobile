// POST /vault/key/{setup,recover} -- see PassVaultapi's services/vaultKey.js.
// The vault key is generated/derived entirely client-side (PBKDF2 over a
// user-chosen "vault password"); the server only ever stores it wrapped
// (escrowed) and hands the unwrapped key back to an already-authenticated
// client via /recover. It never sees the vault password itself.
import '../../../core/api/api_client.dart';
import '../../../core/crypto/vault_crypto.dart' as vault_crypto;

class VaultKeyRepository {
  VaultKeyRepository(this._apiClient);

  final ApiClient _apiClient;

  /// First-time setup (Profile's "Set up vault key" action, per
  /// passvault-client's setupVaultKey). Derives the key from
  /// [vaultPassword] with a freshly generated salt, escrows it, and returns
  /// the derived key (base64) for the caller to hold for this session.
  Future<String> setup(String vaultPassword) async {
    final kdfSalt = vault_crypto.generateKdfSalt();
    final vaultKey = vault_crypto.deriveVaultKeyFromPassword(vaultPassword, kdfSalt);
    await _apiClient.dio.post('/vault/key/setup', data: {'vaultKey': vaultKey, 'kdfSalt': kdfSalt});
    return vaultKey;
  }

  /// Read-only check -- never creates a key (mirrors
  /// passvault-client's getVaultKeyStatus). Returns null if no vault key has
  /// been escrowed for this client yet (setupVaultKeyService's
  /// "no escrowed vault key" case) rather than throwing, so the caller can
  /// decide to route to setup.
  Future<String?> recover() async {
    try {
      // Needs an explicit body -- see whitelabel_repository.dart's fetch()
      // comment on why a bodyless POST fails Fastify's JSON body parser.
      final response = await _apiClient.dio.post('/vault/key/recover', data: <String, dynamic>{});
      final data = response.data as Map<String, dynamic>;
      return data['vaultKey'] as String;
    } catch (e) {
      final apiException = ApiClient.toApiException(e);
      if (apiException.message.contains('No escrowed vault key')) {
        return null;
      }
      rethrow;
    }
  }
}
