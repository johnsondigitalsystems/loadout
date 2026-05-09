// FILE: lib/widgets/recipe_qr_share_sheet.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// The "Share Recipe" modal bottom sheet. Renders three options on top of
// the active recipe row:
//
//   1. A 256×256 QR code that encodes the recipe in LoadOut's wire
//      format (via `RecipeQrService.encodeRecipe`). Another LoadOut
//      device's scanner reads it and lands the recipe in their library
//      with no network round-trip.
//   2. A "Copy share string" button that copies the literal `LO1:...`
//      payload to the clipboard. Useful for paste-import paths
//      (Discord / forum posts / future "paste a share string" UI).
//   3. The existing "Share PDF" call routed through the in-app
//      `RecipePdfService.share`. The QR sheet is additive — the PDF
//      flow is preserved, just relocated below the QR.
//
// Public surface:
//
//   * `showRecipeQrShareSheet(context, row)` — convenience helper
//     that opens the sheet via `showModalBottomSheet`. Matches the
//     pattern used elsewhere in the codebase (see
//     `lib/screens/recipes/recipes_list_screen.dart` `_showAddOptions`).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The recipe form's existing share PopupMenu only exposes PDF and plain-
// text formats. Adding QR as a third menu item would push the user into a
// fullscreen modal anyway, so the cleaner UX is to land all three options
// inside one sheet. This widget centralises that sheet so both the recipe
// form screen (single-recipe edit) and any future caller can re-use it.
//
// The sheet is purely declarative on top of the service: it does not own
// the recipe row, the database, or the share state machine. It receives
// a `UserLoadRow`, calls the encoder, and renders the result.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Encoder failures are first-class UX.** A reloader who pasted a
//    novel into the Notes field can produce a recipe that doesn't fit
//    in a QR. We catch [RecipeQrPayloadTooLargeError] explicitly and
//    render a friendly inline error with a CTA back to the PDF share
//    flow. Any other error falls through to a generic "Couldn't build
//    QR" message — share is never blocking.
//
// 2. **PDF share has to flush AutoSave first.** The recipe form delays
//    that flush in `_shareRecipe`; we deliberately don't mirror it here
//    because the sheet is invoked AFTER the row has already been
//    committed to disk. The host screen's AutoSave flush remains the
//    contract. If a future caller invokes the sheet without committing,
//    the PDF will be stale; we don't try to detect that here because
//    the sheet has no access to the AutoSave controller.
//
// 3. **Clipboard copy needs a "Copied" toast.** Without it, the user
//    has no idea the tap succeeded. We use `ScaffoldMessenger.of` to
//    show a transient SnackBar — the bottom-sheet itself stays on
//    screen so the user can copy + scan in one session.
//
// 4. **256x256 is the magic size.** Smaller renders make the QR
//    fragile on dim screens; bigger ones eat the full sheet height
//    on small phones. 256 logical pixels balances scan reliability
//    against bottom-sheet ergonomics.
//
// 5. **Pure white background is intentional.** `qr_flutter` will
//    happily render a QR onto a transparent / dark background, but
//    most camera apps need a light background to detect the
//    finder patterns reliably. We force `backgroundColor:
//    Colors.white` even in dark mode, with a small white card behind
//    the QR widget in case any padding pixels bleed.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/recipes/recipe_form_screen.dart — `_shareRecipe` routes
//   the share-icon tap into `showRecipeQrShareSheet`.
// - lib/screens/recipes/recipes_list_screen.dart — could plug in for
//   single-row "share via QR" affordance if we add long-press → QR.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Writes to the system clipboard via `Clipboard.setData`.
// - Pushes a SnackBar via `ScaffoldMessenger.of(context)`.
// - Delegates to `RecipePdfService.share` for the PDF tile, which writes
//   a temp file and surfaces the OS share sheet.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../database/database.dart';
import '../services/recipe_pdf_service.dart';
import '../services/recipe_qr_service.dart';

/// Open the Share Recipe modal bottom sheet for [row].
///
/// Returns when the sheet is dismissed (user tapped Cancel, scrim, or
/// otherwise popped). The callers don't currently need a return value;
/// the sheet's affordances each carry their own outcome (clipboard
/// write, OS share sheet for PDF).
Future<void> showRecipeQrShareSheet(
  BuildContext context,
  UserLoadRow row,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) {
      return _RecipeQrShareSheetBody(row: row);
    },
  );
}

class _RecipeQrShareSheetBody extends StatelessWidget {
  const _RecipeQrShareSheetBody({required this.row});

  final UserLoadRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qr = const RecipeQrService();

    // Try to encode the recipe up-front. The result is one of:
    //   * a `String` payload — happy path, render the QR.
    //   * a `RecipeQrPayloadTooLargeError` — too long for QR, surface
    //     the friendly fallback with a CTA back to PDF share.
    //   * any other error — defensive catch-all so a malformed row
    //     can't crash the modal (a SnackBar would dismiss with the
    //     sheet, leaving the user no path forward).
    Object? error;
    String? share;
    try {
      share = qr.encodeRecipe(row);
    } on RecipeQrPayloadTooLargeError catch (e) {
      error = e;
    } catch (e) {
      error = e;
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'Share Recipe',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                row.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            if (share != null) ...[
              _QrPanel(share: share),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Scan with another LoadOut device to import.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy share string'),
                onPressed: () => _copyShareString(context, share!),
              ),
            ] else
              _QrErrorPanel(error: error),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Share as PDF'),
              onPressed: () => _sharePdf(context),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyShareString(BuildContext context, String share) async {
    // Capture the messenger before any await to avoid using a possibly-
    // unmounted BuildContext after the clipboard call returns.
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: share));
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        content: Text('Share string copied to clipboard'),
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    // Pop the sheet first so the OS share-sheet popover (iPad)
    // anchors against the recipe form rather than the deactivated
    // modal context.
    Navigator.of(context).maybePop();
    // The PDF service captures its own iPad popover origin from the
    // host context once we re-await on the next frame. Using the form's
    // navigator context is fine because we just popped this sheet off
    // its top.
    await RecipePdfService().share(context, row);
  }
}

/// Pure-render QR panel: a white card with a 256×256 QR centered.
/// Forces white in both light and dark mode so the camera detector
/// always has a light background to lock onto. Wrapped in a `SizedBox`
/// so the bottom sheet can size itself stably even before the QR widget
/// has painted.
class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.share});

  final String share;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: SizedBox(
          width: 256,
          height: 256,
          child: QrImageView(
            data: share,
            // Level M holds ~2.3 KB at QR-40 — matches our payload cap
            // (`kRecipeQrMaxPayloadBytes`). Level L would let bigger
            // payloads through but is more error-prone outdoors.
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            backgroundColor: Colors.white,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

/// Inline error panel shown when the encoder couldn't build a QR for
/// this recipe (typically because the payload exceeded the QR-safe
/// budget). The PDF tile below is still tappable, so the user has a
/// path forward.
class _QrErrorPanel extends StatelessWidget {
  const _QrErrorPanel({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTooLarge = error is RecipeQrPayloadTooLargeError;
    final message = isTooLarge
        ? 'Recipe too long for a QR. Use file or PDF share instead.'
        : 'Could not build a QR for this recipe.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
