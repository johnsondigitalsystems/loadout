// FILE: lib/services/auth_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Defines `AuthService`, a single Dart class that wraps Firebase Authentication
// and provides one method per sign-in flow that LoadOut supports. The rest of
// the app NEVER talks to the Firebase Auth SDK directly — it talks to this
// class. That keeps every auth-related side effect in one auditable place.
//
// What is "Firebase Auth"? Firebase is Google's managed backend toolkit.
// Firebase Authentication is the part that handles "is this person who they
// say they are?" — it provides hosted sign-in flows for Google, Apple, etc.,
// stores hashed passwords on Google's servers, and gives the app back an
// opaque "User" object with a stable user ID. The LoadOut binary never sees
// raw passwords — when a user types one into our login form, it goes
// straight from the device to Firebase's servers via HTTPS.
//
// Public surface, in the order the methods appear:
//
//   - `authStateChanges` — a stream that fires whenever the user signs in or
//     out. The widget tree subscribes to this so the app can switch between
//     LoginScreen and HomeScreen automatically.
//   - `currentUser` — the currently signed-in user (or null).
//   - `signIn(email, password)` — classic email/password sign-in.
//   - `signUp(email, password)` — creates a new email/password account and
//     fires off a verification email best-effort. We swallow verification-
//     email errors so a transient SMTP problem can't block account creation.
//   - `sendEmailVerification` / `sendPasswordResetEmail` — utilities.
//   - `sendEmailLink(email)` — passwordless flow. Mints a one-time URL and
//     emails it. The address is stashed in `SharedPreferences` so the app
//     can finish sign-in automatically when the link is tapped on this same
//     device. (See `tryCompleteEmailLink`.) `SharedPreferences` is the cross-
//     platform key-value store on top of NSUserDefaults / SharedPrefs — it
//     persists across app launches but not across uninstalls.
//   - `tryCompleteEmailLink(link)` — given a URL the OS handed us via the
//     deep-link plumbing in `lib/app.dart`, decides whether it's a Firebase
//     email-link sign-in URL and finishes the sign-in if so. Returns null
//     otherwise. The pending-email key is cleared on success.
//   - `signInAnonymously()` — creates an anonymous Firebase user. Useful for
//     letting people try the app without committing to an account.
//   - `signInWithGoogle()` — uses the `google_sign_in` 7.x API. The new API
//     is a singleton (`GoogleSignIn.instance`) that requires `initialize()`
//     before the first call; we lazy-init it on the first call to keep
//     startup cheap.
//   - `signInWithApple()` — see "WHY THIS IS HARDER THAN IT LOOKS". Two
//     codepaths because Apple's rules require a NATIVE sheet on iOS, but
//     Android can fall back to Firebase's web OAuth flow.
//   - `signInWithMicrosoft()` / `signInWithYahoo()` — both go through
//     Firebase's hosted OAuth handler. One-line wrappers.
//   - `signOut()` — calls Firebase signOut and (if Google was used) tells
//     `GoogleSignIn` to drop its cached account.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// In the layer cake:
//
//   UI (LoginScreen, HomeScreen)
//     ↓ provider
//   AuthService                       ← this file
//     ↓
//   FirebaseAuth + provider SDKs
//
// Three reasons this is its own file rather than scattered throughout the UI:
// 1. Mockability for tests — `AuthService` can be constructed with a fake
//    `FirebaseAuth` so widget tests can simulate sign-in without networking.
// 2. Single point of auditability — the privacy claim in the app says only
//    auth-related personal data leaves the device. Centralizing every Firebase
//    call here means a reviewer can verify that claim from one screen.
// 3. The seven providers each have their own subtle quirks (initialization,
//    error handling, platform branching). Keeping them out of UI code means
//    swapping implementations doesn't require touching screens.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. APPLE SIGN-IN BRANCHING. Apple's App Store rules require apps that offer
//    Google/Microsoft/etc. sign-in to ALSO offer "Sign in with Apple" via the
//    NATIVE iOS sheet — the web/OAuth fallback is not allowed on iOS. So on
//    iOS we use the `sign_in_with_apple` package to invoke the native sheet,
//    then convert the resulting credential into a Firebase
//    `OAuthProvider('apple.com').credential(...)`. On Android there's no
//    native Apple sheet to invoke, so we fall back to Firebase's hosted
//    OAuth flow via `signInWithProvider(AppleAuthProvider())`. Both routes
//    end at the same Firebase user object.
//
// 2. EMAIL-LINK COMPLETION RACE. The email link arrives at the app via the
//    OS's deep-link plumbing — on iOS via Universal Links, on Android via
//    App Links — handled in `lib/app.dart` using the `app_links` package.
//    For the same-device case the email is in `SharedPreferences`. For the
//    cross-device case (user opens email on phone B but started on phone A)
//    `tryCompleteEmailLink` returns `EmailLinkResult.needsEmail`, which the
//    UI uses to prompt for the email and then call
//    `completeEmailLinkWithEmail`.
//
// 3. GOOGLE SIGN-IN 7.X SINGLETON. The 7.x API replaced the per-instance
//    constructor with a global singleton that REQUIRES an `initialize()`
//    call before any other method. Calling any other method first throws.
//    `_googleInitialized` is the lazy-init flag.
//
// 4. SIGN-OUT ORDERING. We sign out of Firebase first, then Google. If we
//    did Google first and Firebase second, a stale Firebase auth state could
//    briefly show a "signed in" UI between the two calls.
//
// 5. ACTION CODE SETTINGS. The email-link callback URL points at the Firebase
//    Hosting page (`/auth/link`). Hosting then bounces the URL into the app
//    via Universal Links / App Links. If the AASA / assetlinks files are
//    misconfigured (or the Firebase Hosting deployment is stale), the link
//    opens a browser instead of the app, and `tryCompleteEmailLink` is never
//    called.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - /Users/general/Development/Applications/LoadOut/lib/app.dart provides an
//   `AuthService` to the widget tree and subscribes to `authStateChanges` to
//   pick between LoginScreen and HomeScreen. It also feeds the email-link
//   deep-link URL into `tryCompleteEmailLink`, and forwards the auth UID to
//   `PurchasesService.setAppUserId` so RevenueCat tracks the same identity.
// - /Users/general/Development/Applications/LoadOut/lib/screens/auth/login_screen.dart
//   calls every sign-in method depending on which button was tapped.
// - /Users/general/Development/Applications/LoadOut/lib/screens/home/home_screen.dart
//   calls `signOut()` from the menu.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Network: every method except `currentUser` and `authStateChanges` makes
//   HTTPS calls. `signInWithGoogle`, `signInWithApple` (iOS path), and
//   `sendEmailLink` may also briefly open native UI.
// - Persistence: `SharedPreferences` writes the pending-email-link address
//   under `auth.pendingEmailLinkEmail`. Firebase Auth itself persists the
//   signed-in user to its own secure store on the device.
// - Plugin calls: `firebase_auth`, `google_sign_in`, `sign_in_with_apple`.
// - Outbound email: `sendEmailVerification`, `sendPasswordResetEmail`,
//   `sendEmailLink` all trigger Firebase to send mail on our behalf.

import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Outcome of [AuthService.tryCompleteEmailLink].
///
/// Three-state result so callers can tell the difference between "this URL
/// wasn't an email-link sign-in URL at all" (ignore it), "we signed in
/// successfully" (let auth state propagate), and "we know this is an
/// email-link URL but we don't have the email locally — please prompt the
/// user and call [AuthService.completeEmailLinkWithEmail]" (cross-device
/// flow).
enum EmailLinkOutcome { notEmailLink, signedIn, needsEmail }

class EmailLinkResult {
  const EmailLinkResult._(this.outcome, {this.credential, this.link});

  /// The URL was not a Firebase email-link sign-in URL — caller should
  /// ignore it.
  factory EmailLinkResult.notEmailLink() =>
      const EmailLinkResult._(EmailLinkOutcome.notEmailLink);

  /// Sign-in completed; [credential] is the resulting Firebase user.
  factory EmailLinkResult.signedIn(UserCredential credential) =>
      EmailLinkResult._(EmailLinkOutcome.signedIn, credential: credential);

  /// The URL is a valid email-link URL but no pending email is stored on
  /// this device. Caller should prompt the user for their email and then
  /// call [AuthService.completeEmailLinkWithEmail] with [link] and the
  /// entered email.
  factory EmailLinkResult.needsEmail(String link) =>
      EmailLinkResult._(EmailLinkOutcome.needsEmail, link: link);

  final EmailLinkOutcome outcome;
  final UserCredential? credential;
  final String? link;
}

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  bool _googleInitialized = false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // ───────── Email / password ─────────

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUp(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Best-effort verification email; don't fail signup if it doesn't send.
    try {
      await cred.user?.sendEmailVerification();
    } catch (_) {
      // User can request a new verification email later.
    }
    return cred;
  }

  Future<void> sendEmailVerification() =>
      _auth.currentUser!.sendEmailVerification();

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // ───────── Email link (passwordless) ─────────

  static const _pendingEmailKey = 'auth.pendingEmailLinkEmail';

  static final ActionCodeSettings _emailLinkSettings = ActionCodeSettings(
    url: 'https://loadout-precision-reloading.web.app/auth/link',
    handleCodeInApp: true,
    iOSBundleId: 'com.johnsondigital.loadout',
    androidPackageName: 'com.johnsondigital.loadout',
    androidInstallApp: true,
    androidMinimumVersion: '1',
  );

  /// Send a sign-in link to [email]. The address is stashed locally so the
  /// app can complete sign-in automatically when the link is tapped on
  /// this device.
  Future<void> sendEmailLink(String email) async {
    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: _emailLinkSettings,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingEmailKey, email);
  }

  /// Inspect [link] and either complete email-link sign-in (same-device
  /// case, where the pending email is in `SharedPreferences`) or signal
  /// that the caller must prompt the user for their email (cross-device
  /// case).
  ///
  /// Three return cases:
  /// - [EmailLinkOutcome.notEmailLink] — [link] isn't a Firebase
  ///   email-link sign-in URL; caller should ignore it.
  /// - [EmailLinkOutcome.signedIn] — we had the pending email locally and
  ///   sign-in succeeded. The Firebase auth-state stream will propagate
  ///   the new user.
  /// - [EmailLinkOutcome.needsEmail] — the URL is valid but no pending
  ///   email exists on this device (the user requested the link on a
  ///   different device). Caller must prompt for the email and call
  ///   [completeEmailLinkWithEmail] with the URL and entered email.
  Future<EmailLinkResult> tryCompleteEmailLink(String link) async {
    if (!_auth.isSignInWithEmailLink(link)) {
      return EmailLinkResult.notEmailLink();
    }
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_pendingEmailKey);
    if (email == null) {
      return EmailLinkResult.needsEmail(link);
    }
    try {
      final cred = await _auth.signInWithEmailLink(
        email: email,
        emailLink: link,
      );
      await prefs.remove(_pendingEmailKey);
      return EmailLinkResult.signedIn(cred);
    } catch (_) {
      // The pending email didn't match the one the link was issued for
      // (e.g. user retyped a different address before opening the link).
      // Treat as cross-device: clear the stale pref and ask the user.
      await prefs.remove(_pendingEmailKey);
      return EmailLinkResult.needsEmail(link);
    }
  }

  /// Cross-device completion path: the user supplied [email] via a UI
  /// prompt because no pending email was saved on this device. Throws on
  /// failure (Firebase error, mismatched email, expired link) so the UI
  /// can surface the error inline.
  Future<UserCredential> completeEmailLinkWithEmail(
    String link,
    String email,
  ) async {
    final cred = await _auth.signInWithEmailLink(
      email: email,
      emailLink: link,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingEmailKey);
    return cred;
  }

  bool isSignInWithEmailLink(String link) =>
      _auth.isSignInWithEmailLink(link);

  // ───────── Anonymous ─────────

  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();

  // ───────── Google ─────────

  Future<UserCredential> signInWithGoogle() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: const ['email', 'profile'],
    );
    final auth = account.authentication;
    final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
    return _auth.signInWithCredential(credential);
  }

  // ───────── Apple ─────────
  // iOS uses the native Sign in with Apple sheet (required for App Store
  // approval when other social logins are present). Android falls back to
  // Firebase's web OAuth flow.

  Future<UserCredential> signInWithApple() async {
    // Native Sign in with Apple sheet is supported on iOS and macOS. On
    // Android (and any other platform) we fall back to Firebase's hosted
    // OAuth web flow.
    if (Platform.isIOS || Platform.isMacOS) {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final credential = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        accessToken: apple.authorizationCode,
      );
      return _auth.signInWithCredential(credential);
    }
    return _auth.signInWithProvider(AppleAuthProvider());
  }

  // ───────── Microsoft / Yahoo ─────────
  // Both go through Firebase's hosted OAuth flow.

  Future<UserCredential> signInWithMicrosoft() =>
      _auth.signInWithProvider(MicrosoftAuthProvider());

  Future<UserCredential> signInWithYahoo() =>
      _auth.signInWithProvider(YahooAuthProvider());

  // ───────── Sign out ─────────

  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Already signed out / not initialized properly — ignore.
      }
    }
  }
}
