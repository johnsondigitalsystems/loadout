// FILE: lib/data/reticle_tags.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Builds a brand-agnostic search-tag set for any reticle in the catalog,
// without requiring a tags column on the `Reticles` table or a `tags`
// field in `assets/seed_data/reticles.json` / `reticles_v2.json`. The
// tags are derived purely from a reticle's `model`, `family`, and
// `manufacturer` strings -- the data we already have on every row --
// plus a small hand-curated archetype-keyword table that promotes
// generic descriptors ("dense mil tree", "compact mil hash", "combat",
// "red dot") to dedicated tags so a search by job-to-be-done filters
// the catalog regardless of what the row's model literally says.
//
// Public API:
//
//   `Set<String> deriveReticleTags({manufacturer, model, family})`
//      -- returns the lowercase tags for one reticle. Always non-empty
//      (every reticle gets at least the manufacturer and model words).
//
//   `bool reticleMatchesQuery(query, manufacturer, model, family)`
//      -- returns true when the query (already lowercased + trimmed)
//      matches any tag, the manufacturer, the model, the family, or
//      the concatenated "manufacturer model family" haystack. The
//      picker uses this single helper instead of building the
//      haystack manually so the matching rule stays consistent.
//
//   `kPopularReticleTags`
//      -- ordered list of the LoadOut archetype categories every
//      shooter recognises (default mil tree, dense mil tree, MOA,
//      mil hash, combat, hunting BDC, red dot, holographic, mil-dot,
//      plex). The picker renders these as a "Popular reticles"
//      section at the top of the list -- tapping one filters the
//      picker to every reticle whose tag-set contains the popular
//      tag.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The catalog rewrite (see `assets/seed_data/reticles_v2.json`)
// replaced every branded reticle with LoadOut-original archetype
// reticles plus public-domain patterns. A user searching for "dense
// mil tree" or "christmas tree" should land on the right LoadOut
// archetype regardless of which way the catalog's `family` string
// was worded. Tags resolve this without a DB migration.
//
// Computing tags in code (rather than persisting them) means we never
// have to backfill 250+ existing reticles or worry about the JSON-
// based assets-present test (`test/assets_present_test.dart`) failing
// on missing tag fields. New reticles automatically inherit the
// inferred tags the moment they ship.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Reticle naming is wildly inconsistent. "Mil-Dot", "MIL-DOT",
//     "MIL Dot", "Mil dot", "Mil-Hash", "MILHASH" all refer to the
//     same family of reticles. We normalize aggressively (lower-case,
//     strip punctuation, collapse whitespace) before tagging.
//   * The archetype-keyword table promotes generic descriptors
//     ("compact", "medium", "dense", "christmas", "combat", "bdc",
//     "hunting", "red dot", "holographic") to dedicated tags so
//     "dense" filters to every dense tree archetype regardless of
//     whether the row's family says "Mil reticles" or "MOA reticles".
//   * A single reticle can land in multiple popular buckets -- e.g.
//     `loadout_mil_tree_christmas` belongs to both "christmas-tree"
//     and "dense-mil-tree". We don't deduplicate at the tag level,
//     only at the popular-section row level (so a reticle never
//     appears twice in one rendered list).
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/widgets/reticle_picker.dart` -- the picker calls
//   [reticleMatchesQuery] for the search box and [deriveReticleTags]
//   for the "Popular reticles" filter chips.
// - Tests under `test/` -- the tag-derivation logic should stay pure
//   so future tests can assert specific name -> tag mappings.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure functions over strings.

/// One popular-reticle entry the picker renders as a chip / row at the
/// top of the list. The `tag` is the canonical lowercase token used to
/// filter the catalog; the `label` is the user-facing display name; the
/// `description` is a one-liner that appears as a subtitle on the chip
/// (kept short -- it's a hint, not documentation).
class PopularReticleEntry {
  const PopularReticleEntry({
    required this.tag,
    required this.label,
    required this.description,
  });

  final String tag;
  final String label;
  final String description;
}

/// Archetype-keyword table. Maps a model / family / manufacturer
/// keyword (matched against the lowercased, punctuation-stripped
/// haystack) to one or more dedicated tags that should be added to
/// every reticle whose haystack contains that keyword.
///
/// Most rows in the catalog already include the relevant noun in
/// their `family` ("LoadOut Mil reticles", "LoadOut MOA reticles",
/// "LoadOut Combat reticles", "Public-domain reticles") or model
/// ("Mil Tree - Christmas Tree"). This table lets the picker still
/// match a search by JOB ("dense", "compact", "christmas", "bdc")
/// rather than only by the full archetype name.
const Map<String, List<String>> _kArchetypeTags = {
  // Density buckets. Match the spec section "Mil Tree - Compact",
  // "Mil Tree - Medium", "Mil Tree - Dense", "Mil Tree - Christmas Tree".
  'compact': ['compact', 'compact-mil'],
  'medium': ['medium-mil'],
  'dense': ['dense', 'dense-mil-tree'],
  'christmas': ['christmas-tree', 'dense-mil-tree'],
  // Hash patterns -- the simple no-tree variants.
  'mil hash': ['milhash', 'mil-hash'],
  'milhash': ['milhash', 'mil-hash'],
  'mil dot': ['mildot', 'mil-dot'],
  'mildot': ['mildot', 'mil-dot'],
  'moa hash': ['moahash', 'moa-hash'],
  // BDC / drop reticles.
  'bdc': ['bdc'],
  'with bdc': ['bdc'],
  // Combat / DMR archetypes.
  'combat': ['combat'],
  'dmr': ['dmr', 'combat'],
  // Hunting -> hunting tag.
  'hunting': ['hunting'],
  // Red dots / holographic.
  'red dot': ['red-dot', 'reddot'],
  'reddot': ['red-dot', 'reddot'],
  'holographic': ['holographic'],
  // Plex / German hunting reticles.
  'plex': ['plex', 'hunting'],
  'german': ['german', 'hunting'],
  'duplex': ['plex', 'hunting'],
  // Crosshair -> generic crosshair tag.
  'crosshair': ['crosshair'],
  // SFP / FFP / fixed.
  'sfp': ['sfp'],
  'ffp': ['ffp'],
  // Tree / christmas synonym promotion.
  'tree': ['tree'],
};

/// Ordered list of the LoadOut reticle categories every shooter
/// recognises. Rendered by the picker as a "Popular reticles" section
/// above the brand-grouped list. Tapping one filters the catalog to
/// every reticle whose tag-set contains the popular tag.
const List<PopularReticleEntry> kPopularReticleTags = [
  PopularReticleEntry(
    tag: 'dense-mil-tree',
    label: 'Dense Mil Tree',
    description: 'Tight 0.2-mil grids with full holdover ladder',
  ),
  PopularReticleEntry(
    tag: 'christmas-tree',
    label: 'Christmas Tree',
    description: 'Wrapping wind-dot ladder for ELR / PRS',
  ),
  PopularReticleEntry(
    tag: 'medium-mil',
    label: 'Medium Mil Tree',
    description: 'Balanced 0.5-mil grid with tree',
  ),
  PopularReticleEntry(
    tag: 'compact-mil',
    label: 'Compact Mil Tree',
    description: 'Minimal mil reticle for less-busy field of view',
  ),
  PopularReticleEntry(
    tag: 'mil-hash',
    label: 'Mil Hash',
    description: 'Simple mil cross with hashes, no tree',
  ),
  PopularReticleEntry(
    tag: 'mil-dot',
    label: 'Mil-Dot',
    description: 'Classic ranging dot pattern (USMC heritage)',
  ),
  PopularReticleEntry(
    tag: 'moa-hash',
    label: 'MOA Hash',
    description: 'MOA cross + hashes, MOA shooters',
  ),
  PopularReticleEntry(
    tag: 'bdc',
    label: 'BDC',
    description: 'Calibrated drop reticles by yardage',
  ),
  PopularReticleEntry(
    tag: 'combat',
    label: 'Combat',
    description: 'Horseshoe + dot for fast acquisition',
  ),
  PopularReticleEntry(
    tag: 'hunting',
    label: 'Hunting',
    description: 'Plex and BDC reticles for game',
  ),
  PopularReticleEntry(
    tag: 'red-dot',
    label: 'Red Dot',
    description: 'Single-dot red-dot patterns',
  ),
  PopularReticleEntry(
    tag: 'holographic',
    label: 'Holographic',
    description: 'Dot + ring holographic patterns',
  ),
];

/// Derive the brand-agnostic search tags for one reticle. Always
/// returns a non-empty set -- at minimum, every word in the manufacturer
/// + model + family becomes a tag.
Set<String> deriveReticleTags({
  required String manufacturer,
  required String model,
  String? family,
}) {
  final tags = <String>{};
  final haystack = _normalize('$manufacturer $model ${family ?? ''}');

  // Add every individual word (>= 2 chars) as a tag. This covers most
  // cases -- "loadout", "mil", "moa", "tree", "ffp", "sfp", etc.
  for (final w in haystack.split(' ')) {
    if (w.length >= 2) tags.add(w);
  }

  // Add the manufacturer as a single tag (lowercased, no spaces -- so
  // "Public domain" -> "publicdomain" -- but ALSO keep the spaced
  // form so a search "public" still hits).
  tags.add(_normalize(manufacturer).replaceAll(' ', ''));
  // Add a punctuation-stripped, no-space form of the model.
  tags.add(_normalize(model).replaceAll(' ', ''));

  // Walk the archetype-keyword table and attach extra tags whenever
  // the keyword appears anywhere in the haystack.
  for (final entry in _kArchetypeTags.entries) {
    if (haystack.contains(entry.key)) {
      tags.addAll(entry.value);
    }
  }

  return tags;
}

/// True when `query` (already lowercased + trimmed by the caller)
/// matches any tag derived from this reticle, OR appears as a
/// substring of the lowercased manufacturer / model / family. Used by
/// the search box.
bool reticleMatchesQuery({
  required String query,
  required String manufacturer,
  required String model,
  String? family,
}) {
  if (query.isEmpty) return true;
  final q = _normalize(query);
  if (q.isEmpty) return true;
  // Quick substring match on the raw haystack first (handles partial
  // typing).
  final hay = _normalize('$manufacturer $model ${family ?? ''}');
  if (hay.contains(q)) return true;
  // Tag exact-match.
  final tags = deriveReticleTags(
    manufacturer: manufacturer,
    model: model,
    family: family,
  );
  if (tags.contains(q)) return true;
  // Also match if the query is a prefix of any tag.
  for (final t in tags) {
    if (t.startsWith(q)) return true;
  }
  return false;
}

/// True when the reticle's tag set contains the given popular tag
/// (case-insensitive). Used by the "Popular reticles" chip to filter
/// the catalog.
bool reticleHasPopularTag({
  required String popularTag,
  required String manufacturer,
  required String model,
  String? family,
}) {
  final tags = deriveReticleTags(
    manufacturer: manufacturer,
    model: model,
    family: family,
  );
  return tags.contains(popularTag.toLowerCase());
}

/// Lowercase + collapse-whitespace + drop punctuation. Keeps digits
/// and a single space between tokens. Hyphens / slashes / underscores
/// become spaces.
String _normalize(String s) {
  // Replace anything that isn't a letter or digit with a space, then
  // collapse repeated whitespace.
  final lower = s.toLowerCase();
  final spaced = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
      spaced.write(ch);
    } else {
      spaced.write(' ');
    }
  }
  return spaced.toString().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
}
