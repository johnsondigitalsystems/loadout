// FILE: lib/screens/recipes/recipe_qr_scan_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Fullscreen camera-based importer for LoadOut recipe QR codes. Wires
// `mobile_scanner`'s preview widget to:
//
//   1. Request camera permission via `permission_handler` on first push.
//      Denied state renders an inline "permission needed" banner with
//      an "Open Settings" link instead of a black camera preview.
//   2. Render the camera preview with a centered transparent scanning
//      rect overlay.
//   3. On every detected barcode, fast-reject anything that doesn't
//      start with the LoadOut magic prefix and surface a "Not a
//      LoadOut QR" snackbar (continues scanning).
//   4. On a matched LoadOut QR, decode via `RecipeQrService`, dedupe
//      against the local DB by `(name, cartridge, powder, charge)`,
//      insert via `RecipeRepository`, pop the screen, and surface
//      "Imported {recipe.name}" via the parent's snackbar.
//   5. Provide an explicit Cancel / back affordance.
//
// Public surface:
//
//   * `RecipeQrScanScreen` — the screen widget. Push it via
//     `Navigator.push(MaterialPageRoute(builder: (_) => const
//     RecipeQrScanScreen()))`. The other agent's "imports" section
//     will register this as one of its tile entries.
//   * `RecipeQrScanScreen.route()` — convenience constructor for the
//     other agent so it doesn't have to know the import path.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Recipe sharing is two-sided. The encode side (share sheet) is meaningless
// without a decode side. This screen is the decode counterpart — local-
// first, no-network, no-account, fully aligned with the privacy posture
// in CLAUDE.md § 13. The other agent is currently building the recipes-
// list "Imports" section; we publish this widget under a stable name so
// they can plug it in (or ship a TODO marker until they do).
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **`mobile_scanner` fires onDetect rapidly.** Each frame can produce
//    multiple `BarcodeCapture` events with the same payload. We hold an
//    `_isProcessing` latch around the dedupe + insert so a fast camera
//    doesn't try to insert the same recipe four times. The latch resets
//    on a timer (after a "Not a LoadOut QR" snackbar) so a user who
//    moved the QR out of frame and back in can rescan.
//
// 2. **Permission flow has three states.** `granted`, `denied`, and
//    `permanentlyDenied`. The first two re-prompt on the next request
//    call; the third needs a Settings deep-link because `request()`
//    silently returns the same denial. We branch on `isPermanentlyDenied`
//    after the call returns to decide whether to show the in-app
//    button or the Settings link.
//
// 3. **Soft-fail every async path.** Per CLAUDE.md and the user spec
//    we wrap the decode + insert in `safeAsync`. A corrupt QR or a DB
//    error never crashes the screen — it surfaces a snackbar and
//    continues scanning.
//
// 4. **Dedupe is best-effort.** We compare against `RecipeRepository.
//    allOnce()` rather than holding a stream subscription to keep the
//    screen lightweight. If the user creates a duplicate locally
//    between push and scan, we'll miss it; that's fine. The dedupe
//    key (`name + cartridge + powder + charge`) is intentionally
//    conservative — it catches "I shared this with myself" but won't
//    flag two genuinely different recipes that happen to share the
//    same recipe name.
//
// 5. **Lifecycle vs the camera.** mobile_scanner's controller holds
//    a native camera handle. We dispose it in `State.dispose` and
//    pause the stream when the screen loses foreground (handled by
//    the package automatically via `WidgetsBindingObserver`, but we
//    explicitly stop the stream on a successful import so the
//    camera light goes off before the navigator pop completes — UX
//    nicety, no functional impact).
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - Other agent's imports section (recipes-list / quick-add bottom sheet)
//   — once that section lands it will push `RecipeQrScanScreen`. Until
//   then this file is "registered" via direct import; an in-place
//   TODO marker in `recipes_list_screen.dart` reminds us to wire it.
// - test/recipe_qr_service_test.dart exercises the decode path used
//   here without instantiating the Flutter widget tree.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Opens the device camera via `mobile_scanner`. Stops on dispose or
//   on a successful scan.
// - Requests camera permission via `permission_handler`. May open the
//   OS Settings deep-link.
// - Reads from and writes to the local SQLite DB via
//   `RecipeRepository.allOnce` and `RecipeRepository.insert`.

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../repositories/recipe_repository.dart';
import '../../services/recipe_qr_service.dart';
import '../../widgets/range_day_safety.dart' show safeAsync;

/// Fullscreen QR scanner that imports a recipe from another LoadOut
/// device. Pop after a successful import; a `RecipeQrScanResult`
/// describing the imported recipe is returned to the caller.
class RecipeQrScanScreen extends StatefulWidget {
  const RecipeQrScanScreen({super.key});

  /// Convenience helper for callers who want a `MaterialPageRoute` they
  /// can hand to `Navigator.push` without re-importing the screen
  /// itself. Used by the other agent's imports section.
  static Route<RecipeQrScanResult?> route() {
    return MaterialPageRoute<RecipeQrScanResult?>(
      builder: (_) => const RecipeQrScanScreen(),
    );
  }

  @override
  State<RecipeQrScanScreen> createState() => _RecipeQrScanScreenState();
}

/// Returned by `Navigator.pop(context, value)` when an import succeeds.
/// Lets the caller surface their own snackbar / refresh stream.
class RecipeQrScanResult {
  const RecipeQrScanResult({
    required this.recipeId,
    required this.recipeName,
  });

  final int recipeId;
  final String recipeName;
}

enum _PermissionState {
  /// We haven't asked yet — permission_handler will be called inside
  /// initState's microtask.
  unknown,

  /// User granted camera access. Render the scanner.
  granted,

  /// User denied but the prompt can still re-fire. Render the in-app
  /// "Allow camera access" button.
  denied,

  /// User denied with the "Don't ask again" affordance, or the device
  /// otherwise blocks the prompt. Render an "Open Settings" deep link.
  permanentlyDenied,
}

class _RecipeQrScanScreenState extends State<RecipeQrScanScreen> {
  /// Handle to mobile_scanner's controller — disposed in [dispose].
  /// Constructed on demand inside the granted branch so we don't open
  /// the camera until permission is confirmed.
  MobileScannerController? _controller;

  _PermissionState _permission = _PermissionState.unknown;

  /// Latch that prevents the rapid-fire `onDetect` stream from queueing
  /// multiple decode passes for the same QR. Reset after every
  /// non-LoadOut frame so a user can rescan after panning the camera
  /// off and back on.
  bool _isProcessing = false;

  /// Cooldown timestamp on the "Not a LoadOut QR" snackbar so we don't
  /// flood the screen with one snackbar per frame when the user is
  /// pointing at a Wi-Fi QR for a few seconds.
  DateTime? _lastInvalidNotice;

  @override
  void initState() {
    super.initState();
    // Defer the permission check to the next microtask so the screen
    // can paint its loading state before the OS prompt fires.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePermission());
  }

  @override
  void dispose() {
    // ignore: discarded_futures
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _ensurePermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      if (status.isGranted) {
        _permission = _PermissionState.granted;
        _controller ??= MobileScannerController(
          // Scan only QR codes — we don't need 1D / data-matrix support.
          formats: const [BarcodeFormat.qrCode],
          detectionSpeed: DetectionSpeed.normal,
          // Default torch OFF; camera defaults to back.
          torchEnabled: false,
        );
      } else if (status.isPermanentlyDenied) {
        _permission = _PermissionState.permanentlyDenied;
      } else {
        _permission = _PermissionState.denied;
      }
    });
  }

  Future<void> _openSettings() async {
    // permission_handler exposes a uniform "deep-link to OS settings"
    // helper. Returns false on platforms that don't support it; we
    // surface a snackbar in that case rather than silently failing.
    final ok = await openAppSettings();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("Couldn't open Settings."),
        ),
      );
    }
  }

  /// Called for every barcode detection event. The flow:
  ///
  ///   1. Bail if we're already mid-process.
  ///   2. Pull the first non-empty payload off the capture event.
  ///   3. Quick-reject anything without the `LO1:` prefix and resume.
  ///   4. Decode + dedupe + insert under `safeAsync`.
  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    if (!mounted) return;
    String? candidate;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        candidate = raw;
        break;
      }
    }
    if (candidate == null) return;
    final qr = const RecipeQrService();
    if (!qr.lookLikesLoadOutQr(candidate)) {
      _showNotALoadOutSnack();
      return;
    }
    _isProcessing = true;
    // Unawaited intentionally — the processing future's outcome is
    // surfaced via setState / Navigator pop, not the return value.
    // ignore: discarded_futures
    _handleLoadOutCandidate(candidate);
  }

  /// Throttled "Not a LoadOut QR" snackbar so the user isn't bombarded
  /// when they're pointing at a Wi-Fi QR or billboard URL.
  void _showNotALoadOutSnack() {
    final now = DateTime.now();
    final last = _lastInvalidNotice;
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return;
    }
    _lastInvalidNotice = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        content: Text('Not a LoadOut QR'),
      ),
    );
  }

  Future<void> _handleLoadOutCandidate(String share) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.read<RecipeRepository>();
    final qr = const RecipeQrService();

    final outcome = await safeAsync<_ImportOutcome>(
      context,
      mounted: () => mounted,
      userMessage: 'Could not import that QR. Try scanning again.',
      body: () async {
        final decoded = qr.decodeShareString(share);
        final newKey = decoded.payload.dedupeKey();
        // Local dedupe — single round trip rather than a streaming
        // watcher because this is a one-shot decision per scan.
        final existing = await repo.allOnce();
        for (final row in existing) {
          final existingKey = qr.payloadFromRow(row).dedupeKey();
          if (existingKey == newKey) {
            return _ImportOutcome.duplicate(row.name);
          }
        }
        final id = await repo.insert(decoded.companion);
        return _ImportOutcome.inserted(id, decoded.payload.name);
      },
    );

    if (!mounted) return;
    if (outcome == null) {
      // safeAsync already surfaced a snackbar; resume scanning after a
      // short delay so the user can pan the camera and try again.
      _resumeAfterCooldown();
      return;
    }
    switch (outcome.kind) {
      case _ImportOutcomeKind.inserted:
        // Stop the camera before popping so the indicator light goes
        // off promptly. Errors here are non-fatal.
        // ignore: discarded_futures
        _controller?.stop();
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Imported ${outcome.recipeName}'),
          ),
        );
        Navigator.of(context).pop(
          RecipeQrScanResult(
            recipeId: outcome.recipeId!,
            recipeName: outcome.recipeName,
          ),
        );
        break;
      case _ImportOutcomeKind.duplicate:
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            content: Text(
              '"${outcome.recipeName}" is already in your library',
            ),
          ),
        );
        _resumeAfterCooldown();
        break;
    }
  }

  /// Re-enable the detection latch after a short delay so the rapid-
  /// fire `onDetect` stream doesn't immediately re-process the same
  /// frame. 800 ms is short enough for an attentive user but long
  /// enough that a held QR doesn't loop snackbars.
  void _resumeAfterCooldown() {
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Recipe QR'),
      ),
      body: switch (_permission) {
        _PermissionState.unknown => const Center(
            child: CircularProgressIndicator(),
          ),
        _PermissionState.denied => _PermissionDeniedView(
            permanent: false,
            onAllow: _ensurePermission,
            onOpenSettings: _openSettings,
          ),
        _PermissionState.permanentlyDenied => _PermissionDeniedView(
            permanent: true,
            onAllow: _ensurePermission,
            onOpenSettings: _openSettings,
          ),
        _PermissionState.granted => _ScannerView(
            controller: _controller!,
            onDetect: _onDetect,
          ),
      },
    );
  }
}

/// Result of one decode attempt. Lifted out so safeAsync can return a
/// single value type and the success / duplicate paths can both
/// surface their own snackbar copy.
enum _ImportOutcomeKind { inserted, duplicate }

class _ImportOutcome {
  const _ImportOutcome.inserted(int id, String name)
      : kind = _ImportOutcomeKind.inserted,
        recipeId = id,
        recipeName = name;

  const _ImportOutcome.duplicate(String name)
      : kind = _ImportOutcomeKind.duplicate,
        recipeId = null,
        recipeName = name;

  final _ImportOutcomeKind kind;
  final int? recipeId;
  final String recipeName;
}

class _ScannerView extends StatelessWidget {
  const _ScannerView({
    required this.controller,
    required this.onDetect,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: onDetect,
        ),
        // Centered scanning rect — purely cosmetic, gives the user a
        // clear "aim here" target. mobile_scanner detects barcodes
        // anywhere in frame; the rect is for human aim, not for the
        // detector.
        IgnorePointer(
          child: Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        // Bottom hint banner.
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Aim at a LoadOut recipe QR to import.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown when the user has not granted camera access. `permanent` true
/// flips the primary CTA to "Open Settings"; otherwise we expose the
/// in-app re-prompt button.
class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.permanent,
    required this.onAllow,
    required this.onOpenSettings,
  });

  final bool permanent;
  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = permanent
        ? 'Camera access was denied. Allow camera access in Settings to scan recipe QRs.'
        : 'Camera access is needed to scan recipe QRs shared by other LoadOut users.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Camera access needed',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (permanent)
              FilledButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open Settings'),
              )
            else
              FilledButton(
                onPressed: onAllow,
                child: const Text('Allow camera access'),
              ),
          ],
        ),
      ),
    );
  }
}
