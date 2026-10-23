// Renders the new account screens with fake repositories -- catches layout
// errors (overflow, unbounded constraints) and wiring mistakes that static
// analysis can't.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passvault_mobile/core/api/api_client.dart';
import 'package:passvault_mobile/core/providers.dart';
import 'package:passvault_mobile/core/storage/token_storage.dart';
import 'package:passvault_mobile/core/theme/app_theme.dart';
import 'package:passvault_mobile/features/account/data/account_repository.dart';
import 'package:passvault_mobile/features/account/domain/account_models.dart';
import 'package:passvault_mobile/features/account/presentation/activity_screen.dart';
import 'package:passvault_mobile/features/account/presentation/pages_screen.dart';
import 'package:passvault_mobile/features/account/presentation/upgrade_plan_screen.dart';

final _api = ApiClient(TokenStorage(const FlutterSecureStorage()));

class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository() : super(_api);

  @override
  Future<ActivityPage> fetchActivity({int page = 1, int pageSize = 25}) async => ActivityPage(
        [
          ActivityItem(
            activityType: ActivityType.accountPasswordViewed,
            label: 'Account password viewed',
            entryName: 'Gmail',
            ipAddress: '203.0.113.9',
            latitude: 12.9,
            longitude: 77.5,
            createdDate: DateTime(2026, 10, 23, 10, 30),
          ),
          ActivityItem(activityType: 102, label: 'Logged in', createdDate: DateTime(2026, 10, 22)),
        ],
        1,
        1,
        2,
      );

  @override
  Future<ClientPackage?> fetchPackage() async => ClientPackage(
        packageId: 1,
        name: 'Free',
        expiryDate: DateTime(2026, 11, 1),
        daysRemaining: 9,
      );
}

class _FakePlanRepository extends PlanRepository {
  _FakePlanRepository() : super(_api);

  @override
  Future<List<Plan>> fetchPlans() async => const [
        Plan(id: 1, name: 'Free', price: 0),
        Plan(id: 2, name: 'Pro', price: 499, currency: 'INR', intervalType: '2', intervalCount: 1, maxAccounts: 500),
      ];

  @override
  Future<UpgradeRequest?> fetchMyRequest() async =>
      const UpgradeRequest(status: 'REJECTED', requestedPackageName: 'Pro', rejectionReason: 'Payment not found');

  @override
  Future<PaymentMethod> fetchPaymentMethod() async => const PaymentMethod(
        upiId: 'passvault@upi',
        bankName: 'Test Bank',
        accountNumber: '1234567890',
        instructions: '<p>Pay and enter the <b>UTR</b> number.</p>',
      );
}

Widget _wrap(Widget child) => ProviderScope(
      overrides: [
        accountRepositoryProvider.overrideWithValue(_FakeAccountRepository()),
        planRepositoryProvider.overrideWithValue(_FakePlanRepository()),
        cmsPagesProvider.overrideWith((ref) async => const [
              CmsPage(title: 'Home', alias: '/', isDefault: true),
              CmsPage(title: 'Privacy policy', alias: 'privacy', content: '<h2>Privacy</h2><p>We never see your vault.</p>'),
              CmsPage(title: 'Status', alias: 'status', isLink: true, linkUrl: 'https://status.example.com'),
            ]),
      ],
      child: MaterialApp(theme: buildAppTheme(PvPalette.amethyst), home: child),
    );

void main() {
  testWidgets('activity list shows rows with details, IP and location', (tester) async {
    await tester.pumpWidget(_wrap(const ActivityScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Account password viewed · Gmail'), findsOneWidget);
    expect(find.textContaining('IP 203.0.113.9'), findsOneWidget);
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    expect(find.text('Logged in'), findsOneWidget);
  });

  testWidgets('help & legal lists content pages and opens one', (tester) async {
    await tester.pumpWidget(_wrap(const PagesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsNothing); // default page filtered out
    expect(find.text('Status'), findsOneWidget);
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('We never see your vault.', findRichText: true), findsOneWidget);
  });

  testWidgets('upgrade plan: rejected banner, other plans, payment details', (tester) async {
    await tester.pumpWidget(_wrap(const UpgradePlanScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Payment not found'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget); // current plan (Free) not offered
    await tester.tap(find.text('Pro'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('passvault@upi'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('passvault@upi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Submit for approval'), 200, scrollable: find.byType(Scrollable).first);
    final submit = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit for approval'));
    expect(submit.onPressed, isNull); // needs a transfer reference first
  });
}
