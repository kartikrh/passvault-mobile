// GET/PUT /vault/data -- mirrors passvault-client's src/lib/vaultData.js.
// The vault key never travels with the request; entries are
// encrypted/decrypted entirely client-side, PassVaultapi only relays the
// resulting opaque blob to/from the client's own Google Drive.
import '../../../core/api/api_client.dart';
import '../../../core/crypto/vault_crypto.dart' as vault_crypto;
import '../domain/vault_entry.dart';

class VaultFileResult {
  final List<VaultEntry> entries;
  final String? revisionId;
  const VaultFileResult(this.entries, this.revisionId);
}

class VaultDataResult {
  final List<VaultEntry> entries;
  final Map<String, String?> revisionIds; // keyed by VaultFileKind
  const VaultDataResult(this.entries, this.revisionIds);
}

class VaultDataRepository {
  VaultDataRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<VaultFileResult> _fetchFile(String vaultKey, String vaultType) async {
    final response = await _apiClient.dio.get('/vault/data', queryParameters: {'vaultType': vaultType});
    final data = response.data as Map<String, dynamic>;
    final blob = data['blob'] as String?;
    if (blob == null) {
      return const VaultFileResult([], null);
    }
    final decrypted = vault_crypto.decryptVaultBlob(vaultKey, blob);
    final rawEntries = decrypted['entries'] as List<dynamic>? ?? [];
    final entries = rawEntries.map((e) => VaultEntry.fromJson(e as Map<String, dynamic>)).toList();
    return VaultFileResult(entries, data['revisionId'] as String?);
  }

  /// Fetches only the requested file kind(s) and merges their entries into
  /// one list -- mirrors fetchVaultEntries: a caller that only needs
  /// Accounts never also pulls the Notes file from Drive, and vice versa.
  Future<VaultDataResult> fetchEntries({
    required String vaultKey,
    List<String> kinds = const [VaultFileKind.accounts, VaultFileKind.notes],
  }) async {
    final results = await Future.wait(kinds.map((kind) => _fetchFile(vaultKey, kind)));
    final entries = <VaultEntry>[];
    final revisionIds = <String, String?>{};
    for (var i = 0; i < kinds.length; i++) {
      entries.addAll(results[i].entries);
      revisionIds[kinds[i]] = results[i].revisionId;
    }
    return VaultDataResult(entries, revisionIds);
  }

  /// Saves only the entries belonging to entryType's file (an Accounts
  /// write never re-uploads Notes, and vice versa) and returns the full
  /// revisionIds map with that one file's id refreshed. Optimistic
  /// concurrency via expectedRevisionId -- see putVaultDataService's
  /// REVISION_CONFLICT error, surfaced to the caller as an ApiException.
  Future<Map<String, String?>> _saveEntries({
    required String vaultKey,
    required List<VaultEntry> entries,
    required Map<String, String?> revisionIds,
    required String entryId,
    required int entryType,
    required String changeType,
    String? entryName,
  }) async {
    final vaultType = vaultFileKindForEntryType(entryType);
    final entriesForFile = entries.where((e) => vaultFileKindForEntryType(e.type) == vaultType).toList();
    final blob = vault_crypto.encryptVaultBlob(vaultKey, {
      'entries': entriesForFile.map((e) => e.toJson()).toList(),
    });
    final response = await _apiClient.dio.put('/vault/data', data: {
      'blob': blob,
      'entryId': entryId,
      'entryType': entryType,
      'changeType': changeType,
      'expectedRevisionId': revisionIds[vaultType],
      'entryName': entryName,
    });
    final data = response.data as Map<String, dynamic>;
    return {...revisionIds, vaultType: data['revisionId'] as String?};
  }

  Future<VaultDataResult> addEntry({
    required String vaultKey,
    required List<VaultEntry> entries,
    required Map<String, String?> revisionIds,
    required VaultEntry newEntry,
  }) async {
    final nextEntries = [...entries, newEntry];
    final nextRevisionIds = await _saveEntries(
      vaultKey: vaultKey,
      entries: nextEntries,
      revisionIds: revisionIds,
      entryId: newEntry.id,
      entryType: newEntry.type,
      changeType: VaultChangeType.create,
      entryName: newEntry.title,
    );
    return VaultDataResult(nextEntries, nextRevisionIds);
  }

  Future<VaultDataResult> updateEntry({
    required String vaultKey,
    required List<VaultEntry> entries,
    required Map<String, String?> revisionIds,
    required VaultEntry updatedEntry,
  }) async {
    final nextEntries = entries.map((e) => e.id == updatedEntry.id ? updatedEntry : e).toList();
    final nextRevisionIds = await _saveEntries(
      vaultKey: vaultKey,
      entries: nextEntries,
      revisionIds: revisionIds,
      entryId: updatedEntry.id,
      entryType: updatedEntry.type,
      changeType: VaultChangeType.update,
      entryName: updatedEntry.title,
    );
    return VaultDataResult(nextEntries, nextRevisionIds);
  }

  Future<VaultDataResult> deleteEntry({
    required String vaultKey,
    required List<VaultEntry> entries,
    required Map<String, String?> revisionIds,
    required String entryId,
    required int entryType,
  }) async {
    final matches = entries.where((e) => e.id == entryId);
    final deletedTitle = matches.isEmpty ? null : matches.first.title;
    final nextEntries = entries.where((e) => e.id != entryId).toList();
    final nextRevisionIds = await _saveEntries(
      vaultKey: vaultKey,
      entries: nextEntries,
      revisionIds: revisionIds,
      entryId: entryId,
      entryType: entryType,
      changeType: VaultChangeType.delete,
      entryName: deletedTitle,
    );
    return VaultDataResult(nextEntries, nextRevisionIds);
  }
}
