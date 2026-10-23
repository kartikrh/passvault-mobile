import 'package:flutter_test/flutter_test.dart';
import 'package:passvault_mobile/features/account/domain/account_models.dart';
import 'package:passvault_mobile/features/account/presentation/onboarding_screen.dart';
import 'package:passvault_mobile/features/account/presentation/profile_screen.dart';
import 'package:passvault_mobile/features/auth/domain/client.dart';
import 'package:passvault_mobile/features/vault_data/domain/account.dart';
import 'package:passvault_mobile/features/vault_data/domain/note.dart';
import 'package:passvault_mobile/features/vault_data/domain/vault_entry.dart';

Client _client({String? username = 'alice', bool hasPassword = true, bool otpEnabled = true, int? otpType = 1, bool hasOtpSecret = true}) =>
    Client(
      name: 'Alice',
      username: username,
      email: 'alice@example.com',
      hasPassword: hasPassword,
      otpEnabled: otpEnabled,
      otpType: otpType,
      hasOtpSecret: hasOtpSecret,
      driveConnected: true,
    );

void main() {
  group('entries keep fields this app does not know about', () {
    test('account edit keeps unknown fields and hidden', () {
      final entry = VaultEntry.fromJson({
        'id': '1',
        'type': VaultEntryType.account,
        'title': 'Mail',
        'username': 'a',
        'password': 'p',
        'hidden': true,
        'futureField': {'x': 1},
      });
      final account = Account.fromEntry(entry);
      expect(account.hidden, isTrue);
      final saved = Account(
        id: account.id,
        title: 'Mail 2',
        username: account.username,
        password: account.password,
        hidden: account.hidden,
        extra: account.extra,
      ).toEntry(id: '1');
      expect(saved.fields['futureField'], {'x': 1});
      expect(saved.fields['hidden'], isTrue);
      expect(saved.fields['title'], 'Mail 2');
    });

    test('note copyWith keeps unknown fields and hidden', () {
      final note = Note.fromEntry(VaultEntry.fromJson({
        'id': '2',
        'type': VaultEntryType.note,
        'title': 't',
        'body': 'b',
        'hidden': true,
        'futureField': 'keep',
      }));
      final saved = note.copyWith(title: 'new').toEntry(id: '2');
      expect(saved.fields['futureField'], 'keep');
      expect(saved.fields['hidden'], isTrue);
    });
  });

  group('onboarding gate (matches the web wizard)', () {
    test('complete account passes', () => expect(needsOnboarding(_client()), isFalse));
    test('missing username needs profile', () => expect(needsProfileStep(_client(username: null)), isTrue));
    test('Google account without password needs profile', () => expect(needsProfileStep(_client(hasPassword: false)), isTrue));
    test('authenticator not enrolled needs OTP step', () => expect(needsOtpStep(_client(hasOtpSecret: false)), isTrue));
    test('mail OTP never needs enrollment', () => expect(needsOtpStep(_client(otpType: 2, hasOtpSecret: false)), isFalse));
    test('2FA off never needs enrollment', () => expect(needsOtpStep(_client(otpEnabled: false, hasOtpSecret: false)), isFalse));
  });

  test('username validation mirrors the server', () {
    expect(validateUsername('ab'), isNotNull);
    expect(validateUsername('bad name'), isNotNull);
    expect(validateUsername('good.name_1'), isNull);
  });

  test('formatPrice uses the server IntervalType codes', () {
    expect(formatPrice(0, 'INR', '2', 1), 'Free');
    expect(formatPrice(499, 'INR', '2', 1), '₹499 / month');
    expect(formatPrice(1200, 'USD', '3', 2), r'$1200 / 2 years');
    expect(formatPrice(99.5, 'EUR', '1', 7), '€99.50 / 7 days');
  });

  test('activity details: entry name for vault rows, path for page views, none otherwise', () {
    ActivityItem item(int type) => ActivityItem.fromJson({
          'activityType': type,
          'activityLabel': 'x',
          'refId': '/accounts',
          'entryName': 'Gmail',
          'createdDate': '2026-10-23T08:00:00Z',
        });
    expect(item(ActivityType.accountPasswordViewed).details, 'Gmail');
    expect(item(ActivityType.pageViewed).details, '/accounts');
    expect(item(102).details, isNull);
  });
}
