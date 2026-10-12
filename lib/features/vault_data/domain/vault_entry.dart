/// Mirrors PassVaultapi's utilities/vaultConstants.js / passvault-client's
/// src/lib/vaultData.js -- entryType/changeType are declared by the client
/// on every PUT /vault/data so the server's opaque-id ledger can enforce
/// plan quotas and log activity without ever decrypting the blob it stores.
abstract class VaultEntryType {
  static const int account = 1;
  static const int group = 2;
  static const int note = 3;
}

abstract class VaultChangeType {
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
}

/// Accounts (+ Groups) and Notes live in two SEPARATE encrypted files in the
/// client's Drive -- each fetched/saved independently, with its own Drive
/// revision id.
abstract class VaultFileKind {
  static const String accounts = 'accounts';
  static const String notes = 'notes';
}

String vaultFileKindForEntryType(int entryType) {
  switch (entryType) {
    case VaultEntryType.account:
    case VaultEntryType.group:
      return VaultFileKind.accounts;
    case VaultEntryType.note:
      return VaultFileKind.notes;
    default:
      throw ArgumentError('Unknown entryType: $entryType');
  }
}

/// A decrypted vault entry (account, group, or note). Kept as a loosely
/// typed JSON map -- like passvault-client's vaultData.js -- rather than a
/// rigid class hierarchy, since PassVaultapi never validates or even sees
/// this shape (it's opaque inside the encrypted blob); the concrete
/// field sets (title/username/password/url/securityQuestions for an
/// account; title/body/color/pinned/archived/tags for a note) are a
/// presentation-layer concern for the accounts/notes screens.
class VaultEntry {
  final String id;
  final int type;
  final Map<String, dynamic> fields;

  const VaultEntry({required this.id, required this.type, required this.fields});

  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    final id = copy.remove('id') as String;
    final type = copy.remove('type') as int;
    return VaultEntry(id: id, type: type, fields: copy);
  }

  Map<String, dynamic> toJson() => {'id': id, 'type': type, ...fields};

  String? get title => fields['title'] as String?;
}
