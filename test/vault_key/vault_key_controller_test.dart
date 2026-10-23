// VaultKeyController's unlock paths, with the API and the biometric prompt
// faked out.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passvault_mobile/core/biometrics/biometric_service.dart';
import 'package:passvault_mobile/core/crypto/vault_crypto.dart';
import 'package:passvault_mobile/features/vault_key/application/vault_key_controller.dart';
import 'package:passvault_mobile/features/vault_key/data/vault_key_repository.dart';

const _kdfSalt = 'MDEyMzQ1Njc4OWFiY2RlZg==';
// deriveVaultKeyFromPassword('correct horse battery staple', _kdfSalt)
const _vaultKey = 'H/ZMdkjDEDpZ4T7DlMYQs7RkF9UgyowFSsi/pzKxi+s=';

class _FakeRepository implements VaultKeyRepository {
  VaultKeyParams params;
  _FakeRepository(this.params);

  @override
  Future<VaultKeyParams> fetchParams() async => params;

  @override
  Future<String> setup(String vaultPassword) async => _vaultKey;

  @override
  Future<String> unlock(String vaultPassword) async {
    if (vaultPassword != 'correct horse battery staple') throw const IncorrectVaultPasswordException();
    return _vaultKey;
  }
}

class _FakeBiometrics implements BiometricService {
  String? stored;
  bool passes = true;

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> authenticate(String reason) async => passes;
  @override
  Future<bool> isEnabled() async => stored != null;
  @override
  Future<void> enable(String vaultKey) async => stored = vaultKey;
  @override
  Future<void> disable() async => stored = null;
  @override
  Future<String?> unlockVaultKey(String reason) async => (stored != null && passes) ? stored : null;
}

void main() {
  // A real key check for _vaultKey, as the server would hold it.
  final keyCheck = createKeyCheck(_vaultKey);
  VaultKeyParams params() => VaultKeyParams(exists: true, kdfSalt: _kdfSalt, keyCheck: keyCheck);

  test('checkStatus reports a set-up vault as locked, not ready', () async {
    final controller = VaultKeyController(_FakeRepository(params()), _FakeBiometrics());
    await controller.checkStatus();
    expect(controller.state, isA<VaultKeyLocked>());
  });

  test('checkStatus reports missing when no key is set up', () async {
    final controller = VaultKeyController(_FakeRepository(const VaultKeyParams(exists: false)), _FakeBiometrics());
    await controller.checkStatus();
    expect(controller.state, isA<VaultKeyMissing>());
  });

  test('wrong vault password throws and stays locked', () async {
    final controller = VaultKeyController(_FakeRepository(params()), _FakeBiometrics());
    await controller.checkStatus();
    await expectLater(controller.unlockWithPassword('nope'), throwsA(isA<IncorrectVaultPasswordException>()));
    expect(controller.state, isA<VaultKeyLocked>());
  });

  test('biometric unlock returns the stored key when it still matches', () async {
    final biometrics = _FakeBiometrics()..stored = _vaultKey;
    final controller = VaultKeyController(_FakeRepository(params()), biometrics);
    expect(await controller.unlockWithBiometrics(), isTrue);
    expect((controller.state as VaultKeyReady).vaultKey, _vaultKey);
  });

  test('biometric unlock fails closed when the check is cancelled', () async {
    final biometrics = _FakeBiometrics()
      ..stored = _vaultKey
      ..passes = false;
    final controller = VaultKeyController(_FakeRepository(params()), biometrics);
    expect(await controller.unlockWithBiometrics(), isFalse);
    expect(controller.state, isNot(isA<VaultKeyReady>()));
    expect(biometrics.stored, _vaultKey); // a cancel doesn't wipe it
  });

  test('a stale stored key (vault password changed elsewhere) is discarded', () async {
    final biometrics = _FakeBiometrics()..stored = deriveVaultKeyFromPassword('old password', _kdfSalt);
    final controller = VaultKeyController(_FakeRepository(params()), biometrics);
    expect(await controller.unlockWithBiometrics(), isFalse);
    expect(biometrics.stored, isNull);
  });

  test('enabling biometrics requires an unlocked vault', () async {
    final biometrics = _FakeBiometrics();
    final controller = VaultKeyController(_FakeRepository(params()), biometrics);
    await expectLater(controller.enableBiometrics(), throwsStateError);
    await controller.unlockWithPassword('correct horse battery staple');
    await controller.enableBiometrics();
    expect(biometrics.stored, _vaultKey);
  });

  test('BiometricService type is constructible with secure storage', () {
    expect(BiometricService(const FlutterSecureStorage()), isA<BiometricService>());
  });
}
