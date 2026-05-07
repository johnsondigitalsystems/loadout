// FILE: lib/data/recipe_templates.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Holds the static "starter recipe" templates surfaced from the Quick Add
// flow. A template is a small, opinionated set of starting values
// (cartridge + a common powder + a typical mid-range charge + a popular
// bullet) drawn from published reloading data, so a beginner can see a
// working starting load instead of staring at a blank form.
//
// Templates are NOT a database table. They ship as `const` data with the
// binary because:
//   * The set is small and curated. Six entries today, never going to be
//     hundreds. A SQLite table would be overkill.
//   * No user editing is intended. If a user wants to tweak, they pick
//     the template, then hit Save and the resulting User Load is fully
//     editable like any other.
//   * Updates ride along with app releases via the normal binary update
//     channel — same way the Reloading Glossary works.
//
// Every template carries a `disclaimer` field. The Quick Add screen
// surfaces this verbatim in a banner the user has to acknowledge before
// the values are persisted as a recipe. Reloading manuals are the source
// of truth — never the app, never these templates.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// LoadOut's marketing pivot toward the 66% pen-and-paper reloader cohort
// requires the Quick Add flow to produce a working recipe in under 30
// seconds. A blank form fails for someone who hasn't yet decided which
// powder/charge to start at — they need a known-good reference point.
//
// Templates fill that gap with a five-minute affordance: pick a template,
// see fields populate, edit anything that doesn't fit, save. The
// disclaimer is what keeps this from being load advice — we say "verify
// in your manual" loud enough that nobody confuses a starter value for a
// recommendation.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/recipes/quick_add_recipe_screen.dart — the only consumer.
//   Reads `kRecipeTemplates`, displays the picker dropdown, and applies
//   the chosen template's values to the in-progress form.

/// One starter recipe surfaced from the Quick Add flow. All values are
/// starting points only — the [disclaimer] field is shown verbatim in
/// the UI to make that explicit.
class RecipeTemplate {
  const RecipeTemplate({
    required this.id,
    required this.name,
    required this.caliber,
    required this.powder,
    required this.powderChargeGr,
    required this.bullet,
    required this.bulletWeightGr,
    this.coalIn,
    required this.disclaimer,
    this.useCase,
    this.notes,
  });

  /// Stable identifier used as a dropdown value. Never user-facing.
  final String id;

  /// Display name shown in the template picker.
  final String name;

  final String caliber;
  final String powder;
  final double powderChargeGr;
  final String bullet;
  final double bulletWeightGr;

  /// Cartridge overall length in inches. Optional — some templates leave
  /// this blank and let the reloader measure their own.
  final double? coalIn;

  /// Free-form intended use ("match", "practice", "hunting", etc.).
  /// Pre-fills the Use Case field on the resulting recipe.
  final String? useCase;

  /// Pre-filled notes for the resulting recipe. Often includes the
  /// published-data source the template was drawn from.
  final String? notes;

  /// Mandatory disclaimer surfaced in the Quick Add screen. The current
  /// copy is intentionally identical across templates — keeping it as a
  /// per-template field lets us specialise wording later (e.g. for
  /// subsonic loads) without restructuring the model.
  final String disclaimer;
}

/// Generic disclaimer applied to every shipping template. Pulled out as
/// a const so the Quick Add screen can surface it in the no-template
/// case too (general reminder above the form).
const String kRecipeTemplateDisclaimer =
    'These values are starting points from published reloading data. '
    'ALWAYS verify against your current reloading manual before loading. '
    'Never start at maximum charge.';

/// The shipping template set. Order is curated — most popular cartridges
/// first.
const List<RecipeTemplate> kRecipeTemplates = <RecipeTemplate>[
  RecipeTemplate(
    id: '6_5_creedmoor_h4350_140eldm',
    name: '6.5 Creedmoor — H4350 + 140gr ELD-M',
    caliber: '6.5 Creedmoor',
    powder: 'Hodgdon H4350',
    powderChargeGr: 41.5,
    bullet: 'Hornady ELD Match 140gr',
    bulletWeightGr: 140,
    coalIn: 2.800,
    useCase: 'match',
    notes: 'Popular match starting load. Verify against Hodgdon and '
        'Hornady published data for your specific brass and primer.',
    disclaimer: kRecipeTemplateDisclaimer,
  ),
  RecipeTemplate(
    id: '308_win_varget_168smk',
    name: '.308 Winchester — Varget + 168gr SMK',
    caliber: '.308 Winchester',
    powder: 'Hodgdon Varget',
    powderChargeGr: 43.0,
    bullet: 'Sierra MatchKing 168gr',
    bulletWeightGr: 168,
    coalIn: 2.800,
    useCase: 'match',
    notes: 'Classic .308 match starting load. Verify against Hodgdon and '
        'Sierra published data for your specific brass and primer.',
    disclaimer: kRecipeTemplateDisclaimer,
  ),
  RecipeTemplate(
    id: '223_rem_h335_55fmj',
    name: '.223 Rem — H335 + 55gr FMJ',
    caliber: '.223 Remington',
    powder: 'Hodgdon H335',
    powderChargeGr: 24.5,
    bullet: 'FMJ 55gr',
    bulletWeightGr: 55,
    coalIn: 2.250,
    useCase: 'practice',
    notes: 'Common .223 plinking / practice starting load. Verify against '
        'Hodgdon published data for your specific brass and primer.',
    disclaimer: kRecipeTemplateDisclaimer,
  ),
  RecipeTemplate(
    id: '300blk_subsonic_h110_220sierra',
    name: '.300 Blackout subsonic — H110 + 220gr Sierra',
    caliber: '.300 AAC Blackout',
    powder: 'Hodgdon H110',
    powderChargeGr: 10.5,
    bullet: 'Sierra MatchKing 220gr',
    bulletWeightGr: 220,
    coalIn: 2.100,
    useCase: 'practice',
    notes: 'Subsonic starting load. Subsonic loads have unique pressure '
        'considerations — verify carefully against Hodgdon and Sierra '
        'published data.',
    disclaimer: kRecipeTemplateDisclaimer,
  ),
  RecipeTemplate(
    id: '9mm_titegroup_124fmj',
    name: '9mm Luger — Titegroup + 124gr FMJ',
    caliber: '9mm Luger',
    powder: 'Hodgdon Titegroup',
    powderChargeGr: 4.4,
    bullet: 'FMJ 124gr',
    bulletWeightGr: 124,
    coalIn: 1.150,
    useCase: 'practice',
    notes: 'Popular 9mm range starting load. Verify against Hodgdon '
        'published data for your specific bullet and brass.',
    disclaimer: kRecipeTemplateDisclaimer,
  ),
];
