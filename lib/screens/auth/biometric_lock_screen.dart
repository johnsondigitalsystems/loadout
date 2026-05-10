// FILE: lib/screens/auth/biometric_lock_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Renders between Firebase Auth's "user is signed in" state and the
// HomeScreen when biometric unlock is enabled and the current
// session has not yet been unlocked. Shows an icon, the signed-in
// account's email (or "Guest account" for anonymous users), an
// "Unlock with biometrics" button, and a fall-through "Sign out"
// option.
//
// Auto-prompts on mount via a post-frame callback so the user sees
// the OS biometric sheet immediately without an extra tap; if the
// prompt is cancelled or fails, the screen stays put with the
// retry button visible. We never auto-retry — the user explicitly
// drives the next attempt.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The auth gate in `lib/app.dart` decides between three states:
//   * No Firebase user → [LoginScreen]
//   * Firebase user + biometric enabled + not unlocked this session
//     → this screen
//   * Firebase user + (biometric disabled OR already unlocked)
//     → [HomeScreen]
//
// Centralizing the lock-screen UI here keeps the gate small and
// gives the UI a single place to evolve (logo, app-version
// callout, sign-out fallback, future "use device PIN instead"
// wording).
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * **Auto-prompt on mount, not on rebuild.** The post-frame
//     callback fires the platform biometric sheet exactly once when
//     the screen first mounts. A naive "fire on every rebuild" would
//     re-trigger the sheet whenever the parent rebuilds (e.g. on a
//     theme change), which on iOS prompts the user multiple times.
//   * **Don't auto-retry on failure.** A failed / cancelled prompt
//     leaves `_failed = true` and the user sees the retry button.
//     Auto-retrying would feel hostile if the user explicitly
//     cancelled.
//   * **`signOut()` is the only "back button."** There's no way to
//     skip biometric without signing out — the gate is the gate. A
//     "Cancel and stay locked" option would be confusing because the
//     user would have nowhere to go (HomeScreen is on the other
//     side of the gate).
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/app.dart (`_AuthGate.build`) — renders this screen when the
//   gate's "biometric required" branch fires.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Triggers `BiometricService.authenticate(...)` (platform sheet).
// - Calls `AuthService.signOut()` from the fallback button.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Auto-prompt on mount — the user came back to the app expecting
    // to use it; an immediate biometric sheet feels native (mirrors
    // iOS Settings, banking apps, password managers).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      _runAuthenticate();
    });
  }

  Future<void> _runAuthenticate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await context
        .read<BiometricService>()
        .authenticate(reason: 'Unlock LoadOut');
    if (!mounted) return;
    setState(() {
      _busy = false;
      // On success the auth gate rebuilds away from this screen;
      // on failure we stay put with the retry button visible.
      _failed = !ok;
    });
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    await context.read<AuthService>().signOut();
    // The auth gate watches the auth-state stream and will rebuild to
    // [LoginScreen] once Firebase reports `null`. No navigation needed
    // here — the gate owns routing.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.read<AuthService>().currentUser;
    final email = user?.email;
    final isAnonymous = user?.isAnonymous ?? false;
    final accountLabel = isAnonymous
        ? 'Guest account'
        : (email != null && email.isNotEmpty ? email : 'Signed in');
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.fingerprint,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'LoadOut is locked',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    accountLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_failed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Authentication cancelled or failed. Try again, '
                        'or sign out to use a different account.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _runAuthenticate,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock with biometrics'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
