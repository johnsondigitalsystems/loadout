// FILE: lib/data/reticle_tags.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Builds a brand-agnostic search-tag set for any reticle in the catalog,
// without requiring a tags column on the `Reticles` table or a `tags`
// field in `assets/seed_data/reticles.json`. The tags are derived purely
// from a reticle's `model`, `family`, and `manufacturer` strings — the
// data we already have on every row — plus a small hand-curated cross-
// brand patent table (Horus Vision licensed Tremor3 to Nightforce, S&B,
// and others; the brand-side reticle is named "TReMoR3" / "Tremor3"
// without the "Horus" string anywhere, so a search for "horus" would
// otherwise miss them).
//
// Public API:
//
//   `Set<String> deriveReticleTags({manufacturer, model, family})`
//      — returns the lowercase tags for one reticle. Always non-empty
//      (every reticle gets at least the manufacturer and model words).
//
//   `bool reticleMatchesQuery(query, manufacturer, model, family)`
//      — returns true when the query (already lowercased + trimmed)
//      matches any tag, the manufacturer, the model, the family, or
//      the concatenated "manufacturer model family" haystack. The
//      picker uses this single helper instead of building the
//      haystack manually so the matching rule stays consistent.
//
//   `kPopularReticleTags`
//      — ordered list of the ~10 reticle families every long-range
//      shooter knows by name (Tremor3, MIL-DOT, MOA-DOT, EBR-1,
//      EBR-2C, GAP-Reticle, SCR, MIL-XT, H59, MSR2). The picker
//      renders these as a "Popular reticles" section at the top of
//      the list — tapping one filters the picker to every reticle
//      whose tag-set contains the popular tag, regardless of brand.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// A user searching for "Tremor3" wants to see every Tremor3 licensee
// (Nightforce, Schmidt & Bender, possibly more in the future), not just
// the reticles whose model string happens to contain "tremor3". The
// existing search did `model.toLowerCase().contains(query)` which
// already finds both Nightforce's "TReMoR3" and S&B's "Tremor3", but
// breaks when the user types a different angle into the same family
// ("horus" was historically the design house, so power users search
// for the patent name). Tags resolve this without a DB migration.
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
//   * Reticle naming is wildly inconsistent across brands. "Mil-Dot",
//     "MIL-DOT", "MIL Dot", "Mil dot", "Mil-Hash", "MILHASH" all refer
//     to the same family of reticles. We normalize aggressively (lower-
//     case, strip punctuation, collapse whitespace) before tagging.
//   * Some patterns ARE brand-specific (Vortex's EBR-7C is theirs alone),
//     so we keep the manufacturer string in the tag set — searching
//     "vortex" still narrows to Vortex even if the reticle's model
//     doesn't say so.
//   * Cross-brand patent license tags (`horus` for Tremor3, `horus` for
//     H59, etc.) are added explicitly via [_kPatentTags]. Edit that
//     table when a new licensee ships a reticle of a known design
//     family.
//   * A single reticle can land in multiple popular buckets — e.g. the
//     Schmidt & Bender H59 lives in both "h59" and "horus". We don't
//     deduplicate at the tag level, only at the popular-section row
//     level (so a reticle never appears twice in one rendered list).
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/widgets/reticle_picker.dart` — the picker calls
//   [reticleMatchesQuery] for the search box and [deriveReticleTags]
//   for the "Popular reticles" filter chips.
// - Tests under `test/` — the tag-derivation logic should stay pure
//   so future tests can assert specific name → tag mappings.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure functions over strings.

/// One popular-reticle entry the picker renders as a chip / row at the
/// top of the list. The `tag` is the canonical lowercase token used to
/// filter the catalog; the `label` is the user-facing display name; the
/// `description` is a one-liner that appears as a subtitle on the chip
/// (kept short — it's a hint, not documentation).
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

/// Patent / licensed-design table. Maps a reticle-name keyword to one
/// or more cross-brand tags that should be added to its tag set when
/// the keyword appears in the model or family string.
///
/// Keys are matched against the lowercased, punctuation-stripped model
/// + family text. Values are the additional tags to attach.
const Map<String, List<String>> _kPatentTags = {
  // Horus Vision designs licensed to multiple optics brands.
  'tremor3': ['horus', 'tremor3'],
  'tremor 3': ['horus', 'tremor3'],
  'tremor': ['horus'],
  'h59': ['horus', 'h59'],
  'h 59': ['horus', 'h59'],
  'h37': ['horus', 'h37'],
  // Surgeon Rifles' SCR (Special Competition Reticle) shows up across
  // Burris, Steiner, EOTech (Vudu).
  'scr': ['scr'],
  // GAP-Reticle (G.A. Precision) - shows up across US Optics, Bushnell.
  'gap': ['gap'],
  // Bryan Litz / Applied Ballistics MIL-XT family.
  'mil-xt': ['milxt'],
  'mil xt': ['milxt'],
  // Common precision-rifle hash patterns. The base "mil" / "moa" tags
  // already get added by the splitter, but we promote "mil-dot" /
  // "mil-hash" / "moa-dot" to dedicated tags so a search for "mil-dot"
  // narrows specifically to those reticles instead of every mil
  // reticle.
  'mil-dot': ['mildot'],
  'mil dot': ['mildot'],
  'mildot': ['mildot'],
  'mil-hash': ['milhash'],
  'mil hash': ['milhash'],
  'milhash': ['milhash'],
  'moa-dot': ['moadot'],
  'moa dot': ['moadot'],
  'msr2': ['msr2'],
  'msr-2': ['msr2'],
  'msr 2': ['msr2'],
  // Vortex EBR family — a search for "ebr" should find every EBR-N.
  'ebr': ['ebr'],
  // Schmidt & Bender German numbered patterns.
  'p4f': ['p4f'],
  'klassik': ['klassik'],
};

/// Ordered list of the ~10 reticle families every long-range shooter
/// knows by name. Rendered by the picker as a "Popular reticles"
/// section above the brand-grouped list. Tapping one filters the
/// catalog to every reticle whose tag-set contains the popular tag,
/// regardless of brand.
const List<PopularReticleEntry> kPopularReticleTags = [
  PopularReticleEntry(
    tag: 'tremor3',
    label: 'Tremor3',
    description: 'Horus Vision design — Nightforce, S&B, others',
  ),
  PopularReticleEntry(
    tag: 'mildot',
    label: 'Mil-Dot',
    description: 'Classic mil-dot ranging reticle',
  ),
  PopularReticleEntry(
    tag: 'milhash',
    label: 'Mil-Hash',
    description: 'Hash-style mil grid',
  ),
  PopularReticleEntry(
    tag: 'moadot',
    label: 'MOA-Dot',
    description: 'MOA grid with dot subtensions',
  ),
  PopularReticleEntry(
    tag: 'ebr',
    label: 'EBR (Vortex)',
    description: 'Vortex Extended Bullet Range family',
  ),
  PopularReticleEntry(
    tag: 'gap',
    label: 'GAP-Reticle',
    description: 'G.A. Precision tree-style reticle',
  ),
  PopularReticleEntry(
    tag: 'scr',
    label: 'SCR',
    description: 'Special Competition Reticle (Burris, Steiner, others)',
  ),
  PopularReticleEntry(
    tag: 'milxt',
    label: 'MIL-XT',
    description: 'Bryan Litz / Nightforce precision pattern',
  ),
  PopularReticleEntry(
    tag: 'h59',
    label: 'H59',
    description: 'Horus H59 tree reticle',
  ),
  PopularReticleEntry(
    tag: 'msr2',
    label: 'MSR2',
    description: 'Schmidt & Bender / Steiner / Kahles Multi-Stadia',
  ),
];

/// Derive the brand-agnostic search tags for one reticle. Always
/// returns a non-empty set — at minimum, every word in the manufacturer
/// + model + family becomes a tag.
Set<String> deriveReticleTags({
  required String manufacturer,
  required String model,
  String? family,
}) {
  final tags = <String>{};
  final haystack = _normalize('$manufacturer $model ${family ?? ''}');

  // Add every individual word (≥ 2 chars) as a tag. This covers most
  // cases — "vortex", "ebr", "mrad", "mil", "moa", "ffp", "sfp", etc.
  for (final w in haystack.split(' ')) {
    if (w.length >= 2) tags.add(w);
  }

  // Add the manufacturer as a single tag (lowercased, no spaces — so
  // "Schmidt & Bender" → "schmidtbender" — but ALSO keep the spaced
  // form so a search "schmidt" still hits).
  tags.add(_normalize(manufacturer).replaceAll(' ', ''));
  // Add a punctuation-stripped, no-space form of the model so "EBR-2C"
  // → "ebr2c" matches a search of "ebr2c" with no hyphen.
  tags.add(_normalize(model).replaceAll(' ', ''));

  // Walk the patent / cross-brand table and attach extra tags whenever
  // the keyword appears anywhere in the haystack.
  for (final entry in _kPatentTags.entries) {
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
  // typing like "ebr-2" before the user even gets to "ebr2c").
  final hay = _normalize('$manufacturer $model ${family ?? ''}');
  if (hay.contains(q)) return true;
  // Tag exact-match — covers the cross-brand cases ("horus", "tremor3"
  // when the model name itself doesn't say "horus").
  final tags = deriveReticleTags(
    manufacturer: manufacturer,
    model: model,
    family: family,
  );
  if (tags.contains(q)) return true;
  // Also match if the query is a prefix of any tag — so typing "trem"
  // surfaces every "tremor3" / "tremor" hit.
  for (final t in tags) {
    if (t.startsWith(q)) return true;
  }
  return false;
}

/// True when the reticle's tag set contains the given popular tag
/// (case-insensitive). Used by the "Popular reticles" chip to filter
/// the catalog regardless of brand.
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
/// become spaces so "EBR-2C" → "ebr 2c" (which then splits into "ebr"
/// and "2c" tags — both useful for search).
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
