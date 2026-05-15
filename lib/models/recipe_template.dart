// FILE: lib/models/recipe_template.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Typed `RecipeTemplate` data class + `RecipeTemplateDetailLevel`
// enum + the disclaimer banner string shared by every template.
//
// A recipe template is one curated "starting point" load — a
// caliber + powder + charge + bullet + weight + COAL/CBTO + notes
// drawn from published reloading data so a beginner can see a
// working starting load instead of a blank form. Templates ride
// the seed-data pipeline: shipped as JSON in
// `assets/seed_data/recipe_templates.json`, seeded into the
// `RecipeTemplates` drift table on first run, read at runtime via
// `RecipeRepository.allTemplates` / `templatesByDetailLevel`.
//
// Pre-Phase-Two (Group 1, 2026-05-15), templates lived as a static
// const Dart list `kRecipeTemplates` in
// `lib/data/recipe_templates.dart`. Adding a template required a
// store release. The seed-data path lets manufactures (or LoadOut
// engineering) push corrections / additions via a manifest bump
// and a Firebase Storage upload, no App Store push needed.
//
// The `recommendedDetailLevel` annotation is new in this revision.
// It lets the picker UI (today: Quick Add only; future: the unified
// form after Phase Three's Quick → Regular bridge collapse) filter
// templates by the form's current mode. A "starter load" template
// that fills the load-defining fields only is `quick`; a
// "match-tested load" with seating depth, neck-tension settings,
// and process notes is `extended`.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Templates are reference data, not code. Pre-launch we can rewrite
// them whenever the catalog needs to grow. Post-launch we need a
// non-store-release path to ship "we forgot to add a 6.5 PRC
// starter" — that's the seed-data live update mechanism (see
// `lib/services/seed_updater.dart` and Engineering.md § 5).
//
// Hosting the disclaimer string as a `static const` on the model
// (rather than a top-level const) lets us version it alongside the
// templates themselves later if a per-template disclaimer ever
// needs to specialise (e.g. for subsonic loads where pressure
// considerations are different).
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Liability is the whole point of the disclaimer.** Every
//    template surfaces the disclaimer string in a banner the user
//    has to acknowledge before applying. Don't drop it from the UI
//    as "obvious" — it's what keeps these from being interpreted
//    as load advice. The Quick Add picker reads
//    `RecipeTemplate.disclaimer` directly. Removing the field
//    would break that contract.
//
// 2. **Charge values are intentionally MID-RANGE, not max.** Each
//    template's `powderChargeGr` is pulled from a published
//    manual's mid-range entry. If we ever programmatically derive
//    these from a load-data table, the derivation must respect
//    this rule.
//
// 3. **Templates are NOT migrated as User Loads on first run.**
//    They stay in the catalog table until the user picks one in
//    Quick Add, at which point the resulting row is a normal
//    `UserLoadRow`. This avoids polluting the user's recipe list
//    with values they never picked.
//
// 4. **COAL xor CBTO at template apply time.** Phase One Group 4
//    added the `cbtoIn` field. Quick Add's apply-template logic
//    prefers `coalIn` when both are set (manuals quote COAL more
//    often). All five shipping templates use `coalIn`; the
//    `cbtoIn` field stays null on them by default.
//
// 5. **`recommendedDetailLevel` defaults to `quick` on apply.** The
//    Phase Three queue includes a Quick → Regular bridge redesign
//    that may collapse Quick + Standard into one form with a mode
//    flag. The annotation lets the picker filter templates by
//    mode without needing to ship a new template field then.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/repositories/recipe_repository.dart` — `allTemplates()`
//   and `templatesByDetailLevel(...)` map drift rows back into
//   `RecipeTemplate` instances.
// - `lib/database/seed_loader.dart` — `_seedRecipeTemplates()`
//   parses the seed JSON via `RecipeTemplate.fromJson`.
// - `lib/screens/recipes/quick_add_recipe_screen.dart` — the
//   template picker.
// - `test/recipe_template_test.dart` — JSON round-trip + detail-
//   level enum coverage.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure data class + enum + static const.

/// Scope of fields a [RecipeTemplate] populates. Used by the picker
/// UI (today: Quick Add; future: unified form mode toggle after
/// Phase Three) to filter templates by current form mode so a
/// pen-and-paper notebook user doesn't see a 30-field "match
/// tested" template in Quick mode.
///
/// The persisted key (in the `RecipeTemplates` drift table's
/// `recommendedDetailLevel` column) is the enum's [name] string —
/// `RecipeTemplateDetailLevel.quick.name == 'quick'`. Don't change
/// a name without a migration step.
enum RecipeTemplateDetailLevel {
  /// Load-defining fields only (caliber, powder, charge, bullet,
  /// weight, COAL/CBTO, notes). Suitable for Quick mode and for
  /// the unified form's "Core" detail level.
  quick,

  /// Adds load-development metadata (charge tolerance, primer
  /// size, seating depth). Maps to the unified form's "Core"
  /// detail level after Phase Three's collapse.
  core,

  /// Adds process notes, equipment, lot context. Maps to the
  /// unified form's "Extended" detail level.
  extended,

  /// Full template with every field including pressure indicators
  /// and process equipment. Maps to the unified form's "Full"
  /// detail level.
  full,
}

/// One starter recipe surfaced from the Quick Add flow. All values
/// are starting points only — the [disclaimer] string is shown
/// verbatim in the UI to make that explicit.
///
/// Constructed from JSON via [RecipeTemplate.fromJson]; built back
/// from a drift `RecipeTemplateRow` via `RecipeRepository._rowToTemplate`.
class RecipeTemplate {
  const RecipeTemplate({
    required this.id,
    required this.name,
    required this.recommendedDetailLevel,
    this.description,
    this.caliber,
    this.powder,
    this.powderChargeGr,
    this.bullet,
    this.bulletWeightGr,
    this.coalIn,
    this.cbtoIn,
    this.useCase,
    this.notes,
  });

  /// Stable identifier used as a dropdown / radio value. Never
  /// user-facing. Pinned across catalog updates so a future-version
  /// of a template (e.g. corrected charge weight) overwrites the
  /// existing row instead of duplicating.
  final String id;

  /// Display name shown in the template picker.
  final String name;

  /// Optional one-line note shown under the name in the picker.
  /// Today no shipping template uses this — but seed-JSON updates
  /// can add it without a schema change.
  final String? description;

  /// Scope of fields this template populates. See
  /// [RecipeTemplateDetailLevel] for semantics.
  final RecipeTemplateDetailLevel recommendedDetailLevel;

  // All pre-fill fields are nullable. A template that only knows a
  // caliber + powder + charge is still useful — Quick Add applies
  // every non-null field and leaves the rest blank.

  final String? caliber;
  final String? powder;
  final double? powderChargeGr;
  final String? bullet;
  final double? bulletWeightGr;

  /// Cartridge overall length in inches. Optional. When non-null,
  /// Quick Add's apply-template logic sets the COAL/CBTO axis to
  /// COAL and populates the dimension field with this value.
  final double? coalIn;

  /// Cartridge base-to-ogive in inches. Optional. Added by Phase
  /// One Group 4 for the COAL/CBTO axis toggle. When [coalIn] is
  /// null and this is non-null, Quick Add switches the axis to
  /// CBTO. When both are non-null, COAL wins (manuals quote COAL
  /// more often than CBTO; CBTO is bullet-comparator-dependent).
  /// All five shipping templates use [coalIn]; this stays null on
  /// them.
  final double? cbtoIn;

  /// Free-form intended use ("match", "practice", "hunting", etc.).
  /// Pre-fills the Use Case field on the resulting recipe.
  final String? useCase;

  /// Pre-filled notes for the resulting recipe. Often includes the
  /// published-data source the template was drawn from.
  final String? notes;

  /// Disclaimer banner shown above the template picker. Hosting
  /// the string on the class (rather than a top-level const) lets
  /// us version it alongside templates later if needed; today the
  /// same string applies to every template.
  ///
  /// The Quick Add picker reads this directly and renders it in a
  /// banner the user sees before applying a template. Reloading
  /// manuals are the source of truth — never the app, never these
  /// templates.
  static const String disclaimer =
      'These values are starting points from published reloading data. '
      'ALWAYS verify against your current reloading manual before loading. '
      'Never start at maximum charge.';

  /// Parse a single template object from the seed-JSON shape.
  /// Throws [ArgumentError] when [recommendedDetailLevel] is an
  /// unknown enum value — the seed file is the source of truth
  /// and silently degrading to a default would hide a typo.
  factory RecipeTemplate.fromJson(Map<String, dynamic> json) {
    final levelName = json['recommendedDetailLevel'] as String?;
    final level = levelName == null
        ? RecipeTemplateDetailLevel.quick
        : _detailLevelFromName(levelName);
    return RecipeTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      recommendedDetailLevel: level,
      caliber: json['caliber'] as String?,
      powder: json['powder'] as String?,
      powderChargeGr: (json['powderChargeGr'] as num?)?.toDouble(),
      bullet: json['bullet'] as String?,
      bulletWeightGr: (json['bulletWeightGr'] as num?)?.toDouble(),
      coalIn: (json['coalIn'] as num?)?.toDouble(),
      cbtoIn: (json['cbtoIn'] as num?)?.toDouble(),
      useCase: json['useCase'] as String?,
      notes: json['notes'] as String?,
    );
  }

  static RecipeTemplateDetailLevel _detailLevelFromName(String name) {
    for (final v in RecipeTemplateDetailLevel.values) {
      if (v.name == name) return v;
    }
    throw ArgumentError(
      'Unknown recommendedDetailLevel "$name" — expected one of '
      '${RecipeTemplateDetailLevel.values.map((v) => v.name).join(', ')}',
    );
  }
}
