// FILE: lib/screens/recipes/recipe_import_source.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Canonical taxonomy of recipe import sources, plus a small helper
// that maps a file extension to the most-specific matching source
// kind. Used by `RecipeImportLandingScreen` to dispatch a picked
// file to the right per-source flow (spreadsheet wizard, LoadOut
// JSON re-import handler, Garmin .fit parser, etc.).
//
// The taxonomy is the source of truth for "what imports does
// LoadOut support" — every time we add a new source, an enum value
// lands here and the landing screen's routing switch gains a case.
// The same enum drives the source-taxonomy table in
// `Engineering.md` § 19.4.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Before Phase One Group 5, every "import a recipe" affordance had
// its own private routing logic split across `ImportOptionsSection`,
// the recipe form's inline Garmin .fit button, the onboarding deep
// links, and the Backup screen's "import" tile. Adding a new
// source required editing five different files and discovering
// every entry point by grep. Concentrating the taxonomy here gives
// us:
//
//   - A single enum to scan when adding a new source.
//   - A symmetric `detectKindFromFileExtension` helper that owns
//     the (filename → kind) decision. The landing screen calls
//     this; no per-tile copy of the extension table needs
//     maintaining.
//   - A clean separation between "source kind" (declarative,
//     listed here) and "source flow" (the actual UI in the
//     landing screen / per-source screen).
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// - Photos do not route through `detectKindFromFileExtension`.
//   They arrive from a different OS API (`image_picker`), not the
//   file picker — there's no extension to consult before the user
//   has captured. The landing screen has dedicated tiles for the
//   two photo paths (single + multi-page); the file-extension
//   helper returns null for image MIMEs.
// - LoadOut's own JSON re-import lives at the `.json` extension,
//   but a `.json` could also be foreign data (a spreadsheet
//   exported as JSON, an unrelated app's backup). The kind we
//   return here is "loadoutJson" — the per-source flow handles
//   the format sniff and falls back to a friendly error if the
//   payload doesn't match the LoadOut export shape.
// - Garmin .fit files appear under "Choose a file" but the
//   landing screen Pro-gates the route at handler invocation
//   time, not at extension-detection time. This keeps the kind
//   purely descriptive — Pro-gating is a flow concern, not a
//   taxonomy concern. (Phase Two completes the landing-screen
//   route for .fit; today it falls back to the recipe form's
//   inline Garmin .fit button — see `RecipeImportLandingScreen`
//   `_routeFor`.)
// - The three "Coming Soon" kinds (Word `.docx`, OneNote, Garmin
//   Xero photo) have NO live routing yet but ARE in the enum so
//   the source-taxonomy table in `Engineering.md` § 19.4 stays in
//   one place. The landing screen renders them as disabled tiles.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/screens/recipes/recipe_import_landing_screen.dart`
// - Engineering.md § 19.4 source-taxonomy table.
// - `test/recipe_import_source_test.dart` (filename mapping
//   regression).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure data types + a pure function.

/// Canonical recipe-import source kinds. Drives routing in
/// [RecipeImportLandingScreen] and the source-taxonomy table in
/// `Engineering.md` § 19.4.
///
/// Add a new kind by:
///   1. Append a value here.
///   2. Add a case in `RecipeImportLandingScreen._routeFor`.
///   3. Add a row in the source-taxonomy table in Engineering.md.
enum RecipeImportSourceKind {
  /// CSV (`.csv`) or Excel (`.xlsx` / `.xls`). Routes to
  /// `SpreadsheetImportScreen`.
  spreadsheet,

  /// Single photo (camera or gallery). Routes to
  /// `PhotoImportScreen` → `PhotoImportReviewScreen`. iOS/Android
  /// only.
  photoSingle,

  /// Multi-page batch from the gallery. Routes to the multi-page
  /// capture flow → `MultiPageImportReviewScreen`. iOS/Android
  /// only.
  photoMultiPage,

  /// LoadOut JSON re-import (a previous in-app local export).
  /// Routes to the existing JSON re-import handler.
  loadoutJson,

  /// QR code from another LoadOut user. Routes to
  /// `RecipeQrScanScreen`.
  qrCode,

  /// Paste from clipboard (CSV-shaped text). Materialised to a
  /// temp `.csv` file and routed through
  /// `SpreadsheetImportScreen(initialFile:)`.
  clipboard,

  /// Garmin Xero `.fit` chronograph export. Pro-gated. Today the
  /// landing-screen tile is informational only — the live flow
  /// lives on the recipe form's Pro tools section. Phase Two
  /// extracts the form-side handler so the landing-screen route
  /// can invoke it without a `RecipeFormScreen` state.
  garminFit,

  // ─── Coming Soon (no live routing yet) ────────────────────────

  /// Microsoft Word document (`.docx` / `.doc`). Phase Two.
  msWordDoc,

  /// Microsoft OneNote (`.one`). Phase Two; realistic path is
  /// "export OneNote page to `.docx`, then route as
  /// [msWordDoc]."
  msOneNote,

  /// Photo of a Garmin Xero chronograph display (OCR vs the
  /// `.fit` file). Phase Two; complement to [garminFit].
  garminXeroPhoto,
}

/// True when the kind has a live routing path in
/// [RecipeImportLandingScreen]. The Coming Soon kinds return
/// false; the landing screen renders them as disabled tiles.
bool isLiveRecipeImportKind(RecipeImportSourceKind kind) {
  switch (kind) {
    case RecipeImportSourceKind.spreadsheet:
    case RecipeImportSourceKind.photoSingle:
    case RecipeImportSourceKind.photoMultiPage:
    case RecipeImportSourceKind.loadoutJson:
    case RecipeImportSourceKind.qrCode:
    case RecipeImportSourceKind.clipboard:
    case RecipeImportSourceKind.garminFit:
      return true;
    case RecipeImportSourceKind.msWordDoc:
    case RecipeImportSourceKind.msOneNote:
    case RecipeImportSourceKind.garminXeroPhoto:
      return false;
  }
}

/// Examine a picked file's extension (case-insensitive) and
/// return the most-specific matching [RecipeImportSourceKind], or
/// null when the extension is unsupported.
///
/// Photos do NOT route through this helper — they arrive via a
/// separate OS API (the photo picker / camera) and bypass file-
/// extension detection. The landing screen has dedicated tiles
/// for the two photo paths.
///
/// Returns Coming Soon kinds (Word `.docx`, OneNote `.one`) for
/// the relevant extensions so callers can present an
/// informational "we're working on this" tile instead of a
/// silent "unsupported" snackbar.
RecipeImportSourceKind? detectKindFromFileExtension(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.csv') ||
      lower.endsWith('.xlsx') ||
      lower.endsWith('.xls')) {
    return RecipeImportSourceKind.spreadsheet;
  }
  if (lower.endsWith('.json')) return RecipeImportSourceKind.loadoutJson;
  if (lower.endsWith('.fit')) return RecipeImportSourceKind.garminFit;
  if (lower.endsWith('.docx') || lower.endsWith('.doc')) {
    return RecipeImportSourceKind.msWordDoc;
  }
  if (lower.endsWith('.one')) return RecipeImportSourceKind.msOneNote;
  // Image MIMEs / extensions intentionally NOT mapped here —
  // photos route through the dedicated photo picker tiles, not
  // through file-extension detection.
  return null;
}
