// FILE: test/biometric_service_test.dart
//
// Unit tests for `lib/services/biometric_service.dart`. Exercises:
//
//   1. Hydration — initial probe and `isHydrated` flips to true.
//   2. `isAvailable` is false when the device reports no biometric
//      enrolled OR `isDeviceSupported` returns false.
//   3. `setEnabled(true)` refuses for anonymous + null users (the
//      defense-in-depth guard added when biometric was de-promoted
//      for anonymous accounts).
//   4. `setEnabled(true)` runs an authentication confirm pass —
//      a failed confirm leaves the toggle off.
//   5. `setEnabled(false)` is unconditional (matches iOS Settings
//      → Touch ID semantics — disabling never re-prompts).
//   6. `lock()` only re-arms when biometric is enabled and
//      currently unlocked.
//
// Mocks `LocalAuthentication` via the constructor's `auth`
// parameter and the user getter via `currentUserGetter`. No
// FirebaseAuth instance is required.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

// Pulled directly from the platform interface so the test doesn't
// have to re-import `AuthMessages` (which `local_auth` doesn't
// re-export). The error_codes constants are also there.
// ignore: implementation_imports
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loadout/services/biometric_service.dart';

/// Minimal stub for `LocalAuthentication`. We don't `implements
/// LocalAuthentication` — that would force us to import the
/// `AuthMessages` type which lives in `local_auth_platform_interface`
/// and isn't re-exported by `local_auth`. Instead we extend
/// `LocalAuthentication` and use `noSuchMethod` to fail loud on any
/// member we haven't explicitly mocked, while still satisfying the
/// `BiometricService` constructor's `LocalAuthentication?` parameter.
class _StubLocalAuthentication implements LocalAuthentication {
  bool deviceSupported = true;
  List<BiometricType> available = [BiometricType.face];
  bool authenticateResult = true;
  bool throwOnAuthenticate = false;

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => available;

  // Note: `authenticate` is intentionally NOT overridden via
  // `@override` — its signature includes `Iterable<AuthMessages>`
  // which lives in `local_auth_platform_interface` (not re-exported
  // by `local_auth`). We intercept the call via `noSuchMethod` on
  // the right Symbol below.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #authenticate &&
        invocation.isMethod) {
      if (throwOnAuthenticate) {
        return Future<bool>.error(
            PlatformException(code: auth_error.notAvailable));
      }
      return Future<bool>.value(authenticateResult);
    }
    return super.noSuchMethod(invocation);
  }
}

/// Minimal stub for the FirebaseAuth `User` interface — we only
/// need `isAnonymous` for the gate. Everything else throws if
/// touched (which is what we want; tests should never go through
/// the unmocked path).
class _StubUser implements User {
  _StubUser({required this.isAnonymous}) : uid = 'test-uid';
  @override
  final bool isAnonymous;
  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Future<void> _waitForHydration(BiometricService svc) async {
  for (var i = 0; i < 50; i++) {
    if (svc.isHydrated) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('BiometricService never hydrated');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('hydrates with isAvailable=true when device has biometric', () async {
      final stubAuth = _StubLocalAuthentication();
      final svc = BiometricService(
        auth: stubAuth,
        currentUserGetter: () => null,
      );
      expect(svc.isHydrated, isFalse);
      await _waitForHydration(svc);
      expect(svc.isAvailable, isTrue);
      expect(svc.isEnabled, isFalse);
      expect(svc.isUnlocked, isTrue,
          reason: 'gate is open when biometric is disabled');
    });

    test('isAvailable is false when device is not supported', () async {
      final stubAuth = _StubLocalAuthentication()..deviceSupported = false;
      final svc = BiometricService(
        auth: stubAuth,
        currentUserGetter: () => null,
      );
      await _waitForHydration(svc);
      expect(svc.isAvailable, isFalse);
    });

    test('isAvailable is false when no biometric is enrolled', () async {
      final stubAuth = _StubLocalAuthentication()..available = [];
      final svc = BiometricService(
        auth: stubAuth,
        currentUserGetter: () => null,
      );
      await _waitForHydration(svc);
      expect(svc.isAvailable, isFalse);
    });

    test('setEnabled(true) refuses for null user', () async {
      final stubAuth = _StubLocalAuthentication();
      final svc = BiometricService(
        auth: stubAuth,
        currentUserGetter: () => null,
      );
      await _waitForHydration(svc);
      final ok = await svc.setEnabled(true);
      expect(ok, isFalse);
      expect(svc.isEnabled, isFalse);
    });

    test('setEnabled(true) refuses for anonymous user', () async {
      final stubAuth = _StubLocalAuthentication();
      final svc = BiometricService(
        auth: stubAuth,
        currentUserGetter: () => _StubUser(isAnonymous: true),
      );
      await _waitForHydration(svc);
      final ok = await svc.setEnabled(true);
      expect(ok, isFalse);
      expect(svc.isEnabled, isFalse,
          reason: 'anonymous accounts must NOT enable biometric');
    });

    test('setEnabled(true) succeeds for real user when auth confirms', () async {
      final stubAuth = _StubLocalAuthentication();
      final svc = BiometricService(
        auth: stubAuth,
        currentUserGetter: () => _StubUser(isAnonymous: false),
      );
      await _waitForHydration(svc);
      final ok = await svc.setEnabled(true);
      expect(ok, isTrue);
      expect(svc.isEnabled, isTrue);
      expect(svc.isUnlocked, isTrue,
          reason: 'enabling mid-session leaves the gate open '
              "(the user just confirmed they're the right person)");

      // Persisted to SharedPreferences?
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('biometric_unlock_enabled'), isTrue);
    });

    test('setEnabled(true) is rejected when auth fails', () async {
      final stubAuth = _StubLocalAuthentication()..authenticateResult = false;
      final svc = BiometricService(
        auth: stubAuth,
        currentUserGetter: () => _StubUser(isAnonymous: false),
      );
      await _waitForHydration(svc);
      final ok = await svc.setEnabled(true);
      expect(ok, isFalse);
      expect(svc.isEnabled, isFalse,
          reason: 'a failed confirm must NOT leave the toggle on');
    });

    test('setEnabled(false) is unconditional', () async {
      // Pre-seed enabled state.
      SharedPreferences.setMockInitialValues(
          <String, Object>{'biometric_unlock_enabled': true});
      final stubAuth = _StubLocalAuthentication();
      final svc = BiometricService(
        auth: stubAuth,
        currentUserGetter: () => _StubUser(isAnonymous: false),
      );
      await _waitForHydration(svc);
      expect(svc.isEnabled, isTrue);
      // Disable should NOT trigger an authenticate prompt.
      stubAuth.throwOnAuthenticate = true;
      final ok = await svc.setEnabled(false);
      expect(ok, isTrue);
      expect(svc.isEnabled, isFalse);
    });

    test('lock() re-arms only when enabled and currently unlocked', () async {
      final stubAuth = _StubLocalAuthentication();
      final svc = BiometricService(
        auth: stubAuth,
        currentUserGetter: () => _StubUser(isAnonymous: false),
      );
      await _waitForHydration(svc);
      // Starts unlocked-because-disabled.
      expect(svc.isEnabled, isFalse);
      svc.lock();
      expect(svc.isUnlocked, isTrue,
          reason: 'lock() is a no-op while biometric is disabled');

      // Enable + verify unlocked, then lock.
      await svc.setEnabled(true);
      expect(svc.isUnlocked, isTrue);
      svc.lock();
      expect(svc.isUnlocked, isFalse);
      // Calling lock again is a no-op.
      svc.lock();
      expect(svc.isUnlocked, isFalse);
    });

    test('hydration of pre-existing enabled flag closes the gate', () async {
      // Simulates a returning user with biometric on — the gate must
      // start closed so the AuthGate routes to BiometricLockScreen.
      SharedPreferences.setMockInitialValues(
          <String, Object>{'biometric_unlock_enabled': true});
      final stubAuth = _StubLocalAuthentication();
      final svc = BiometricService(
        auth: stubAuth,
        currentUserGetter: () => _StubUser(isAnonymous: false),
      );
      await _waitForHydration(svc);
      expect(svc.isEnabled, isTrue);
      expect(svc.isUnlocked, isFalse,
          reason: 'returning user must re-pass biometric on launch');
    });

    test('hydration auto-skips gate when device removed biometric', () async {
      // Edge case from the file header: user enabled biometric on
      // a real account, then later removed Face ID from their
      // device. The probe finds isAvailable=false, so the gate
      // auto-opens (skip the BiometricLockScreen rather than
      // stranding them).
      SharedPreferences.setMockInitialValues(
          <String, Object>{'biometric_unlock_enabled': true});
      final stubAuth = _StubLocalAuthentication()..available = [];
      final svc = BiometricService(
        auth: stubAuth,
        currentUserGetter: () => _StubUser(isAnonymous: false),
      );
      await _waitForHydration(svc);
      expect(svc.isEnabled, isTrue);
      expect(svc.isAvailable, isFalse);
      expect(svc.isUnlocked, isTrue,
          reason: 'no enrolled biometric → gate opens, user not stranded');
    });
  });
}
