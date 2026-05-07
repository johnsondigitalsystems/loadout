// FILE: lib/screens/ballistics/widgets/contribution_breakdown.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Renders an expandable "How your correction breaks down" card under the
// DOPE table on the ballistics screen. The card answers a question every
// long-range shooter asks once they internalize their drop chart:
//
//     "Of my 31 MOA dial-up at 1000 yards, how much is gravity, how much
//      is drag, how much is Coriolis, and how much is everything else?"
//
// We answer it by computing six trajectory variants — a "no physics"
// baseline plus each effect layered on cumulatively — and reporting the
// MARGINAL contribution of each effect as it's added on top of the
// previous ones. So the user sees, for the sample range of their choice
// (defaults to the longest sample on the DOPE table — that's where the
// contributions are most visible):
//
//     Total drop:                327.8 in   (31.3 MOA)
//       Geometric (sight height):  -13.5 in
//       Gravity:                  +207.4 in
//       Drag deceleration:        +123.4 in
//       Coriolis (vertical):      +  0.2 in
//       Wind:                       0.0 in
//       Spin drift:                 0.0 in
//
//     Total wind drift:          +85.9 in
//       Geometric:                  0.0 in
//       Gravity:                    0.0 in
//       Drag:                       0.0 in
//       Coriolis (E–W):            +0.4 in
//       Crosswind:                +75.7 in
//       Spin drift:                +9.8 in
//
// Each line is rendered with a small, signed horizontal bar that
// represents the contribution's magnitude relative to the largest
// |contribution| in the group. Rows colour-code each effect to a stable
// theme colour so users can pattern-match across runs.
//
// ============================================================================
// THE MATH — INCREMENTAL ATTRIBUTION (cumulative, ordered)
// ============================================================================
// Naive "leave-one-out" attribution (`contribution_X = full − solve_with_X_off`)
// fails badly at long range because it double-counts the dominant pairwise
// coupling between gravity and drag: a slower bullet (drag) spends longer
// under gravity and falls further. At 1000 yd for a 6.5 CM 140 gr ELD-M,
// that coupling is roughly 120 inches. Both `gravity_contribution_lone`
// and `drag_contribution_lone` include parts of it, so summing them
// overshoots the real drop by ~40 %.
//
// Instead we use an INCREMENTAL ATTRIBUTION:
//
//   1. Solve the trajectory with NO physics enabled. This is the
//      "baseline" — pure sight-height geometry, the bullet flies in a
//      straight line at the bisected zero angle (which is θ ≈ 0 with
//      no physics).
//   2. Add gravity only → `solve_g`. The marginal gravity contribution
//      is `solve_g − baseline`.
//   3. Add gravity + drag → `solve_gd`. The marginal drag contribution
//      is `solve_gd − solve_g`. Crucially, the drag × gravity coupling
//      term (the "slower bullet falls more" effect) ends up here,
//      where it intuitively belongs.
//   4. Add gravity + drag + Coriolis → `solve_gdc`. Marginal Coriolis
//      is `solve_gdc − solve_gd`.
//   5. Add gravity + drag + Coriolis + wind → `solve_gdcw`. Marginal
//      wind is `solve_gdcw − solve_gdc`.
//   6. Full physics → `full`. Marginal spin drift is `full − solve_gdcw`.
//
// The contributions sum EXACTLY to `full − baseline`, by construction
// (a telescoping series). Adding the geometric baseline back in then
// recovers `full`. So the user-visible breakdown ADDS UP — there's no
// hidden residual.
//
// The order (gravity → drag → Coriolis → wind → spin) is chosen to
// match the typical magnitude ordering for a long-range rifle solve.
// A different order would produce different marginal values for each
// effect (the Shapley value averages over all orderings, but at 5
// effects that's 120 solves — too expensive for a phone-side widget).
// We document the ordering choice in the widget's footnote so the user
// understands the attribution is order-dependent.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The breakdown is the kind of thing a competitive long-range shooter
// would build a spreadsheet to figure out. Bringing it into the app as
// a one-tap expansion lets them learn the dominant terms in their
// firing solution without leaving LoadOut. Pedagogically, it
// demystifies the DOPE table — readers see drag + drag×gravity
// coupling combine into a substantial chunk of their dial-up at
// extended ranges, even though most online shooting content focuses
// just on BC.
//
// We render the breakdown ONLY when there are samples to break down;
// if the parent's `_samples` list is empty (user hasn't tapped
// Calculate yet), we don't display the card at all.
//
// ============================================================================
// PERFORMANCE
// ============================================================================
// Each variant solve is one full trajectory solve, including the
// bisection-based zero finder. On a phone that's 5–15 ms per variant.
// Six variants = 30–90 ms. We compute the variants synchronously on
// expansion; the user sees a brief loading state, then the bars.
//
// Future optimisation if this becomes a bottleneck: cache the variants
// alongside the samples on the parent screen, and re-derive only when
// inputs change. For now the on-expand cost is invisible to the user.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. The widget is pure-functional: same inputs always render the
// same output. No I/O, no state mutation outside the local `_State`.

import 'package:flutter/material.dart';

import '../../../services/ballistics/environment.dart';
import '../../../services/ballistics/projectile.dart';
import '../../../services/ballistics/solver.dart';
import '../../../services/ballistics/units.dart';
import '../ballistics_screen.dart' show AngleUnit;

/// Expandable card that breaks the user's drop and wind correction
/// down into per-effect contributions (gravity, drag, Coriolis, wind,
/// spin drift) plus the underlying geometric baseline. Default is
/// collapsed; on expansion the variant solves run and the bars render.
class ContributionBreakdown extends StatefulWidget {
  const ContributionBreakdown({
    super.key,
    required this.projectile,
    required this.environment,
    required this.shot,
    required this.sampleRangesYards,
    required this.fullSamples,
    required this.unit,
  });

  /// The projectile description used by the parent's full solve. We
  /// re-use it verbatim for each variant solve — the breakdown is an
  /// A/B comparison between the same inputs and a single effect
  /// disabled.
  final Projectile projectile;

  /// The environment used by the parent's full solve.
  final Environment environment;

  /// The shot inputs (MV, sight height, zero range) used by the
  /// parent's full solve.
  final ShotInputs shot;

  /// The full ladder of sample ranges the parent solved at — same list
  /// passed to [solveTrajectory]. We solve every variant against this
  /// full ladder and read off the chosen sample range.
  final List<double> sampleRangesYards;

  /// The full-physics trajectory result. We pluck the chosen sample
  /// out of this list as the baseline against which each variant
  /// delta is computed.
  final List<TrajectorySample> fullSamples;

  /// Drop / wind unit toggle from the parent screen. We honour the
  /// user's choice so the breakdown lines up visually with the DOPE
  /// table immediately above.
  final AngleUnit unit;

  @override
  State<ContributionBreakdown> createState() => _ContributionBreakdownState();
}

/// Cached set of variant trajectories for the incremental
/// attribution. Each entry adds one effect on top of the previous
/// ones, in the documented order (gravity → drag → Coriolis → wind →
/// spin). The marginal contribution of each effect is the delta
/// between consecutive entries.
class _Variants {
  _Variants({
    required this.baseline,
    required this.gravity,
    required this.gravityDrag,
    required this.gravityDragCoriolis,
    required this.gravityDragCoriolisWind,
  });

  /// No physics at all. The bullet flies in a straight line at θ ≈ 0
  /// (the no-physics zero solver collapses to "aim horizontally").
  /// Drop is purely sight-height geometry: `sight_height × (1 − R/zero_range)`.
  final List<TrajectorySample> baseline;

  /// + Gravity. Bullet falls parabolically; the zero finder picks a
  /// real super-elevation angle.
  final List<TrajectorySample> gravity;

  /// + Drag. Bullet decelerates, time of flight grows, drop grows
  /// (drag × gravity coupling).
  final List<TrajectorySample> gravityDrag;

  /// + Coriolis. Adds the −2Ω×v acceleration in both axes.
  final List<TrajectorySample> gravityDragCoriolis;

  /// + Wind. Adds the relative-velocity offset that produces
  /// crosswind drift.
  final List<TrajectorySample> gravityDragCoriolisWind;
}

/// One row of the breakdown — a labeled, signed contribution rendered
/// as a numeric value plus a horizontal bar. Each row's [valueInches]
/// is the MARGINAL contribution of one physics effect: the delta
/// between two consecutive variant solves in the documented order.
class _ContribRow {
  _ContribRow({
    required this.label,
    required this.valueInches,
    required this.color,
  });

  final String label;
  final double valueInches;
  final Color color;
}

class _ContributionBreakdownState extends State<ContributionBreakdown> {
  /// Index into [widget.sampleRangesYards] / [widget.fullSamples] for
  /// the row we're breaking down. Defaults to the longest sample —
  /// that's where each contribution is most visible.
  int _selectedIndex = 0;

  /// Cached variants. Null until the user expands the card or the
  /// inputs change; in that case we re-solve.
  _Variants? _variants;

  /// Snapshot of inputs we last solved against; if any changes between
  /// builds (typically because the parent re-ran Calculate) we drop the
  /// cache.
  Object? _cacheKey;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _initialSelectedIndex();
  }

  @override
  void didUpdateWidget(covariant ContributionBreakdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-pick the longest range when the parent re-solved with a
    // different ladder. We keep the cache invalidation broad —
    // anything except an unchanged inputs identity drops the cache.
    final newKey = _buildCacheKey();
    if (newKey != _cacheKey) {
      _variants = null;
      _cacheKey = null;
      _selectedIndex = _initialSelectedIndex();
    }
  }

  /// Pick the index of the longest sample range. With the typical
  /// trajectory ladder (100 → 1000 yd), this is the last entry — the
  /// place where contributions are largest and most informative.
  int _initialSelectedIndex() {
    if (widget.fullSamples.isEmpty) return 0;
    var bestIdx = 0;
    var bestRange = widget.fullSamples[0].rangeYards;
    for (var i = 1; i < widget.fullSamples.length; i++) {
      if (widget.fullSamples[i].rangeYards > bestRange) {
        bestRange = widget.fullSamples[i].rangeYards;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// Identity-style key for the cache: a tuple of the inputs that
  /// affect the variant solves. We use [Object.hashAll] over the
  /// salient fields so two builds of the same parent state share the
  /// cached variants.
  Object _buildCacheKey() {
    return Object.hashAll([
      identityHashCode(widget.projectile),
      identityHashCode(widget.environment),
      identityHashCode(widget.shot),
      identityHashCode(widget.sampleRangesYards),
      widget.sampleRangesYards.length,
      if (widget.sampleRangesYards.isNotEmpty)
        widget.sampleRangesYards.first,
      if (widget.sampleRangesYards.isNotEmpty)
        widget.sampleRangesYards.last,
    ]);
  }

  /// Run all five cumulative variants. This is the expensive call —
  /// we do it on first expansion and cache the result. Five
  /// trajectory solves + one bisection per solve = ~50 ms on a
  /// phone.
  void _ensureVariants() {
    if (_variants != null) return;
    final ranges = widget.sampleRangesYards;
    _variants = _Variants(
      baseline: solveTrajectory(
        projectile: widget.projectile,
        environment: widget.environment,
        shot: widget.shot,
        sampleRangesYards: ranges,
        includeGravity: false,
        includeDrag: false,
        includeCoriolis: false,
        includeWind: false,
        includeSpinDrift: false,
      ),
      gravity: solveTrajectory(
        projectile: widget.projectile,
        environment: widget.environment,
        shot: widget.shot,
        sampleRangesYards: ranges,
        includeGravity: true,
        includeDrag: false,
        includeCoriolis: false,
        includeWind: false,
        includeSpinDrift: false,
      ),
      gravityDrag: solveTrajectory(
        projectile: widget.projectile,
        environment: widget.environment,
        shot: widget.shot,
        sampleRangesYards: ranges,
        includeGravity: true,
        includeDrag: true,
        includeCoriolis: false,
        includeWind: false,
        includeSpinDrift: false,
      ),
      gravityDragCoriolis: solveTrajectory(
        projectile: widget.projectile,
        environment: widget.environment,
        shot: widget.shot,
        sampleRangesYards: ranges,
        includeGravity: true,
        includeDrag: true,
        includeCoriolis: true,
        includeWind: false,
        includeSpinDrift: false,
      ),
      gravityDragCoriolisWind: solveTrajectory(
        projectile: widget.projectile,
        environment: widget.environment,
        shot: widget.shot,
        sampleRangesYards: ranges,
        includeGravity: true,
        includeDrag: true,
        includeCoriolis: true,
        includeWind: true,
        includeSpinDrift: false,
      ),
    );
    _cacheKey = _buildCacheKey();
  }

  /// Look up the sample at [index] in a variant solve. The variants
  /// share the same range ladder as `fullSamples`, but if a variant
  /// returned fewer entries (e.g. a zero-finder failure under an
  /// unusual configuration), we fall back to the full sample so the
  /// breakdown stays well-defined.
  TrajectorySample _lookup(List<TrajectorySample> variant, int index) {
    if (index >= 0 && index < variant.length) return variant[index];
    if (widget.fullSamples.isEmpty || index >= widget.fullSamples.length) {
      return TrajectorySample(
        rangeYards: 0,
        timeSec: 0,
        dropInches: 0,
        windDriftInches: 0,
        spinDriftInches: 0,
        velocityFps: 0,
        energyFtLb: 0,
        machNumber: 0,
      );
    }
    return widget.fullSamples[index];
  }

  /// Convert a contribution magnitude in inches to the display unit
  /// the user picked on the parent screen (inches / MOA / mil) at the
  /// sample's range.
  double _toDisplayUnit(double inches, double yards) {
    switch (widget.unit) {
      case AngleUnit.inches:
        return inches;
      case AngleUnit.moa:
        return inchesToMoaAtYards(inches, yards);
      case AngleUnit.mil:
        return inchesToMilAtYards(inches, yards);
    }
  }

  String _displayUnitLabel() {
    switch (widget.unit) {
      case AngleUnit.inches:
        return 'in';
      case AngleUnit.moa:
        return 'MOA';
      case AngleUnit.mil:
        return 'mil';
    }
  }

  /// Number of fractional digits to render. MOA/mil look natural at 2
  /// places; raw inches at 1.
  int _fractionDigits() {
    switch (widget.unit) {
      case AngleUnit.inches:
        return 1;
      case AngleUnit.moa:
        return 2;
      case AngleUnit.mil:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.fullSamples.isEmpty) return const SizedBox.shrink();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: (expanded) {
          if (expanded) {
            setState(() {
              _ensureVariants();
            });
          }
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        leading: Icon(
          Icons.insights_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          'How your correction breaks down',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'See what gravity, drag, wind, spin and Coriolis contribute',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final variants = _variants;
    if (variants == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final samples = widget.fullSamples;
    final chipIndices = _pickRangeChipIndices(samples.length);
    final selected = samples[_selectedIndex.clamp(0, samples.length - 1)];

    final dropRows = _buildDropRows(theme, variants, selected);
    final windRows = _buildWindRows(theme, variants, selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Range chooser. The bar magnitudes change as the user picks a
        // different range — this is the part the user explores.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final i in chipIndices)
              ChoiceChip(
                label: Text('${samples[i].rangeYards.toStringAsFixed(0)} yd'),
                selected: i == _selectedIndex,
                onSelected: (_) => setState(() => _selectedIndex = i),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _BreakdownGroup(
          title: 'Total drop',
          totalInches: selected.dropInches,
          rows: dropRows,
          rangeYards: selected.rangeYards,
          unit: widget.unit,
          unitLabel: _displayUnitLabel(),
          fractionDigits: _fractionDigits(),
          toDisplay: _toDisplayUnit,
        ),
        const SizedBox(height: 16),
        _BreakdownGroup(
          title: 'Total wind drift',
          totalInches: selected.windDriftInches,
          rows: windRows,
          rangeYards: selected.rangeYards,
          unit: widget.unit,
          unitLabel: _displayUnitLabel(),
          fractionDigits: _fractionDigits(),
          toDisplay: _toDisplayUnit,
        ),
        const SizedBox(height: 12),
        Text(
          'Each contribution is the marginal effect of adding one piece '
          'of physics on top of the previous ones, in the order: gravity '
          '→ drag → Coriolis → wind → spin. The drag row therefore '
          'includes the drag×gravity coupling (a slower bullet spends '
          'longer under gravity, which dominates beyond ~600 yd). The '
          'rows sum exactly to the displayed total.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Build the rows for the "drop" group. Drop is the vertical
  /// component, dominated by gravity and the drag×gravity coupling.
  ///
  /// Sign convention follows [TrajectorySample.dropInches]: positive =
  /// below LoS, i.e. the bullet has fallen by N inches relative to
  /// the line of sight. A POSITIVE contribution means "this effect
  /// pulls the bullet farther below LoS."
  List<_ContribRow> _buildDropRows(
    ThemeData theme,
    _Variants variants,
    TrajectorySample full,
  ) {
    final idx = _selectedIndex;
    final colors = _DropColors.fromTheme(theme);

    final base = _lookup(variants.baseline, idx).dropInches;
    final g = _lookup(variants.gravity, idx).dropInches;
    final gd = _lookup(variants.gravityDrag, idx).dropInches;
    final gdc = _lookup(variants.gravityDragCoriolis, idx).dropInches;
    final gdcw = _lookup(variants.gravityDragCoriolisWind, idx).dropInches;
    final all = full.dropInches; // gdcw + spin

    // Marginal contributions (telescoping sum equals all − base).
    final gravityMarginal = g - base;
    final dragMarginal = gd - g;
    final coriolisMarginal = gdc - gd;
    final windMarginal = gdcw - gdc;
    final spinMarginal = all - gdcw;

    return [
      _ContribRow(
        label: 'Geometric (sight ht)',
        valueInches: base,
        color: colors.baseline,
      ),
      _ContribRow(
        label: 'Gravity',
        valueInches: gravityMarginal,
        color: colors.gravity,
      ),
      _ContribRow(
        label: 'Drag deceleration',
        valueInches: dragMarginal,
        color: colors.drag,
      ),
      _ContribRow(
        label: 'Coriolis (vertical)',
        valueInches: coriolisMarginal,
        color: colors.coriolis,
      ),
      _ContribRow(
        label: 'Wind (vertical)',
        valueInches: windMarginal,
        color: colors.wind,
      ),
      _ContribRow(
        label: 'Spin drift (vertical)',
        valueInches: spinMarginal,
        color: colors.spin,
      ),
    ];
  }

  /// Build the rows for the "wind" group. Lateral drift, signed
  /// positive-right (matches [TrajectorySample.windDriftInches]). At
  /// typical ranges crosswind dominates, then spin drift, with
  /// Coriolis adding a small nudge on long off-axis shots.
  List<_ContribRow> _buildWindRows(
    ThemeData theme,
    _Variants variants,
    TrajectorySample full,
  ) {
    final idx = _selectedIndex;
    final colors = _WindColors.fromTheme(theme);

    final base = _lookup(variants.baseline, idx).windDriftInches;
    final g = _lookup(variants.gravity, idx).windDriftInches;
    final gd = _lookup(variants.gravityDrag, idx).windDriftInches;
    final gdc = _lookup(variants.gravityDragCoriolis, idx).windDriftInches;
    final gdcw = _lookup(variants.gravityDragCoriolisWind, idx).windDriftInches;
    final all = full.windDriftInches;

    final gravityMarginal = g - base;
    final dragMarginal = gd - g;
    final coriolisMarginal = gdc - gd;
    final windMarginal = gdcw - gdc;
    final spinMarginal = all - gdcw;

    return [
      _ContribRow(
        label: 'Geometric (sight ht)',
        valueInches: base,
        color: colors.baseline,
      ),
      _ContribRow(
        label: 'Gravity (lateral)',
        valueInches: gravityMarginal,
        color: colors.gravity,
      ),
      _ContribRow(
        label: 'Drag (lateral)',
        valueInches: dragMarginal,
        color: colors.drag,
      ),
      _ContribRow(
        label: 'Coriolis (E–W)',
        valueInches: coriolisMarginal,
        color: colors.coriolis,
      ),
      _ContribRow(
        label: 'Crosswind drift',
        valueInches: windMarginal,
        color: colors.wind,
      ),
      _ContribRow(
        label: 'Spin drift',
        valueInches: spinMarginal,
        color: colors.spin,
      ),
    ];
  }

  /// Select up to 5 evenly-spaced indices from `[0..n-1]`, always
  /// including the first and the last. With ≤5 samples we just return
  /// every index.
  List<int> _pickRangeChipIndices(int n) {
    if (n <= 5) {
      return [for (var i = 0; i < n; i++) i];
    }
    final picks = <int>{0};
    for (var k = 1; k <= 3; k++) {
      picks.add((k * (n - 1) / 4).round());
    }
    picks.add(n - 1);
    final sorted = picks.toList()..sort();
    return sorted;
  }
}

/// One labeled group of contribution rows (drop or wind). Renders the
/// total at the top and a stack of bars below.
class _BreakdownGroup extends StatelessWidget {
  const _BreakdownGroup({
    required this.title,
    required this.totalInches,
    required this.rows,
    required this.rangeYards,
    required this.unit,
    required this.unitLabel,
    required this.fractionDigits,
    required this.toDisplay,
  });

  final String title;
  final double totalInches;
  final List<_ContribRow> rows;
  final double rangeYards;
  final AngleUnit unit;
  final String unitLabel;
  final int fractionDigits;
  final double Function(double inches, double yards) toDisplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // We size the bars relative to the largest |contribution| in the
    // group rather than the total — that way a small total won't
    // crush all the bars to invisibility, and a single dominant
    // contribution doesn't push the smaller ones into pixel-noise
    // either. We then divide each row's bar fraction by this max.
    var barScale = totalInches.abs();
    for (final r in rows) {
      if (r.valueInches.abs() > barScale) barScale = r.valueInches.abs();
    }
    if (barScale < 1e-9) barScale = 1;

    final totalDisplay = toDisplay(totalInches, rangeYards);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_signed(totalDisplay, fractionDigits)} $unitLabel',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: _ContribBar(
                row: row,
                rangeYards: rangeYards,
                totalInches: totalInches,
                barScale: barScale,
                unitLabel: unitLabel,
                fractionDigits: fractionDigits,
                toDisplay: toDisplay,
              ),
            ),
        ],
      ),
    );
  }

  String _signed(double v, int digits) {
    if (v == 0) return v.toStringAsFixed(digits);
    final s = v.toStringAsFixed(digits);
    if (v > 0 && !s.startsWith('+') && !s.startsWith('-')) return '+$s';
    return s;
  }
}

/// One contribution row: label on the left, number + percent on the
/// right, and a horizontal bar. Bar grows from the left for positive
/// values and from the right for negative values, so the user can see
/// the sign at a glance.
class _ContribBar extends StatelessWidget {
  const _ContribBar({
    required this.row,
    required this.rangeYards,
    required this.totalInches,
    required this.barScale,
    required this.unitLabel,
    required this.fractionDigits,
    required this.toDisplay,
  });

  final _ContribRow row;
  final double rangeYards;
  final double totalInches;
  final double barScale;
  final String unitLabel;
  final int fractionDigits;
  final double Function(double inches, double yards) toDisplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = toDisplay(row.valueInches, rangeYards);
    final pct = totalInches.abs() < 1e-9
        ? 0.0
        : (row.valueInches / totalInches * 100);
    final fill = (row.valueInches.abs() / barScale).clamp(0.0, 1.0);
    final isNegative = row.valueInches < 0;

    return Row(
      children: [
        // Label column — fixed width so the bars line up.
        SizedBox(
          width: 150,
          child: Text(
            row.label,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        // Bar.
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 14,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.6),
              child: Align(
                alignment: isNegative
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fill,
                  heightFactor: 1.0,
                  child: Container(color: row.color),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Number + percent.
        SizedBox(
          width: 120,
          child: Text(
            '${_signed(display, fractionDigits)} $unitLabel '
            '(${pct.abs() >= 10 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1)}%)',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _signed(double v, int digits) {
    if (v == 0) return v.toStringAsFixed(digits);
    final s = v.toStringAsFixed(digits);
    if (v > 0 && !s.startsWith('+') && !s.startsWith('-')) return '+$s';
    return s;
  }
}

/// Stable colour palette for the drop group. We map each effect to a
/// distinct theme-derived hue so the user can pattern-match across
/// runs (and so colour-blind users get adequate contrast against the
/// surface background — the bars sit on a `surfaceContainerHighest`
/// tint).
class _DropColors {
  _DropColors({
    required this.baseline,
    required this.gravity,
    required this.drag,
    required this.coriolis,
    required this.wind,
    required this.spin,
  });

  factory _DropColors.fromTheme(ThemeData theme) {
    final cs = theme.colorScheme;
    return _DropColors(
      // Geometric baseline — outline tint, neutral grey-ish so it
      // doesn't compete with the physics rows visually.
      baseline: cs.outlineVariant,
      // Gravity — primary brand colour. It's the dominant effect, so
      // the bar is the most visually present.
      gravity: cs.primary,
      // Drag — secondary brand. Smaller magnitude on its own, but
      // grows fast at long range thanks to the drag×gravity coupling
      // attributed to it.
      drag: cs.secondary,
      // Coriolis — tertiary. Distinct from primary/secondary so the
      // user can see at a glance which slice is which.
      coriolis: cs.tertiary,
      // Wind — error/warm tone. Vertical wind is essentially zero on
      // the drop axis but we render the row for completeness.
      wind: cs.error,
      spin: cs.outline,
    );
  }

  final Color baseline;
  final Color gravity;
  final Color drag;
  final Color coriolis;
  final Color wind;
  final Color spin;
}

/// Stable colour palette for the wind group.
class _WindColors {
  _WindColors({
    required this.baseline,
    required this.gravity,
    required this.drag,
    required this.coriolis,
    required this.wind,
    required this.spin,
  });

  factory _WindColors.fromTheme(ThemeData theme) {
    final cs = theme.colorScheme;
    return _WindColors(
      baseline: cs.outlineVariant,
      gravity: cs.tertiary,
      drag: cs.outline,
      coriolis: cs.secondary,
      wind: cs.primary,
      spin: cs.error,
    );
  }

  final Color baseline;
  final Color gravity;
  final Color drag;
  final Color coriolis;
  final Color wind;
  final Color spin;
}
