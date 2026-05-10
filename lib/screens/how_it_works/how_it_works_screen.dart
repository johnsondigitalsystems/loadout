// FILE: lib/screens/how_it_works/how_it_works_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Renders the "How It Works" explainer screen — a topical menu of feature
// explanations the user can browse at their own pace. Reachable from the
// side drawer's "How It Works" entry. The screen replaces the older
// approach of linking directly to the linear `OnboardingScreen`.
//
// The layout:
//
//   - Header lead-in ("Pick any topic — or start with the Quick Tour.")
//   - A big highlighted `_QuickTourCard` that routes to the eight-page
//     `OnboardingScreen` (the "Quick Tour" branding).
//   - Section "THE BASICS" — Recipes, Firearms, SAAMI Specs, Glossary
//   - Section "GOING DEEPER" — Reloading Guide, LoadOut Pro, Local-First
//     & Privacy, Disclaimer & Safety
//
// Each topic is rendered as a `_TopicCard` (icon + title + tagline +
// chevron). Tapping a card pushes a `_TopicDetailScreen`, which renders
// a bigger view of the same `_Topic` data:
//
//   - Eyebrow line ("THE BASICS" / "GOING DEEPER" — small, uppercase,
//     letter-spaced label above the hero)
//   - Hero icon in a circular brass-tinted disc
//   - Headline title
//   - Body paragraph
//   - Bulleted feature list (`_BulletRow` items with icon + text)
//   - A primary `FilledButton.icon` CTA labeled per the topic
//
// The CTA dispatch lives in `_TopicDetailScreen._runCta`. CTAs either
// (a) pop back to the home shell and switch its bottom-nav tab via
// `HomeScreen.switchTab(navContext, index)`, or (b) pop back to home
// and push a standalone screen as a `MaterialPageRoute`. The
// `_popToHomeAndSwitchTab` and `_popToHomeAndPush` helpers handle the
// pop-then-act sequence so the topic detail and the topics index are
// torn down correctly before the destination renders.
//
// The "Read Disclaimer" CTA is a special case — it does NOT push the
// blocking-acceptance `DisclaimerScreen`. It pushes a separate read-only
// `DisclaimerViewerScreen` defined further down in this file. Same
// body text, different chrome (no checkbox, no Accept button) so the
// user can re-read the safety language without being asked to re-accept.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `OnboardingScreen` is a linear PageView walkthrough — once a user
// dismisses it, they have no obvious way back to a refresher about a
// specific feature. This screen is the "browse anytime" complement: a
// menu of bite-sized topic cards the user can dip into when they want
// to remember how a particular subsystem works.
//
// Co-locating the read-only `DisclaimerViewerScreen` here (rather than
// reusing the gating `DisclaimerScreen` as a dual-purpose view) keeps
// the gating screen's contract simple — it always means "this is the
// blocking acceptance step." Splitting the read-only path lets the
// gating screen stay focused on its job.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// The `_popToHomeAndSwitchTab` helper deliberately resolves the home
// state via `Navigator.of(context).context` BEFORE calling
// `popUntil((route) => route.isFirst)`. That's because `popUntil` tears
// down the topic detail and the topics index, which would invalidate
// the original `context` we were called with. Capturing the navigator's
// own context up front gives us a context that survives the pop.
//
// The SAAMI tab index (4) is hard-coded in `_runCta`'s switch statement
// and there's a comment to keep it in sync with `HomeScreenState._pages`.
// If a new tab is inserted before SAAMI, both files must update
// together. Not great, but the alternative — exposing tab indices as
// a typed enum — is more boilerplate than a four-tab nav warrants.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/screens/home/home_screen.dart` — the side drawer's "How It
//   Works" entry pushes this screen.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None directly — pure routing UI on top of `const` topic data. The
// CTAs trigger navigator pushes/pops; no I/O, no persistence, no
// network.

import 'package:flutter/material.dart';

import '../backup/backup_screen.dart';
import '../batches/batches_list_screen.dart';
import '../brass_lots/brass_lots_list_screen.dart';
import '../disclaimer/disclaimer_screen.dart';
import '../glossary/glossary_screen.dart';
import '../guide/reloading_guide_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../paywall/paywall_screen.dart';
import '../privacy/privacy_screen.dart';
import '../ballistics/internal_ballistics_screen.dart';
import '../load_development/load_development_list_screen.dart';
import '../resources/resources_screen.dart';
import '../settings/settings_screen.dart';

/// Topic-based explainer screen reachable from the side drawer
/// ("How It Works"). Acts as a menu of bite-sized topic cards — each
/// opens a detail page that explains a specific feature, with an
/// optional CTA that jumps to the relevant part of the app.
///
/// The Quick Tour card at the top routes to the existing linear
/// [OnboardingScreen]; this screen replaces the drawer's direct link
/// to onboarding so users have a richer, browsable entry point.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final basics = _topicsForSection(_Section.basics);
    final deeper = _topicsForSection(_Section.goingDeeper);

    return Scaffold(
      appBar: AppBar(title: const Text('How It Works')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // Header lead-in.
            Text(
              'Pick any topic — or start with the Quick Tour.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            // Big highlighted entry card.
            _QuickTourCard(
              onTap: () => _openOnboarding(context),
            ),
            const SizedBox(height: 28),
            _SectionLabel(label: _Section.basics.label),
            const SizedBox(height: 12),
            for (final t in basics) ...[
              _TopicCard(
                topic: t,
                onTap: () => _openTopic(context, t),
              ),
              if (t != basics.last) const SizedBox(height: 10),
            ],
            const SizedBox(height: 28),
            _SectionLabel(label: _Section.goingDeeper.label),
            const SizedBox(height: 12),
            for (final t in deeper) ...[
              _TopicCard(
                topic: t,
                onTap: () => _openTopic(context, t),
              ),
              if (t != deeper.last) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  void _openOnboarding(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _openTopic(BuildContext context, _Topic topic) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TopicDetailScreen(topic: topic),
      ),
    );
  }
}

// ─────────────────────────── Topic data model ───────────────────────────

enum _Section {
  basics('THE BASICS'),
  goingDeeper('GOING DEEPER');

  const _Section(this.label);
  final String label;
}

enum _TopicId {
  recipes,
  firearms,
  rangeDay,
  ballistics,
  batches,
  brassLots,
  saami,
  glossary,
  // Free, Resources-tile destination — never republishes manufacturer
  // load data; deep-links to the official Hodgdon / Hornady / Sierra
  // / Vihtavuori pages instead. See lookup_loads_sheet.dart.
  lookupLoads,
  reloadingGuide,
  beginnerMode,
  // Pro features added in the May 2026 wave. Each has its own
  // engineering CLAUDE.md section (§§ 24, 25); the topic cards below
  // are the user-facing explainers.
  internalBallistics,
  loadDevelopment,
  smartImport,
  cloudSync,
  companionApps,
  pro,
  privacy,
  disclaimer,
}

class _Topic {
  const _Topic({
    required this.id,
    required this.section,
    required this.icon,
    required this.title,
    required this.tagline,
    required this.body,
    required this.bullets,
    required this.ctaLabel,
  });

  final _TopicId id;
  final _Section section;
  final IconData icon;
  final String title;
  final String tagline;
  final String body;
  final List<_TopicBullet> bullets;
  final String ctaLabel;
}

class _TopicBullet {
  const _TopicBullet(this.icon, this.text);
  final IconData icon;
  final String text;
}

List<_Topic> _topicsForSection(_Section section) =>
    _allTopics.where((t) => t.section == section).toList(growable: false);

const List<_Topic> _allTopics = [
  // ─── THE BASICS ───
  _Topic(
    id: _TopicId.recipes,
    section: _Section.basics,
    icon: Icons.receipt_long,
    title: 'Recipes',
    tagline:
        'Capture loads in seconds with Quick, or every detail with Standard. Toggle Core / Extended / Full.',
    body:
        'A recipe is your specific load formula — caliber, powder, charge, '
        'bullet, primer, brass, and dimensions like COAL or CBTO. Save it, '
        'search it, edit it on the Recipes tab.\n\n'
        'Two FABs: Quick (notebook-line capture — four fields, no naming '
        'required) and Standard (the full form). Use the detail toggle at '
        'the top of any recipe to switch between Core, Extended, and Full '
        'field views. In Full mode the form is a navigable accordion — '
        'tap a section header to expand, and switching modes scrolls back '
        'to the section you were just editing.\n\n'
        'Component pickers (caliber, powder, bullet, primer, brass) sort '
        'options by Favorites first, then your most-frequently-used, then '
        'the rest. Star a powder once and it bubbles to the top of every '
        'future picker.',
    bullets: [
      _TopicBullet(Icons.bolt, 'Quick FAB: capture a load in 30 seconds.'),
      _TopicBullet(Icons.tune, 'Three detail levels: Core, Extended, Full.'),
      _TopicBullet(
        Icons.search,
        'Filter fields by name. Tap any (?) glyph for a glossary definition.',
      ),
      _TopicBullet(
        Icons.star_border,
        'Smart defaults: Favorites → Frequently used → general.',
      ),
    ],
    ctaLabel: 'Open Recipes',
  ),
  _Topic(
    id: _TopicId.firearms,
    section: _Section.basics,
    icon: Icons.handshake,
    title: 'Firearms',
    tagline:
        'Catalog every gun, link an optic + reticle, track shots fired and throat erosion.',
    body:
        'Add every firearm you reload for. Pick from the reference '
        'catalog or add a custom build. Capture barrel length, twist '
        'rate, action, chambering, and notes.\n\n'
        'Each firearm tracks shots fired across every recipe / batch '
        'so you can monitor barrel life over time. Optional throat-'
        'erosion fields (last-measured CBTO + measurement date) let '
        'you re-zero seating depth as the throat moves.\n\n'
        'Pair an optic from the 47-scope, 26-brand catalog and pick a '
        'reticle from the LoadOut + Classic library — your firearm '
        "remembers both, so the Range Day setup card pre-fills the "
        'reticle when you select this gun. Star a firearm to surface '
        "it at the top of every picker.",
    bullets: [
      _TopicBullet(
        Icons.library_add,
        'Pick from 47 scopes / 26 brands or add a custom build.',
      ),
      _TopicBullet(Icons.timer, 'Tracks shots fired across all your recipes.'),
      _TopicBullet(
        Icons.straighten,
        'Throat erosion: last-CBTO + date for re-zero work.',
      ),
      _TopicBullet(
        Icons.star_border,
        'Favorite a firearm and it floats to the top of every picker.',
      ),
    ],
    ctaLabel: 'Open Firearms',
  ),
  _Topic(
    id: _TopicId.rangeDay,
    section: _Section.basics,
    icon: Icons.gps_fixed,
    title: 'Range Day',
    tagline:
        'The screen you live in at the line. Quick mode for fast field use; Full mode for analysis.',
    body:
        'Open the Range Day tab and you land on a fresh session — pick '
        'distance, target, profile, load, firearm, and reticle. The '
        'pinned solution strip at the top stays in view as you scroll: '
        'glance → fire → glance.\n\n'
        'A Quick / Full toggle lives in the AppBar. Quick collapses the '
        'screen to Setup + Firing Solution — the bare minimum at the '
        'line. Full reveals every advanced card: Environment, Wind '
        'Bracket, Hit Probability, Target Plot (tap-to-record-shot), '
        'Group Stats, Last Shot Correction, DOPE table, Moving Target '
        'lead, Notes.\n\n'
        'Three Pro analysis routes push from the screen rather than '
        'inline:\n\n'
        '  • Hit Probability Map — Monte Carlo hit probability '
        'across the engagement window (wind / range / shooter '
        'dispersion).\n'
        '  • BC Truing — back out the actual ballistic coefficient '
        'from observed drops at known distances.\n'
        '  • Scope Tracking Test — verify your scope\'s click value '
        'against measured group offsets (tall-target / DPC test).\n\n'
        'Saved sessions live in History (AppBar action). Auto-saves '
        'on every field change.',
    bullets: [
      _TopicBullet(Icons.bolt, 'Quick mode: Setup + Solution only.'),
      _TopicBullet(Icons.tune, 'Full mode: every analysis card.'),
      _TopicBullet(Icons.history, 'History menu surfaces every saved session.'),
      _TopicBullet(
        Icons.science_outlined,
        'Pro routes: Hit Probability Map, BC Truing, Scope Tracking Test.',
      ),
      _TopicBullet(
        Icons.bluetooth,
        'Pair Kestrel / Garmin Xero / rangefinders for live data (Pro).',
      ),
    ],
    ctaLabel: 'Open Range Day',
  ),
  _Topic(
    id: _TopicId.ballistics,
    section: _Section.basics,
    icon: Icons.calculate_outlined,
    title: 'Ballistics Calculator (Pro)',
    tagline:
        'Modified Point-Mass solver with the precision corrections that matter past 600 yd.',
    body:
        'A Modified Point-Mass solver in the McCoy tradition. '
        'Free at every range:\n\n'
        '  • G1 / G7 drag tables (every catalog bullet ships with both).\n'
        '  • Spin drift .\n'
        '  • Coriolis (latitude + shot azimuth).\n'
        '  • Aerodynamic jump (crosswind-driven).\n'
        '  • Density altitude (full ICAO atmosphere).\n'
        '  • Per-firearm Ballistic Profiles.\n'
        '  • Atmosphere presets you can save per range.\n\n'
        'Pro adds:\n\n'
        '  • Custom Drag Models — Hornady 4DOF curves and per-bullet '
        'DSF curves on the bullets that ship with them. Roughly +0.3 '
        'MOA accuracy gain past 800 yd vs G7 for transonic-zone shots.\n'
        '  • Live weather pull — populate temp / pressure / humidity '
        'from your current location in one tap.\n\n'
        'Output: drop, wind drift, time of flight, velocity, energy at '
        'any distance.',
    bullets: [
      _TopicBullet(Icons.timeline, 'G1 / G7 (free). Custom Drag Models (Pro).'),
      _TopicBullet(
        Icons.thermostat,
        'Spin drift, Coriolis, aerodynamic jump, density altitude — all free.',
      ),
      _TopicBullet(
        Icons.bookmark_outline,
        'Save atmosphere presets per range.',
      ),
      _TopicBullet(
        Icons.gps_fixed,
        'Live weather pull from your location (Pro).',
      ),
    ],
    ctaLabel: 'Open Ballistics',
  ),
  _Topic(
    id: _TopicId.batches,
    section: _Section.basics,
    icon: Icons.inventory_2_outlined,
    title: 'Batches',
    tagline:
        'Track each loading run end-to-end with a per-cartridge process checklist.',
    body:
        'A batch is one production run — pick a recipe, pick a brass lot, '
        'set how many rounds you\'re loading, and step through the process. '
        'The checklist auto-filters by cartridge type (rifle vs pistol vs '
        'shotgun) so you only see steps that apply.\n\n'
        'When you "Fire X rounds" from the batch detail screen, it cascades '
        'into the brass lot\'s firing count automatically.',
    bullets: [
      _TopicBullet(
        Icons.checklist,
        'Caliber-filtered process checklist per batch.',
      ),
      _TopicBullet(
        Icons.local_fire_department_outlined,
        'Fire-rounds action cascades into brass-lot firing count.',
      ),
      _TopicBullet(
        Icons.tune,
        'Edit the standard process steps under Reloading Steps.',
      ),
    ],
    ctaLabel: 'Open Batches',
  ),
  _Topic(
    id: _TopicId.brassLots,
    section: _Section.basics,
    icon: Icons.factory_outlined,
    title: 'Brass Lots',
    tagline:
        'Track each batch of brass through firings, sizing, trimming, annealing.',
    body:
        'A brass lot tracks one batch of cases — manufacturer, headstamp, '
        'count, firings, last anneal date + method. Helps you retire brass '
        'before it splits.\n\n'
        'Recipes link to a brass lot by FK, so the lot label survives even '
        'if the original brass is consumed and replaced.',
    bullets: [
      _TopicBullet(Icons.refresh, 'Firing-count tracker (auto from Batches).'),
      _TopicBullet(
        Icons.local_fire_department_outlined,
        'Anneal date + method log.',
      ),
      _TopicBullet(Icons.straighten, 'Adjust on-hand count for splits / loss.'),
    ],
    ctaLabel: 'Open Brass Lots',
  ),
  _Topic(
    id: _TopicId.saami,
    section: _Section.basics,
    icon: Icons.straighten,
    title: 'SAAMI Specs',
    tagline:
        'Look up dimensions for 200+ cartridges. Lives under Resources in the side menu.',
    body:
        'Look up authoritative cartridge dimensions for 200+ rifle, pistol, '
        'rimfire, and shotgun cartridges, sourced from SAAMI Z299.1–4 and '
        'CIP TDCC.\n\n'
        'Pick any cartridge to see bullet, case, body, neck, shoulder, and '
        'rim dimensions, plus pressure and twist-rate references.\n\n'
        'SAAMI Specs lives under the side menu → Resources (it used to be '
        'in Settings; reference material got its own home so Settings could '
        'stay focused on preferences).',
    bullets: [
      _TopicBullet(
        Icons.search,
        "Fuzzy search by name or alias — '6 GT' finds '6mm GT'.",
      ),
      _TopicBullet(
        Icons.straighten,
        '200+ cartridges across SAAMI and CIP standards.',
      ),
      _TopicBullet(
        Icons.image_outlined,
        'Pro: technical drawings of cartridge + chamber profiles.',
      ),
    ],
    ctaLabel: 'Open Resources',
  ),
  _Topic(
    id: _TopicId.glossary,
    section: _Section.basics,
    icon: Icons.menu_book,
    title: 'Glossary',
    tagline:
        '142 reloading + ballistics terms across 10 categories. Two beginner landing tiles.',
    body:
        'A searchable reference for the vocabulary you\'ll meet across '
        'the app — 142 terms grouped into 10 categories (Cartridge '
        'anatomy, Ballistics, Range day, Optics, Load development, '
        'Powder, Primers, Brass, Reloading process, Firearm-side). '
        '34 entries include a worked example with concrete numbers.\n\n'
        'Two landing tiles at the top help newcomers anchor: '
        '"New to reloading" curates 21 foundational terms (COAL, '
        'headspace, pressure signs, charge weight, etc.); "Range Day '
        'workflow" curates 22 firing-line terms (mil, MOA, drop, wind '
        'drift, DOPE, density altitude). Tap a tile to filter the '
        'glossary down to that subset; tap "Show all" to clear.\n\n'
        'Field labels across the recipe / Range Day / ballistics forms '
        'are wrapped in a tappable (?) glyph — tap any term in any form '
        'to get its definition without leaving the form.',
    bullets: [
      _TopicBullet(
        Icons.school_outlined,
        'Two landing tiles: "New to reloading" + "Range Day workflow".',
      ),
      _TopicBullet(
        Icons.help_outline,
        'Tappable (?) glyph on every glossary term in every form.',
      ),
      _TopicBullet(
        Icons.format_quote,
        '34 worked examples with concrete numbers.',
      ),
      _TopicBullet(
        Icons.search,
        'Full-text search across terms, acronyms, and definitions.',
      ),
    ],
    ctaLabel: 'Open Glossary',
  ),
  _Topic(
    id: _TopicId.lookupLoads,
    section: _Section.basics,
    icon: Icons.menu_book_outlined,
    title: 'Look Up Published Loads',
    tagline:
        'One tap to the official Hodgdon / Hornady / Sierra / Vihtavuori pages. We never republish.',
    body:
        "LoadOut's principle: your recipes are yours, the "
        "manufacturers' recipes are theirs, and we host neither. The "
        '"Look Up Published Loads" sheet on the SAAMI screen and the '
        'recipe form\'s caliber field opens four cards — Hodgdon '
        'Reloading Data Center, Hornady Load Data, Sierra Load Data, '
        'Vihtavuori Reloading Data Tool — and tapping any card hands '
        'you off to the manufacturer\'s own page in your system '
        'browser.\n\n'
        'We never scrape, never cache, never republish. The cartridge '
        'name you tapped is rendered in the sheet for your reference '
        "but is NOT passed to the destination URL — your input doesn't "
        'leak across the app boundary either.\n\n'
        'Free for everyone.',
    bullets: [
      _TopicBullet(
        Icons.shield_outlined,
        "We never republish anyone else's load tables.",
      ),
      _TopicBullet(
        Icons.open_in_new,
        "Manufacturer's official page in your system browser.",
      ),
      _TopicBullet(
        Icons.privacy_tip_outlined,
        'Your tapped cartridge name never leaves the app.',
      ),
    ],
    ctaLabel: 'Open SAAMI Specs',
  ),
  // (Component Inventory ships at schema v32 in main; the screen is
  // not yet present in this worktree, so the How It Works topic for
  // it is omitted here. Add it back once `lib/screens/inventory/`
  // lands in this branch — see CLAUDE.md § 26 + marketing/CLAUDE.md
  // § 23a for the user-facing copy.)

  // ─── GOING DEEPER ───
  _Topic(
    id: _TopicId.reloadingGuide,
    section: _Section.goingDeeper,
    icon: Icons.auto_stories_outlined,
    title: 'Reloading Guide',
    tagline:
        'Walk through the eight stages of reloading at a high level.',
    body:
        'An eight-stage walkthrough of the reloading process — from inspecting '
        'brass through final inspection. High-level reference, not load data.\n\n'
        'Every stage explains what it does, why it matters, common tools, and '
        'what to watch for. This is reference content; always cross-check '
        'against published manuals from your component manufacturers.',
    bullets: [
      _TopicBullet(Icons.list_alt, 'Eight chronological stages of reloading.'),
      _TopicBullet(
        Icons.warning_amber,
        'High-level — never includes specific charges or pressures.',
      ),
      _TopicBullet(
        Icons.menu_book_outlined,
        'Cross-check with published manuals before loading.',
      ),
    ],
    ctaLabel: 'Open Reloading Guide',
  ),
  _Topic(
    id: _TopicId.beginnerMode,
    section: _Section.goingDeeper,
    icon: Icons.school_outlined,
    title: 'Beginner Mode',
    tagline:
        'Tooltips, simpler defaults, and no power-user clutter. Settings → App preferences.',
    body:
        'Toggle Beginner Mode on (Settings → App preferences) and the app '
        'biases for clarity over density. Recipe forms default to Core. '
        'The (?) glyph next to glossary-tracked field labels gets visual '
        'emphasis the first time you encounter a new term in a session, '
        'then fades to subtle on subsequent appearances. Power-user '
        'surfaces like the BYOK ("bring your own Anthropic key") section '
        'in AI Settings hide entirely.\n\n'
        'Flip it off any time and every advanced affordance comes back.',
    bullets: [
      _TopicBullet(Icons.tune, 'Recipe forms default to Core mode.'),
      _TopicBullet(
        Icons.help_outline,
        'First-occurrence emphasis on glossary tooltips.',
      ),
      _TopicBullet(
        Icons.visibility_off_outlined,
        'Hides BYOK and other power-user toggles.',
      ),
    ],
    ctaLabel: 'Open Settings',
  ),
  _Topic(
    id: _TopicId.smartImport,
    section: _Section.goingDeeper,
    icon: Icons.auto_fix_high_outlined,
    title: 'Imports & QR sharing',
    tagline:
        'Photo OCR, CSV / Excel, paste, QR — all free. AI cleanup is an optional Pro add-on.',
    body:
        'Imports live in a single section of the recipe form. Every '
        'source below is FREE — the only Pro / paid piece is the '
        'optional AI cleanup at the end:\n\n'
        '  • Spreadsheet (CSV / Excel) with a fuzzy header-mapping wizard.\n'
        '  • Photo (on-device OCR via ML Kit, plus a 444-entry '
        'handwriting alias dictionary so a notebook line "6.5 CM 41.0gr '
        'H4350" parses cleanly).\n'
        '  • File — re-import a LoadOut JSON export.\n'
        '  • Another reloading app — Hornady 4DOF / GRT / QuickLOAD / '
        'Strelok export shapes are detected.\n'
        '  • Paste from clipboard — best-effort heuristic parse.\n'
        '  • iCloud Drive / Google Drive / OneDrive — pull a CSV '
        'directly from your cloud.\n'
        '  • QR scan — scan another LoadOut user\'s recipe QR.\n\n'
        'AI Smart Import (Pro, opt-in per use) is the only paid add-on. '
        'It only fires when the on-device parser flags low confidence '
        'AND you tap "Improve with AI." 20 imports / month for Pro '
        'users via the hosted Cloudflare Worker; unlimited if you bring '
        'your own Anthropic key (BYOK). Only the OCR\'d text is sent — '
        'never your saved recipes, firearms, or anything else.',
    bullets: [
      _TopicBullet(
        Icons.camera_alt_outlined,
        'Photo OCR + 444-entry handwriting alias dictionary (free).',
      ),
      _TopicBullet(
        Icons.qr_code_scanner_outlined,
        'QR-share recipes with another LoadOut user (free).',
      ),
      _TopicBullet(
        Icons.table_view_outlined,
        'CSV / Excel + fuzzy header mapping (free).',
      ),
      _TopicBullet(
        Icons.auto_fix_high,
        'AI Smart Import (Pro): per-import opt-in. Off by default.',
      ),
    ],
    ctaLabel: 'Open Recipes',
  ),
  _Topic(
    id: _TopicId.cloudSync,
    section: _Section.goingDeeper,
    icon: Icons.cloud_sync_outlined,
    title: 'Cloud Backup & Sync (Pro)',
    tagline:
        'Encrypted on-device with your passphrase. Lives in YOUR iCloud / Drive / OneDrive.',
    body:
        'Pro unlocks two cloud features: manual Cloud Backup (one-shot '
        'export, encrypted, uploaded to your provider) and continuous '
        'Cloud Sync (auto-uploads ~5 sec after each save, pulls on app '
        'launch).\n\n'
        'Both use the same encryption (AES-256-GCM with PBKDF2 200k '
        'iterations + your passphrase). The encrypted blob lives in '
        'YOUR iCloud Drive, Google Drive, or Microsoft OneDrive — '
        'LoadOut runs no backend that receives this blob. Lost '
        'passphrase = lost data, by design.\n\n'
        "What's in the encrypted payload: every user-data table —"
        ' recipes, firearms, brass lots, batches, custom components, '
        'custom fields, ballistic profiles, atmosphere presets, lots, '
        'load-development sessions, AND every favorite (cartridges, '
        'reticles, targets, plus your starred powders / bullets / '
        'primers / brass). Reference catalogs (the 200+ SAAMI '
        'cartridges, the scope catalog, etc.) are NOT in the payload '
        '— they ship with every install and would only inflate the '
        "blob.\n\nConflict policy is last-writer-wins per row by "
        '`updatedAt`. A favorite added on iPhone shows up on iPad on '
        'the next sync pull.',
    bullets: [
      _TopicBullet(Icons.lock_outline, 'AES-256-GCM, passphrase-derived key.'),
      _TopicBullet(
        Icons.cloud_outlined,
        'iCloud Drive (iOS), Google Drive, Microsoft OneDrive.',
      ),
      _TopicBullet(
        Icons.sync,
        'Cloud Sync: continuous, last-writer-wins per row.',
      ),
      _TopicBullet(
        Icons.star_border,
        'Favorites + component favorites round-trip across devices.',
      ),
    ],
    ctaLabel: 'Open Backup & Export',
  ),
  _Topic(
    id: _TopicId.companionApps,
    section: _Section.goingDeeper,
    icon: Icons.watch_outlined,
    title: 'Apple Watch + Wear OS',
    tagline:
        'Native companion apps. Pairing infrastructure live; payloads coming next.',
    body:
        'Native watchOS (SwiftUI) and Wear OS (Compose) companion apps '
        'are scaffolded. The phone-side bridges (`WatchSessionBridge` on '
        'iOS, `WatchBridge` on Android) activate automatically on app '
        'launch, so the channels respond to pair / reachable queries '
        'today. Live feature payloads (DOPE glance, active load, stage '
        'timer, shot logging) are coming soon — they need the watch '
        'target to be wired up in Xcode and the phone-side code to push '
        'state on every save.',
    bullets: [
      _TopicBullet(Icons.bluetooth, 'WatchConnectivity (iOS) / Wearable Data Layer (Android).'),
      _TopicBullet(
        Icons.timer_outlined,
        'Planned: stage timer, DOPE glance, shot logging.',
      ),
      _TopicBullet(
        Icons.visibility_off_outlined,
        'No HTTP, no Firebase, no analytics on the watch.',
      ),
    ],
    ctaLabel: 'Open Settings',
  ),
  // (No dedicated How It Works topic for biometric. The toggle
  // lives in Settings → Account for users who want it. We don't
  // surface it as a marketed feature — it's an implementation
  // detail of "stay signed in," not a user-facing capability we
  // pitch.)
  _Topic(
    id: _TopicId.loadDevelopment,
    section: _Section.goingDeeper,
    icon: Icons.science_outlined,
    title: 'Load Development (Pro)',
    tagline:
        'Five named methods. Per-charge SD / ES / mean MV / group ES / mean radius. Node detection.',
    body:
        'Pro-gated workspace for running structured load-development '
        'tests. Five named methods, each with a tailored data-entry '
        'workflow, analysis algorithm, and chart:\n\n'
        '  • OCW (Newberry) — three shots per charge across an '
        'evenly-stepped ladder. Vertical-impact flat-spot detection '
        'finds the OCW node automatically.\n'
        '  • Audette Ladder — single shot per charge fired at long '
        'distance (300+ yd). Vertical-stacking analysis.\n'
        '  • Satterlee 10-shot — chronograph-driven. Plot mean MV '
        'vs charge; the plateau-detection algorithm finds the '
        'velocity-stable node.\n'
        '  • Generic charge ladder — freeform. The detail screen '
        'surfaces all three analyses (OCW flat spot, Satterlee '
        "plateau, lowest-SD charge) so you can pick whichever "
        'matches your protocol.\n'
        '  • Seating depth ladder — CBTO ladder around an existing '
        'recipe; tunes seating depth for group / vertical.\n\n'
        'Per-charge stats table on every method screen: mean MV, '
        'SD, ES, mean impact (X / Y), group extreme spread, mean '
        'radius. Cited published source for each method on an '
        'expandable Method card.\n\n'
        'Reachable from Resources, the Home drawer, the recipe '
        'form\'s "Run Load Development" CTA, and the Range Day '
        'active-load row.',
    bullets: [
      _TopicBullet(Icons.tune, 'OCW, Audette, Satterlee, Generic, Seating.'),
      _TopicBullet(
        Icons.show_chart,
        'OCW flat-spot detection; Satterlee MV-plateau detection.',
      ),
      _TopicBullet(
        Icons.table_chart_outlined,
        'Per-charge SD / ES / mean MV / group ES / mean radius.',
      ),
      _TopicBullet(
        Icons.format_quote,
        'Plain-English method explainer with citation on every screen.',
      ),
    ],
    ctaLabel: 'Open Load Development',
  ),
  _Topic(
    id: _TopicId.internalBallistics,
    section: _Section.goingDeeper,
    icon: Icons.thermostat_outlined,
    title: 'Internal Ballistics Calculator (Pro)',
    tagline:
        'Interior-ballistics MV + peak chamber pressure predictor. The mobile answer to GRT / QuickLOAD.',
    body:
        'Predicts muzzle velocity and peak chamber pressure for a '
        'hypothetical reloading recipe — the headline feature LoadOut '
        'was missing relative to GRT (Windows / Mac via Wine) and '
        'QuickLOAD (\$170+, Windows-only). Both desktops; LoadOut '
        'shipping a competent mobile version is the differentiator.\n\n'
        'Implements a published 1962-derived (revised 1980) '
        'interior-ballistics estimation method — the same simplified '
        'model that backed the original Sierra and Lyman desktop programs. '
        'Inputs: cartridge case capacity, powder (looked up in a '
        '~40-powder reference table), charge weight, bullet weight '
        '+ diameter + COAL, barrel length. Outputs: predicted muzzle '
        'velocity (fps), predicted peak pressure (psi), loading '
        'density, expansion ratio, burn-completion %.\n\n'
        'Validation against four published Hodgdon RDC loads: ±10% '
        'MV, ±15% pressure across the test corpus. Persistent yellow '
        '"Estimation Tool — Not a Load-Data Substitute" banner is '
        'un-dismissible. Coarse SAAMI-band gauge ("Below typical '
        'SAAMI max" / "Approaching SAAMI max" / "At or above — '
        'verify") is advisory only.\n\n'
        "Reachable from the Resources tile and a bottom-of-screen "
        'button on the external Ballistics Calculator. Stateless '
        'across visits — no profiles, no persistence — so a stale '
        'prediction can\'t mislead.',
    bullets: [
      _TopicBullet(
        Icons.calculate_outlined,
        'Interior-ballistics estimator on mobile (±10% MV / ±15% pressure).',
      ),
      _TopicBullet(
        Icons.warning_amber,
        'Persistent yellow "estimation tool" banner — un-dismissible.',
      ),
      _TopicBullet(
        Icons.scale_outlined,
        'Loading density, expansion ratio, burn-completion %.',
      ),
      _TopicBullet(
        Icons.block,
        'Unknown powders return "not in catalog" — never silently substituted.',
      ),
    ],
    ctaLabel: 'Open Internal Ballistics',
  ),
  _Topic(
    id: _TopicId.pro,
    section: _Section.goingDeeper,
    icon: Icons.workspace_premium_outlined,
    title: 'LoadOut Pro',
    tagline:
        'Yearly or Lifetime. Unlocks the ballistics solver, encrypted cloud sync, BLE devices, and more.',
    body:
        'Two plans — yearly subscription or lifetime one-time '
        'purchase. Restore prior purchases anytime from the paywall '
        'screen.\n\n'
        'What Pro unlocks today:\n\n'
        '  • Custom drag curves (Hornady 4DOF / DSF) on top of '
        'G1 / G7.\n'
        '  • Internal Ballistics Calculator (interior-ballistics MV + '
        'peak pressure predictor).\n'
        '  • Load Development workspace — five named methods (OCW, '
        'Audette, Satterlee, Generic, Seating).\n'
        '  • Cloud Backup + Cloud Sync (encrypted to your '
        'iCloud / Drive / OneDrive).\n'
        '  • Bluetooth devices: Kestrel weather meters, Garmin Xero '
        'chronograph, rangefinders (Sig, Bushnell, Vortex, Leica, '
        'Vectronix).\n'
        '  • Scope View Pro reticle visualization + training mode.\n'
        '  • Moving Target lead computation.\n'
        '  • Live weather pull from your current location.\n'
        '  • SAAMI cartridge + chamber technical drawings.\n'
        '  • AI Smart Import (per-import opt-in, 20 imports / month).\n'
        '  • Unlimited custom fields.\n\n'
        'Coming soon (also Pro-gated when shipped): AI Reloading '
        'Assistant chat. The placeholder UI today is honest about '
        "this — we don't show a Pro paywall on a feature that "
        "doesn't ship yet.",
    bullets: [
      _TopicBullet(Icons.calculate_outlined, 'Ballistics + custom drag curves.'),
      _TopicBullet(Icons.cloud_sync, 'Encrypted Cloud Backup + Sync.'),
      _TopicBullet(
        Icons.bluetooth,
        'BLE devices (Kestrel, Xero, rangefinders).',
      ),
      _TopicBullet(
        Icons.auto_fix_high,
        'AI Smart Import (per-import opt-in).',
      ),
      _TopicBullet(
        Icons.image_outlined,
        'SAAMI technical drawings + Scope View Pro.',
      ),
    ],
    ctaLabel: 'View Pro',
  ),
  _Topic(
    id: _TopicId.privacy,
    section: _Section.goingDeeper,
    icon: Icons.shield_outlined,
    title: 'Local-First & Privacy',
    tagline:
        'Reloading data stays on your device. Optional encrypted cloud sync to YOUR own cloud — never ours.',
    body:
        'Your reloading data — recipes, firearms, brass lots, batches, '
        'custom components, custom fields, favorites — lives in the '
        'on-device SQLite database. LoadOut runs no backend that '
        'receives this data. No telemetry, no analytics, no third-party '
        'trackers.\n\n'
        'Firebase Auth handles sign-in (email, password, email-link, '
        'Google, Apple, Microsoft, Yahoo, anonymous). Sign-in is the '
        'ONLY thing Firebase sees about you.\n\n'
        'Optional Pro features layer on without breaking the local-'
        'first promise: Cloud Backup (one-shot) and Cloud Sync '
        '(continuous) encrypt the data on YOUR device with a passphrase '
        'only you know, then upload the encrypted blob to YOUR own '
        'iCloud Drive, Google Drive, or OneDrive. We never see the '
        'encrypted blob. Lost passphrase = lost data, by design — we '
        "can't recover what we can't decrypt.\n\n"
        'AI Smart Import (Pro, opt-in per use) is the only surface '
        "that sends user-typed text outside the device. It's scoped "
        'strictly to OCR\'d recipe-photo text and only fires when you '
        'tap "Improve with AI" on a low-confidence parse.',
    bullets: [
      _TopicBullet(
        Icons.shield,
        'Reloading data lives in on-device SQLite.',
      ),
      _TopicBullet(
        Icons.cloud_off,
        'No telemetry, no analytics, no third-party trackers.',
      ),
      _TopicBullet(
        Icons.lock_outline,
        'Cloud Sync (Pro): AES-256-GCM, encrypted with YOUR passphrase.',
      ),
      _TopicBullet(
        Icons.delete_forever,
        "Uninstall = wipe. Lost passphrase = lost cloud blob (by design).",
      ),
    ],
    ctaLabel: 'Privacy Details',
  ),
  _Topic(
    id: _TopicId.disclaimer,
    section: _Section.goingDeeper,
    icon: Icons.warning_amber_outlined,
    title: 'Disclaimer & Safety',
    tagline:
        'Reloading is dangerous. LoadOut is reference data — not a substitute for manuals or training.',
    body:
        'Reloading ammunition is inherently dangerous. Improper handloads can '
        'cause catastrophic firearm failure, serious injury, or death.\n\n'
        'LoadOut is reference and organizational software — not a substitute '
        'for proper training, current manufacturer load manuals, or '
        "experienced supervision. If you're new to reloading, take a class "
        'or work with someone experienced first.',
    bullets: [
      _TopicBullet(
        Icons.warning_amber,
        'Always cross-check loads with current manufacturer manuals.',
      ),
      _TopicBullet(
        Icons.school,
        "If you're new, work with someone experienced first.",
      ),
      _TopicBullet(
        Icons.menu_book,
        'LoadOut provides reference data, not a license to load.',
      ),
    ],
    ctaLabel: 'Read Disclaimer',
  ),
];

// ─────────────────────────── List items ───────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

/// The big highlighted entry card at the top of the list. Uses a brass
/// tinted background and brass border to set it apart from the regular
/// topic cards underneath.
class _QuickTourCard extends StatelessWidget {
  const _QuickTourCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brass = theme.colorScheme.primary;
    return Material(
      color: brass.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: brass.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: brass.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.flag_outlined, color: brass, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Take a Quick Tour',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Eight quick steps — Recipes, Firearms, SAAMI, Pro, '
                      'and safety. Two minutes.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: brass,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.onTap});
  final _Topic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brass = theme.colorScheme.primary;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.30),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: brass.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(topic.icon, color: brass, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      topic.tagline,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Detail screen ───────────────────────────

class _TopicDetailScreen extends StatelessWidget {
  const _TopicDetailScreen({required this.topic});
  final _Topic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brass = theme.colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: Text(topic.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            // Eyebrow — tiny uppercase section label above the hero.
            Text(
              topic.section.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: brass,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            // Hero icon in a circular tinted disc.
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: brass.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(topic.icon, color: brass, size: 44),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              topic.title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              topic.body,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.55,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 24),
            ...topic.bullets.map((b) => _BulletRow(bullet: b)),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _runCta(context, topic),
              icon: const Icon(Icons.arrow_forward),
              label: Text(topic.ctaLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _runCta(BuildContext context, _Topic topic) {
    switch (topic.id) {
      case _TopicId.recipes:
        _popToHomeAndSwitchTab(context, 0);
        break;
      case _TopicId.firearms:
        _popToHomeAndSwitchTab(context, 1);
        break;
      case _TopicId.batches:
        // Batches list lives in the drawer. The bottom-nav slot is
        // taken by Range Day; we push the drawer destination
        // directly so users hit the same screen they'd see from
        // the side menu.
        _popToHomeAndPush(
          context,
          MaterialPageRoute(builder: (_) => const BatchesListScreen()),
        );
        break;
      case _TopicId.brassLots:
        _popToHomeAndPush(
          context,
          MaterialPageRoute(builder: (_) => const BrassLotsListScreen()),
        );
        break;
      case _TopicId.rangeDay:
        // Range Day index in the bottom nav — see HomeScreenState._pages.
        _popToHomeAndSwitchTab(context, 4);
        break;
      case _TopicId.ballistics:
        _popToHomeAndSwitchTab(context, 3);
        break;
      case _TopicId.saami:
        // SAAMI moved out of the bottom nav into the Resources drawer
        // destination. CTA now opens Resources rather than a tab.
        _popToHomeAndPush(
          context,
          MaterialPageRoute(builder: (_) => const ResourcesScreen()),
        );
        break;
      case _TopicId.glossary:
        _popToHomeAndPush(
          context,
          MaterialPageRoute(builder: (_) => const GlossaryScreen()),
        );
        break;
      case _TopicId.lookupLoads:
        // The Lookup Loads sheet is invoked from a cartridge surface
        // (SAAMI / recipe form) — there's no standalone screen. The
        // most useful CTA from the explainer is to drop the user on
        // the Resources directory where SAAMI Specs lives, since
        // that's where they're most likely to want to use it.
        _popToHomeAndPush(
          context,
          MaterialPageRoute(builder: (_) => const ResourcesScreen()),
        );
        break;
      case _TopicId.internalBallistics:
        _popToHomeAndPush(
          context,
          MaterialPageRoute(builder: (_) => const InternalBallisticsScreen()),
        );
        break;
      case _TopicId.loadDevelopment:
        _popToHomeAndPush(
          context,
          MaterialPageRoute(builder: (_) => const LoadDevelopmentListScreen()),
        );
        break;
      case _TopicId.reloadingGuide:
        _popToHomeAndPush(
          context,
          MaterialPageRoute(builder: (_) => const ReloadingGuideScreen()),
        );
        break;
      case _TopicId.beginnerMode:
      case _TopicId.companionApps:
        // These topics live in Settings (App preferences for Beginner
        // Mode, Watch & Wear for companion apps). CTA opens Settings
        // root; the user navigates one level deeper themselves. Keeps
        // the topic body honest about exactly where the toggle lives.
        _popToHomeAndPush(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;
      case _TopicId.smartImport:
        _popToHomeAndSwitchTab(context, 0);
        break;
      case _TopicId.cloudSync:
        _popToHomeAndPush(
          context,
          MaterialPageRoute(builder: (_) => const BackupScreen()),
        );
        break;
      case _TopicId.pro:
        _popToHomeAndPush(
          context,
          MaterialPageRoute(
            builder: (_) => const PaywallScreen(),
            fullscreenDialog: true,
          ),
        );
        break;
      case _TopicId.privacy:
        _popToHomeAndPush(
          context,
          MaterialPageRoute(builder: (_) => const PrivacyScreen()),
        );
        break;
      case _TopicId.disclaimer:
        _popToHomeAndPush(
          context,
          MaterialPageRoute(
            builder: (_) => const DisclaimerViewerScreen(),
          ),
        );
        break;
    }
  }

  /// Pops back through the topic detail and the topics index to the
  /// home shell, then switches its bottom-nav tab to [index].
  ///
  /// The home state is resolved via the [Navigator]'s context so it
  /// remains valid after [Navigator.popUntil] tears down the topic
  /// pages whose contexts we were called from.
  void _popToHomeAndSwitchTab(BuildContext context, int index) {
    final navigator = Navigator.of(context);
    final navContext = navigator.context;
    navigator.popUntil((route) => route.isFirst);
    HomeScreen.switchTab(navContext, index);
  }

  /// Pops back through the topic detail and the topics index, then
  /// pushes [route] from the home shell.
  void _popToHomeAndPush(BuildContext context, Route<void> route) {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    navigator.push(route);
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.bullet});
  final _TopicBullet bullet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brass = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: brass.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(bullet.icon, color: brass, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                bullet.text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Disclaimer viewer ───────────────────────────

/// Read-only viewer for the safety disclaimer, surfaced from the
/// "Read Disclaimer" CTA on the disclaimer topic detail page. The
/// existing [DisclaimerScreen] is the first-launch acceptance gate
/// (with checkbox + accept button); this is just the body text in a
/// normal scrollable screen with a back arrow so users can re-read
/// the disclaimer at any time without re-accepting it.
class DisclaimerViewerScreen extends StatelessWidget {
  const DisclaimerViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Disclaimer & Safety')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: const _DisclaimerViewerBody(),
        ),
      ),
    );
  }
}

class _DisclaimerViewerBody extends StatelessWidget {
  const _DisclaimerViewerBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = theme.textTheme.titleLarge;
    final subheading = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final body = theme.textTheme.bodyMedium;

    return DefaultTextStyle.merge(
      style: body,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Important: This is reference information, not professional '
            'advice.',
            style: heading,
          ),
          const SizedBox(height: 16),
          const Text(
            'LoadOut helps you organize and reference data about reloading '
            'components, firearms, and cartridges. The information in this '
            'app — including reference catalogs of powders, bullets, primers, '
            'brass, firearms, and SAAMI cartridge specifications — is '
            'provided for informational and organizational purposes only.',
          ),
          const SizedBox(height: 16),
          Text('Reloading ammunition is inherently dangerous.',
              style: subheading),
          const SizedBox(height: 4),
          const Text(
            'Improper handloads can cause catastrophic firearm failure '
            'resulting in serious injury or death.',
          ),
          const SizedBox(height: 16),
          Text('You are responsible for verifying every recipe.',
              style: subheading),
          const SizedBox(height: 4),
          const Text(
            'Always cross-reference any recipe data against current published '
            'manuals from the powder, bullet, and firearm manufacturers '
            '(Hodgdon, Sierra, Hornady, Berger, etc.). Manufacturers update '
            'recipe data over time as components and testing equipment change.',
          ),
          const SizedBox(height: 16),
          Text('No warranty.', style: subheading),
          const SizedBox(height: 4),
          const Text(
            'LoadOut provides no warranty as to the accuracy, completeness, '
            'or safety of any data shown. Component lots vary, firearm '
            'chambers vary, and conditions vary.',
          ),
          const SizedBox(height: 16),
          Text('Your responsibility.', style: subheading),
          const SizedBox(height: 4),
          const Text('By using this app you agree that you:'),
          const SizedBox(height: 8),
          const _ViewerBullet(
            'Are of legal age to handle firearms and reloading components in '
            'your jurisdiction.',
          ),
          const _ViewerBullet(
            'Will follow all applicable federal, state, and local laws.',
          ),
          const _ViewerBullet('Will use proper safety equipment and procedures.'),
          const _ViewerBullet(
            'Will not rely on this app as your sole source of recipe data.',
          ),
          const _ViewerBullet(
            'Accept all risk associated with reloading and shooting.',
          ),
          const SizedBox(height: 16),
          Text('No professional relationship.', style: subheading),
          const SizedBox(height: 4),
          const Text(
            'LoadOut is not a substitute for instruction from a qualified '
            'handloader or gunsmith. If you are new to reloading, take a '
            'class or work with someone experienced before producing live '
            'ammunition.',
          ),
          const SizedBox(height: 16),
          Text('Liability.', style: subheading),
          const SizedBox(height: 4),
          const Text(
            'To the fullest extent permitted by law, the developer of '
            'LoadOut disclaims all liability for any damages arising from '
            'use of this app, including but not limited to property damage, '
            'personal injury, or death.',
          ),
        ],
      ),
    );
  }
}

class _ViewerBullet extends StatelessWidget {
  const _ViewerBullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8, top: 2),
            child: Text('•'),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
