// Client-side AES-256-GCM for vault entries, matching passvault-client's
// src/lib/vaultCrypto.js byte-for-byte -- the same account's vault has to
// decrypt identically whether it was written by the web client or this app.
//
// Wire format for both the derived key and an encrypted blob is base64:
//   - deriveVaultKeyFromPassword -> base64(32 raw key bytes)
//   - encryptVaultBlob           -> base64(12-byte IV || ciphertext || 16-byte GCM tag)
//
// PointyCastle's GCMBlockCipher appends the tag to the ciphertext on encrypt
// and expects it appended on decrypt, same layout WebCrypto's
// crypto.subtle.encrypt/decrypt("AES-GCM", ...) uses -- so the concatenation
// here lines up with vaultCrypto.js's `combined = iv || ciphertext` without
// any extra framing.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

const int ivLength = 12; // bytes, standard AES-GCM nonce size
const int _gcmTagLengthBits = 128;

// OWASP-recommended minimum for PBKDF2-HMAC-SHA256 (2023 guidance) -- must
// stay equal to PBKDF2_ITERATIONS in vaultCrypto.js or the two clients derive
// different keys from the same vault password.
const int pbkdf2Iterations = 210000;
const int _vaultKeyLengthBytes = 32; // 256-bit AES key

final Random _secureRandom = Random.secure();

Uint8List _randomBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = _secureRandom.nextInt(256);
  }
  return bytes;
}

/// The KDF salt is public (not secret) but must be random and unique per
/// client -- generated once at setup, stored alongside the escrowed key
/// server-side (tblClientVaultKey.wrKdfSalt), and reused on every later
/// derivation of the same vault key.
String generateKdfSalt() => base64Encode(_randomBytes(16));

/// Derives the 256-bit AES vault key from a user-chosen vault password via
/// PBKDF2-HMAC-SHA256. Returns base64(32 bytes), matching
/// deriveVaultKeyFromPassword in vaultCrypto.js.
String deriveVaultKeyFromPassword(String vaultPassword, String kdfSaltBase64) {
  final salt = base64Decode(kdfSaltBase64);
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, pbkdf2Iterations, _vaultKeyLengthBytes));
  final key = derivator.process(Uint8List.fromList(utf8.encode(vaultPassword)));
  return base64Encode(key);
}

GCMBlockCipher _initCipher(String vaultKeyBase64, Uint8List iv, bool forEncryption) {
  final keyBytes = base64Decode(vaultKeyBase64);
  final cipher = GCMBlockCipher(AESEngine())
    ..init(forEncryption, AEADParameters(KeyParameter(keyBytes), _gcmTagLengthBits, iv, Uint8List(0)));
  return cipher;
}

/// Encrypts [plaintextObject] (anything `jsonEncode` accepts) and returns one
/// base64 string -- iv || ciphertext || tag -- self-contained the same way
/// encryptVaultBlob in vaultCrypto.js is, so the blob PUT to /vault/data
/// needs nothing else alongside it.
String encryptVaultBlob(String vaultKeyBase64, Object? plaintextObject) {
  return encryptVaultBlobWithIv(vaultKeyBase64, plaintextObject, _randomBytes(ivLength));
}

/// Same as [encryptVaultBlob] but with an explicit IV instead of a random
/// one. Not for production use (reusing an IV with the same key breaks
/// AES-GCM) -- exists so a test can pin the IV and diff the output against
/// vaultCrypto.js's WebCrypto encryption byte-for-byte, since AES-GCM is
/// deterministic for a given key/iv/plaintext/AAD.
String encryptVaultBlobWithIv(String vaultKeyBase64, Object? plaintextObject, Uint8List iv) {
  final cipher = _initCipher(vaultKeyBase64, iv, true);
  final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(plaintextObject)));
  final ciphertext = cipher.process(plaintext);
  final combined = Uint8List(iv.length + ciphertext.length)
    ..setRange(0, iv.length, iv)
    ..setRange(iv.length, iv.length + ciphertext.length, ciphertext);
  return base64Encode(combined);
}

/// Reverses [encryptVaultBlob]. Throws if [blobBase64] fails GCM
/// authentication (wrong key, or the blob was tampered with/corrupted).
Map<String, dynamic> decryptVaultBlob(String vaultKeyBase64, String blobBase64) {
  final combined = base64Decode(blobBase64);
  final iv = combined.sublist(0, ivLength);
  final ciphertextAndTag = Uint8List.fromList(combined.sublist(ivLength));
  final cipher = _initCipher(vaultKeyBase64, iv, false);
  final plaintext = cipher.process(ciphertextAndTag);
  return jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
}

/// Fixed marker inside the key check stored server-side
/// (tblClientVaultKey.wrKeyCheck) -- identical to passvault-client's
/// vaultCrypto.js so either app can verify a key check the other created.
const String keyCheckMarker = 'passvault-key-check-v1';

/// Encrypts the key-check marker with [vaultKeyBase64]. The server stores
/// this instead of the key itself, which lets an unlock detect a wrong vault
/// password without the server ever being able to derive or test the key.
String createKeyCheck(String vaultKeyBase64) => encryptVaultBlob(vaultKeyBase64, {'check': keyCheckMarker});

/// True if [keyCheck] decrypts to the marker under [vaultKeyBase64]; false
/// for a wrong key (GCM authentication failure) or a malformed check.
bool verifyKeyCheck(String vaultKeyBase64, String keyCheck) {
  try {
    return decryptVaultBlob(vaultKeyBase64, keyCheck)['check'] == keyCheckMarker;
  } catch (_) {
    return false;
  }
}
