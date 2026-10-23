import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/biometrics/biometric_service.dart';

enum AppLockState { unknown, locked, unlocked }

/// Biometric app lock. With biometric unlock enabled, a signed-in session
/// starts locked on every cold start and re-locks after the app sits in the
/// background (see main.dart), so reopening PassVault means a
/// fingerprint/face check (LockScreen) rather than a full sign-in. Without
/// biometrics the app is never "locked" -- it signs out instead.
class AppLockController extends StateNotifier<AppLockState> {
  AppLockController(this._biometrics) : super(AppLockState.unknown) {
    _init();
  }

  final BiometricService _biometrics;

  Future<void> _init() async {
    state = await _biometrics.isEnabled() ? AppLockState.locked : AppLockState.unlocked;
  }

  /// Returns true if the app locked; false means biometrics are off and the
  /// caller should sign out instead.
  Future<bool> lock() async {
    if (!await _biometrics.isEnabled()) return false;
    state = AppLockState.locked;
    return true;
  }

  void unlock() {
    state = AppLockState.unlocked;
  }
}
