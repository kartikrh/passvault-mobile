import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api/api_client.dart';
import 'location/location_service.dart';
import 'storage/token_storage.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/step_up_repository.dart';
import '../features/auth/data/whitelabel_repository.dart';
import '../features/vault_data/data/drive_repository.dart';
import '../features/vault_data/data/vault_data_repository.dart';
import '../features/vault_key/application/vault_key_controller.dart';
import '../features/vault_key/data/vault_key_repository.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage(ref.watch(secureStorageProvider)));

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(tokenStorageProvider)));

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(locationServiceProvider)),
);

final stepUpRepositoryProvider = Provider<StepUpRepository>((ref) => StepUpRepository(ref.watch(apiClientProvider)));

final whitelabelRepositoryProvider = Provider<WhitelabelRepository>(
  (ref) => WhitelabelRepository(ref.watch(apiClientProvider)),
);

/// Shared across every screen that needs it (login's Google/reCAPTCHA
/// gating, Drive connect's googleClientId) -- autoDispose since it's cheap
/// to refetch and shouldn't outlive whichever screens are actually watching it.
final whitelabelProvider = FutureProvider.autoDispose<WhitelabelConfig>(
  (ref) => ref.watch(whitelabelRepositoryProvider).fetch(),
);

final vaultKeyRepositoryProvider = Provider<VaultKeyRepository>(
  (ref) => VaultKeyRepository(ref.watch(apiClientProvider)),
);

final vaultKeyControllerProvider = StateNotifierProvider<VaultKeyController, VaultKeyState>(
  (ref) => VaultKeyController(ref.watch(vaultKeyRepositoryProvider)),
);

final driveRepositoryProvider = Provider<DriveRepository>((ref) => DriveRepository(ref.watch(apiClientProvider)));

final vaultDataRepositoryProvider = Provider<VaultDataRepository>(
  (ref) => VaultDataRepository(ref.watch(apiClientProvider)),
);
