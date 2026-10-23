// Dashboard, Security and Onboarding need a signed-in session: secure storage
// is mocked with a token and the profile fetch is faked, so the real
// SessionController bootstraps into SessionAuthenticated.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passvault_mobile/core/api/api_client.dart';
import 'package:passvault_mobile/core/location/location_service.dart';
import 'package:passvault_mobile/core/providers.dart';
import 'package:passvault_mobile/core/storage/token_storage.dart';
import 'package:passvault_mobile/core/theme/app_theme.dart';
import 'package:passvault_mobile/features/account/domain/account_models.dart';
import 'package:passvault_mobile/features/account/presentation/onboarding_screen.dart';
import 'package:passvault_mobile/features/account/presentation/security_screen.dart';
import 'package:passvault_mobile/features/auth/data/auth_repository.dart';
import 'package:passvault_mobile/features/auth/data/whitelabel_repository.dart';
import 'package:passvault_mobile/features/auth/domain/client.dart';
import 'package:passvault_mobile/features/home/presentation/home_screen.dart';
import 'package:passvault_mobile/features/vault_key/data/vault_key_repository.dart';

final _api = ApiClient(TokenStorage(const FlutterSecureStorage()));

class _FakeAuth extends AuthRepository {
  _FakeAuth(this.client) : super(_api, LocationService());
  final Client client;
  @override
  Future<Client> fetchProfile() async => client;
}

class _FakeVaultKeys extends VaultKeyRepository {
  _FakeVaultKeys() : super(_api);
  @override
  Future<VaultKeyParams> fetchParams() async => const VaultKeyParams(exists: true, kdfSalt: 's', keyCheck: 'c');
}

Client _client({String? username = 'alice', bool hasPassword = true, bool hasOtpSecret = true}) => Client(
      name: 'Alice Smith',
      username: username,
      email: 'alice@example.com',
      hasPassword: hasPassword,
      otpEnabled: true,
      otpType: 1,
      hasOtpSecret: hasOtpSecret,
      driveConnected: true,
    );

Widget _wrap(Widget child, Client client) => ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth(client)),
        vaultKeyRepositoryProvider.overrideWithValue(_FakeVaultKeys()),
        whitelabelProvider.overrideWith((ref) async => WhitelabelConfig.none),
        clientPackageProvider.overrideWith(
          (ref) async => ClientPackage(packageId: 1, name: 'Pro', maxAccounts: 500, expiryDate: DateTime(2026, 11, 1), daysRemaining: 5),
        ),
      ],
      child: MaterialApp(theme: buildAppTheme(PvPalette.amethyst), home: child),
    );

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({'passvault.clientToken': 'token'}));

  testWidgets('dashboard shows greeting, locked vault, plan expiry and menu', (tester) async {
    await tester.pumpWidget(_wrap(const HomeScreen(), _client()));
    await tester.pumpAndSettle();
    expect(find.text('Hi, Alice'), findsOneWidget);
    expect(find.text('Unlock vault'), findsOneWidget);
    expect(find.text('5 days left'), findsOneWidget);
    for (final item in ['Profile', 'Security & 2FA', 'Change password', 'Activity', 'Help & legal']) {
      await tester.scrollUntilVisible(find.text(item), 100, scrollable: find.byType(Scrollable).first);
      expect(find.text(item), findsOneWidget);
    }
  });

  testWidgets('security screen offers authenticator reset and danger zone', (tester) async {
    await tester.pumpWidget(_wrap(const SecurityScreen(), _client()));
    await tester.pumpAndSettle();
    expect(find.text('Google Authenticator is set up.'), findsOneWidget);
    expect(find.text('Reset authenticator'), findsOneWidget);
    expect(find.text('Suspend account'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('onboarding asks for username + password first', (tester) async {
    await tester.pumpWidget(_wrap(const OnboardingScreen(), _client(username: null, hasPassword: false, hasOtpSecret: false)));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('3 to 30 characters'), findsOneWidget); // validation blocks an empty submit
  });

  testWidgets('onboarding step 2 is authenticator setup', (tester) async {
    await tester.pumpWidget(_wrap(const OnboardingScreen(), _client(hasOtpSecret: false)));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(find.text('Set up authenticator'), findsOneWidget);
  });
}
