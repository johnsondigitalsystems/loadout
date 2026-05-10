// FILE: lib/services/share_handler_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Single-instance service that listens for inbound shared text from the
// OS share sheet (iOS Share Extension or Android `ACTION_SEND` intent
// with `text/plain` mime type) and routes the text into LoadOut's
// recipe-import flow.
//
// The user-facing path:
//
//   1. User opens a note in Apple Notes (or any text-share-capable
//      app — OneNote, Bear, Obsidian, Drafts, etc.).
//   2. User taps Share, picks LoadOut from the share sheet.
//   3. Native side (iOS Share Extension / Android intent filter)
//      passes the text to the Flutter app via the `share_handler`
//      plugin.
//   4. This service receives a `SharedMedia` object with `content`
//      set to the shared text.
//   5. Service builds a `RecipeParser` from the on-device catalog
//      (via `TextImportService.buildParser`), parses the text into
//      a `RecipeDraft`, and pushes `PhotoImportReviewScreen` onto
//      the navigator with `imagePath: null`.
//
// Two delivery channels:
//   * `getInitialSharedMedia()` — fired once at app boot when the
//     user shared INTO a not-yet-running app (cold start). Drained
//     once via `resetInitialSharedMedia()` so a second `start()` on
//     the same launch doesn't re-pop the same review.
//   * `sharedMediaStream` — fires while the app is already running
//     (warm start). We listen for the lifetime of the service.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Apple Notes is a closed sandbox app — the only public path to get
// its text out is the iOS Share Sheet. Asking the user to "export
// to .txt and import that file" works for OneNote / Word, but Apple
// Notes has no Export → Text option. The Share Sheet IS the
// supported affordance, so we receive on the other end.
//
// The same path covers any other notes / docs app the user has
// installed: tap Share in Bear / Obsidian / Drafts / Word /
// OneNote-on-iOS → pick LoadOut → recipe imports immediately.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Cold-start vs warm-start delivery requires both a one-shot
//     `getInitialSharedMedia()` call AND a long-lived
//     `sharedMediaStream` listener. Mishandling the cold-start path
//     re-fires the initial share every time the app restarts (the
//     plugin keeps it cached until you call
//     `resetInitialSharedMedia()`).
//   * The native side delivers a `SharedMedia` object that may carry
//     either text content (`content`) OR file attachments (PDFs,
//     images). For now we handle text only — file attachments would
//     route through the existing PDF / photo flows but we're not
//     wiring that up in this pass to keep the share-extension
//     entitlement minimal.
//   * Routing requires a navigator. We use the app-wide
//     `LoadOutApp.navigatorKey` so the service can run from
//     `_DisclaimerGate.initState` without needing a `BuildContext`
//     stashed somewhere awkward.
//   * Building the parser requires reading from the component
//     catalog (a Provider lookup). We grab a `BuildContext` off the
//     navigator key; that context's `read<>` resolves the providers
//     mounted by `LoadOutApp.MultiProvider` above. This works as
//     long as the listener runs after the providers are mounted —
//     `start()` is called from `_DisclaimerGate.initState`, which
//     itself is mounted under `MultiProvider`, so by then the
//     providers are live.
//   * Plugin platform support: iOS + Android. On macOS / web /
//     Windows / Linux the plugin's `MissingPluginException` would
//     throw on first call; `start()` short-circuits on those
//     platforms so the rest of the app stays clean.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/app.dart::_DisclaimerGate` — calls `ShareHandlerService
//   .instance.start()` once after the user has accepted the
//   disclaimer (so we don't push a recipe-import screen behind the
//   disclaimer modal).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Subscribes to the `share_handler` plugin's stream for the app's
//   lifetime. Single subscription; no leak.
// - Calls `ShareHandler.instance.resetInitialSharedMedia()` after
//   the cold-start payload is consumed so a relaunch doesn't
//   re-deliver it.
// - Pushes `PhotoImportReviewScreen` onto the global navigator.
// - Reads the on-device component catalog to build a
//   `RecipeParser` (via `TextImportService.buildParser`).

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';

import '../app.dart';
import '../screens/recipes/photo_import_review_screen.dart';
import 'text_import_service.dart';

class ShareHandlerService {
  ShareHandlerService._();
  static final ShareHandlerService instance = ShareHandlerService._();

  StreamSubscription<SharedMedia>? _sub;
  bool _started = false;

  /// Wire up the listener. Safe to call more than once — second + N
  /// calls are no-ops. Short-circuits on platforms where
  /// `share_handler` doesn't ship a native impl (macOS / web /
  /// desktop) so the rest of the app stays clean.
  Future<void> start() async {
    if (_started) return;
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      // Plugin not supported on this platform; mark started so
      // future calls early-out without trying again.
      _started = true;
      return;
    }
    _started = true;

    final handler = ShareHandler.instance;

    // Cold-start path: anything the user shared into the app while
    // it wasn't running lands here. Drain once so a relaunch doesn't
    // re-fire the same payload.
    try {
      final initial = await handler.getInitialSharedMedia();
      if (initial != null) {
        await _handleSharedMedia(initial);
        await handler.resetInitialSharedMedia();
      }
    } catch (_) {
      // Plugin missing or transient native failure — don't crash
      // the app; the warm-start path still has a chance to fire.
    }

    // Warm-start path: shares that arrive while the app is already
    // running.
    _sub = handler.sharedMediaStream.listen(
      _handleSharedMedia,
      onError: (_) {
        // Tolerate stream errors silently — the app keeps working,
        // the user can re-share if needed.
      },
    );
  }

  /// One delivery point for both cold-start and warm-start payloads.
  /// Pulls the text content (if any), parses it via the standard
  /// recipe parser, and pushes the review screen on the global
  /// navigator. File attachments are intentionally ignored in this
  /// pass — wiring them through would require extra Share Extension
  /// entitlements and we cover the same files via the dedicated
  /// import sources screen.
  Future<void> _handleSharedMedia(SharedMedia media) async {
    final text = media.content?.trim();
    if (text == null || text.isEmpty) return;

    final navigator = LoadOutApp.navigatorKey.currentState;
    final context = LoadOutApp.navigatorKey.currentContext;
    if (navigator == null || context == null) {
      // Navigator isn't mounted yet (very early boot). Drop the
      // share — the cold-start delivery should re-fire on the next
      // launch. (We don't try to queue here; queuing across the
      // navigator-mount boundary adds complexity for a rare case.)
      return;
    }

    try {
      final parser = await TextImportService.buildParser(context);
      final draft = parser.parse(text);
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => PhotoImportReviewScreen(
            draft: draft,
            imagePath: null,
            ocrText: text,
          ),
        ),
      );
    } catch (_) {
      // Parser construction or push failed — surface a snackbar via
      // the topmost ScaffoldMessenger if we can find one. The
      // context is fetched FRESH from the navigator key (not held
      // across the await above), so the standard "build context
      // across async gap" lint is a false positive here.
      final messengerCtx = LoadOutApp.navigatorKey.currentContext;
      if (messengerCtx != null) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.maybeOf(messengerCtx)?.showSnackBar(
          const SnackBar(
            content: Text("Couldn't import that shared text."),
          ),
        );
      }
    }
  }

  /// Test-only teardown. Drops the stream subscription.
  @visibleForTesting
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
