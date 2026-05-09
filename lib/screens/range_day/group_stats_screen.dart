// FILE: lib/screens/range_day/group_stats_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Full-screen surface that shows the rich Group Statistics block —
// extreme spread, mean radius, group MOA, σ horizontal / σ vertical, the
// 90% Litz confidence interval (when N >= 3), and the centroid + zero-
// adjust paragraph — for the shots recorded in the current Range Day
// session. Entry point is the "Group Statistics" launcher tile inside
// `range_day_detail_screen.dart`; the user pushes here when they want a
// quiet, dedicated read of their group rather than glancing at a small
// inline card mid-session.
//
// The screen is purely a render of the values handed in by the parent.
// It does NOT subscribe to any repository or stream — the parent passes
// `shots`, `target`, `load`, `distanceYd`, and the unit / bullet-diameter
// preferences via the constructor. The only feedback channel back to the
// parent is `Navigator.pop(context, updatedShots)`, which the parent
// awaits to refresh its in-memory `_shots` list (e.g. after the user
// deletes a shot from inside this screen).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The Range Day Detail screen is the longest screen in the app — it
// originally housed the group-stats card, the moving-target card, the
// solution card, the target plot, the DOPE card, and the notes block in
// one scroll view. Two of those cards were judged by the operator to be
// "learning / verification activities," not "between-shots glances," so
// they earn dedicated routes. Hoisting the group-stats body out of the
// detail screen also shaves the detail-screen file's render path, which
// helps with the layout-time crashes the operator has been chasing.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// * The math is in `lib/services/ballistics/group_stats.dart` and is
//   pure — no Flutter, no Drift. We compute the [GroupStats] inside this
//   screen rather than asking the parent to pass a precomputed object,
//   because the parent's distance / bullet-diameter inputs can change
//   between the parent's last solve and this screen's mount. Recomputing
//   here keeps the displayed numbers in sync with the values the user
//   sees in the AppBar / hand-off summary.
// * Normalized impact coords are in [-1..1]; we convert to inches at the
//   target by multiplying by `targetWidthIn / 2` / `targetHeightIn / 2`.
//   Positive y is UP in the impact convention because that's what the
//   shooter's mental model expects ("0.4" high"). The detail screen
//   already uses this convention; we mirror it here so the math agrees.
// * The 90% confidence interval band is hidden when the sample size is
//   < 3 (the Rayleigh quantile table doesn't publish a multiplier most
//   references agree on at N=2) — see `_showCiBlock`.
// * `Navigator.pop(context, _shots)` returns the (potentially mutated)
//   shots list. Today the screen is read-only (delete / edit are still
//   on the detail screen's target plot), so the returned list always
//   matches the input — but the channel exists so a future "delete from
//   here" affordance lands safely without a contract change.
// * Layout safety: phone-first, single column. Tablet (`isWide`) keeps
//   the same one-column layout — group stats is not a master/detail
//   surface. No `Row + Expanded(button)` inside `Column.stretch` (the
//   pattern that crashed the screen previously); we use bare buttons or
//   `Wrap` for action rows.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/range_day/range_day_detail_screen.dart (only call site).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure render. The screen does not write to the database, does not
// touch sensors, and does not pull from the network. `Navigator.pop`
// returns the unchanged `shots` list to the parent.

import 'package:flutter/material.dart';

import '../../database/database.dart';
import '../../services/ballistics/group_stats.dart';
import '../../services/ballistics/units.dart' as bu;
import '../../widgets/glossary_label.dart';
import '../../widgets/range_day_safety.dart';

/// Full-screen presentation of the rich Group Statistics block for a
/// recorded set of shot impacts.
///
/// All inputs come from the parent (Range Day detail screen). Pop with
/// the (possibly mutated) shots list so the parent can sync its in-
/// memory cache.
class GroupStatsScreen extends StatefulWidget {
  const GroupStatsScreen({
    super.key,
    required this.shots,
    required this.targetWidthIn,
    required this.targetHeightIn,
    required this.distanceYd,
    required this.bulletDiameterIn,
    required this.correctionUnit,
    this.target,
    this.load,
  });

  /// Recorded impacts, normalized to [-1..1] in the target's coordinate
  /// system (impactX/impactY on `ShotImpactRow`).
  final List<ShotImpactRow> shots;

  /// Target visible width (inches). Drives the normalized→inches
  /// conversion used by the group-stats math.
  final double targetWidthIn;

  /// Target visible height (inches). Same purpose as [targetWidthIn].
  final double targetHeightIn;

  /// Session distance (yards). Used for MOA / mil conversions. Pass 0
  /// (or any non-positive) when distance is unset; the angular fields
  /// will render "—" rather than NaN.
  final double distanceYd;

  /// Bullet diameter (inches) for the active load. Added to extreme
  /// spread to produce the displayed "Group" measurement (the outside-
  /// edge caliper number). Pass 0 when no load / diameter is known.
  final double bulletDiameterIn;

  /// 'mil' | 'moa' | 'inches' — drives the angular column on the three
  /// big stat rows and the zero-adjust block. Mirrors the parent's
  /// `_correctionUnit` so the user reads the numbers in whatever system
  /// they are dialing the scope in.
  final String correctionUnit;

  /// Optional target row, shown in the AppBar subtitle for context.
  final TargetRow? target;

  /// Optional load row, shown in the AppBar subtitle for context.
  final UserLoadRow? load;

  @override
  State<GroupStatsScreen> createState() => _GroupStatsScreenState();
}

class _GroupStatsScreenState extends State<GroupStatsScreen> {
  /// Local mirror of `widget.shots`. Today this is the same list the
  /// parent handed in — the screen is read-only — but holding the list
  /// in state means a future "delete from here" affordance can mutate
  /// `_shots` and pop with the result without changing the public API.
  late List<ShotImpactRow> _shots;

  @override
  void initState() {
    super.initState();
    _shots = List<ShotImpactRow>.unmodifiable(widget.shots);
  }

  /// Convert the recorded normalized impacts to inches and run the
  /// pure-Dart [computeGroupStats]. Returns null when there are fewer
  /// than 2 shots (the math is undefined) — the caller renders an
  /// empty-state placeholder in that case.
  GroupStats? _computeStats() {
    if (_shots.length < 2) return null;
    final w = widget.targetWidthIn;
    final h = widget.targetHeightIn;
    final pts = [
      for (final s in _shots)
        Offset(s.impactX * (w / 2), s.impactY * (h / 2)),
    ];
    return computeGroupStats(
      points: pts,
      distanceYd: widget.distanceYd,
      bulletDiameterIn: widget.bulletDiameterIn,
    );
  }

  /// Subtitle for the AppBar that orients the user without making them
  /// hop back to the detail screen ("which load was this group from?").
  String? _subtitle() {
    final pieces = <String>[];
    if (widget.target != null) pieces.add(widget.target!.name);
    if (widget.load != null) pieces.add(widget.load!.name);
    if (widget.distanceYd > 0) {
      pieces.add('${widget.distanceYd.toStringAsFixed(0)} yd');
    }
    if (pieces.isEmpty) return null;
    return pieces.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = _subtitle();
    return PopScope<Object?>(
      // Forward the (possibly mutated) shots list to the parent on any
      // pop — system back gesture, AppBar back button, or an explicit
      // call. The parent uses it to refresh its `_shots` cache.
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        // No-op: the result is provided in `_popWithShots` for explicit
        // pops. The system back path leaves `_shots` unchanged; the
        // parent's await resolves to null and it keeps its current
        // cache. That's the documented contract.
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Group Statistics'),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        body: RangeDayErrorBoundary(
          label: 'group statistics',
          child: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: _buildBody(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final stats = _computeStats();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.scatter_plot,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    GlossaryLabel(
                      text: 'Group Statistics',
                      glossaryTerm: 'Group',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (stats != null)
                      Text(
                        '${stats.shotCount}-shot group',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (stats == null)
                  Text(
                    _shots.isEmpty
                        ? 'Record shots on the target plot to see group '
                            'statistics.'
                        : 'Need ≥2 shots to compute group statistics.',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  _statsBody(stats),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Renders the three "ES / MR / Group" rows, the SD pair, the optional
  /// 90% CI block, and the centroid + zero-adjust paragraph. Unit
  /// display for the MOA / MIL column tracks the per-session correction
  /// unit toggle so the user sees the numbers in the system they're
  /// dialing the scope in.
  Widget _statsBody(GroupStats stats) {
    final theme = Theme.of(context);
    final yards = widget.distanceYd;
    final unit = widget.correctionUnit;

    String fmtAngle(double inches) {
      switch (unit) {
        case 'mil':
          return yards <= 0
              ? '—'
              : '${bu.inchesToMilAtYards(inches, yards).toStringAsFixed(2)} mil';
        case 'moa':
          return yards <= 0
              ? '—'
              : '${bu.inchesToMoaAtYards(inches, yards).toStringAsFixed(2)} MOA';
        default:
          return ''; // inches: no separate angle column
      }
    }

    final showAngleColumn = unit != 'inches';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statRow(
          icon: Icons.adjust,
          label: 'ES',
          tooltip: 'Extreme spread (longest center-to-center)',
          inches: stats.extremeSpreadIn,
          showAngle: showAngleColumn,
          angleText: fmtAngle(stats.extremeSpreadIn),
        ),
        const SizedBox(height: 6),
        _statRow(
          icon: Icons.radio_button_checked,
          label: 'Mean R',
          tooltip: 'Mean distance from each shot to the group centroid',
          inches: stats.meanRadiusIn,
          showAngle: showAngleColumn,
          angleText: fmtAngle(stats.meanRadiusIn),
        ),
        const SizedBox(height: 6),
        _statRow(
          icon: Icons.crop_free,
          label: 'Group',
          tooltip: 'ES + bullet diameter (the outside-edge caliper '
              'measurement)',
          inches: stats.groupSizeIn,
          showAngle: showAngleColumn,
          angleText: fmtAngle(stats.groupSizeIn),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _smallStat(
                'σ horizontal',
                '${stats.horizontalSdIn.toStringAsFixed(2)}"',
              ),
            ),
            Expanded(
              child: _smallStat(
                'σ vertical',
                '${stats.verticalSdIn.toStringAsFixed(2)}"',
              ),
            ),
          ],
        ),
        if (_showCiBlock(stats)) ...[
          const SizedBox(height: 12),
          _ciBlock(stats, theme),
        ],
        const SizedBox(height: 12),
        _zeroAdjustBlock(stats, theme),
      ],
    );
  }

  /// True when the supplied stats include a 90% CI on the true group
  /// size — i.e. the sample size is large enough that the Rayleigh
  /// quantile table publishes a multiplier (N >= 3).
  bool _showCiBlock(GroupStats stats) =>
      stats.groupSizeCiLow90PctIn != null &&
      stats.groupSizeCiHigh90PctIn != null;

  /// Litz-style 90% confidence-interval block. Shows the user that the
  /// observed group size has uncertainty bands that depend on sample
  /// size, and adds a small coaching caption that gets less alarming as
  /// N grows. Color-coded: amber (N=3..4), yellow (N=5..9), green
  /// (N>=10).
  Widget _ciBlock(GroupStats stats, ThemeData theme) {
    final n = stats.shotCount;
    final unit = widget.correctionUnit;
    final yards = widget.distanceYd;

    // Tier classification — drives both the color and the caption.
    final ({Color band, Color text, String tier}) palette;
    if (n <= 4) {
      palette = (
        band: Colors.amber.withValues(alpha: 0.18),
        text: theme.brightness == Brightness.dark
            ? Colors.amber.shade200
            : Colors.amber.shade900,
        tier: 'wide',
      );
    } else if (n <= 9) {
      palette = (
        band: Colors.yellow.withValues(alpha: 0.18),
        text: theme.brightness == Brightness.dark
            ? Colors.yellow.shade200
            : Colors.yellow.shade900,
        tier: 'medium',
      );
    } else {
      palette = (
        band: Colors.green.withValues(alpha: 0.18),
        text: theme.brightness == Brightness.dark
            ? Colors.green.shade200
            : Colors.green.shade900,
        tier: 'tight',
      );
    }

    // Range string — angular when the user prefers MIL/MOA and we have
    // distance, otherwise inches.
    String rangeStr;
    if (unit == 'mil' && yards > 0) {
      final lo = bu.inchesToMilAtYards(stats.groupSizeCiLow90PctIn!, yards);
      final hi = bu.inchesToMilAtYards(stats.groupSizeCiHigh90PctIn!, yards);
      rangeStr =
          '${lo.toStringAsFixed(2)} – ${hi.toStringAsFixed(2)} mil';
    } else if (unit != 'inches' &&
        yards > 0 &&
        stats.groupMoaCiLow90Pct != null &&
        stats.groupMoaCiHigh90Pct != null) {
      rangeStr =
          '${stats.groupMoaCiLow90Pct!.toStringAsFixed(2)} – '
          '${stats.groupMoaCiHigh90Pct!.toStringAsFixed(2)} MOA';
    } else {
      rangeStr =
          '${stats.groupSizeCiLow90PctIn!.toStringAsFixed(2)}" – '
          '${stats.groupSizeCiHigh90PctIn!.toStringAsFixed(2)}"';
    }

    // Coaching caption tied to sample-size tier. Phrased as observation
    // rather than nag — Litz's whole point is that the shooter should
    // care, not that the app should hector.
    String caption;
    if (n == 3) {
      caption = 'Three shots is enough to start tracking, but the '
          'confidence band is wide. Shoot 2–7 more to halve the '
          'uncertainty.';
    } else if (n == 4) {
      caption = 'Four shots — the band is still wide. One or two more '
          'shots will tighten it noticeably.';
    } else if (n <= 9) {
      caption =
          'Reasonable sample. The CI tightens fast as you add shots.';
    } else if (n < 20) {
      caption = 'Solid sample size.';
    } else {
      caption =
          'Excellent sample size. Diminishing returns past here.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.band,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 16, color: palette.text),
              const SizedBox(width: 6),
              GlossaryLabel(
                text: '90% confidence interval',
                glossaryTerm: 'Confidence interval (90%)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Statistical confidence interval. The narrower '
                    "this range, the more reliably your group size "
                    "represents your rifle's true precision.",
                child: Icon(
                  Icons.info_outline,
                  size: 14,
                  color: palette.text.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'True precision: $rangeStr',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: palette.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.text.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// One "icon · label · inches · angle" row inside the stats body.
  /// Tooltip appears on long-press / hover so a curious shooter can see
  /// what the abbreviation stands for without cluttering the row.
  Widget _statRow({
    required IconData icon,
    required String label,
    required String tooltip,
    required double inches,
    required bool showAngle,
    required String angleText,
  }) {
    final theme = Theme.of(context);
    // Map the abbreviated row label to the matching glossary entry
    // so the (?) glyph leads to the right definition.
    final glossaryHint = _statRowGlossaryHintFor(label);
    return Tooltip(
      message: tooltip,
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: GlossaryLabel(
              text: label,
              glossaryTerm: glossaryHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${inches.toStringAsFixed(2)}"',
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (showAngle)
            SizedBox(
              width: 96,
              child: Text(
                angleText,
                textAlign: TextAlign.right,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Small label / value column used in the σ pair and the SD row. Same
  /// look as the parent screen's `_smallStat` so the shooter doesn't
  /// notice a typographic seam between the two surfaces.
  Widget _smallStat(String label, String value) {
    final theme = Theme.of(context);
    // σ horizontal / σ vertical map to the same "Standard Deviation"
    // glossary entry; soft-fails to plain Text on unknown labels.
    final glossaryHint = _smallStatGlossaryHintFor(label);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlossaryLabel(
          text: label,
          glossaryTerm: glossaryHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// Map per-row group-stat labels to glossary entries.
  String? _statRowGlossaryHintFor(String label) {
    switch (label) {
      case 'ES':
        return 'Extreme Spread';
      case 'Mean R':
        return 'Mean radius';
      case 'Group':
        return 'Group';
      default:
        return null;
    }
  }

  /// Map small stat labels (σ horizontal / σ vertical) to a useful
  /// glossary entry — both currently route to the statistical SD.
  String? _smallStatGlossaryHintFor(String label) {
    if (label.startsWith('σ')) return 'Standard Deviation (sample)';
    return null;
  }

  /// "Centroid: 0.4" right, 0.2" low → Suggested zero adjust: 0.4" left
  /// (← 0.07 mil), 0.2" up (↑ 0.03 mil)" — the user-facing reverse of
  /// the centroid offset, so the shooter can directly translate the
  /// numbers into scope-turret clicks.
  Widget _zeroAdjustBlock(GroupStats stats, ThemeData theme) {
    final cdx = stats.centroidIn.dx;
    final cdy = stats.centroidIn.dy;
    final unit = widget.correctionUnit;
    final yards = widget.distanceYd;

    String fmtIn(double v) => '${v.abs().toStringAsFixed(2)}"';
    String fmtAngle(double v) {
      switch (unit) {
        case 'mil':
          return yards <= 0
              ? ''
              : '${bu.inchesToMilAtYards(v.abs(), yards).toStringAsFixed(2)} mil';
        case 'moa':
          return yards <= 0
              ? ''
              : '${bu.inchesToMoaAtYards(v.abs(), yards).toStringAsFixed(2)} MOA';
        default:
          return '';
      }
    }

    String centroidLine;
    if (cdx.abs() < 0.05 && cdy.abs() < 0.05) {
      centroidLine = 'Centroid: on aim point';
    } else {
      final h = cdx.abs() < 0.05
          ? ''
          : '${fmtIn(cdx)} ${cdx >= 0 ? 'right' : 'left'}';
      final v = cdy.abs() < 0.05
          ? ''
          : '${fmtIn(cdy)} ${cdy >= 0 ? 'high' : 'low'}';
      final pieces = [h, v].where((s) => s.isNotEmpty).join(', ');
      centroidLine = 'Centroid: $pieces';
    }

    // Zero adjust is the reverse of the centroid: if the group is 0.4"
    // right, the user dials the scope 0.4" LEFT. Sign-flipping the
    // centroid is enough — the labels flip naturally.
    final adjustHRaw = -cdx;
    final adjustVRaw = -cdy;
    final hLabel = adjustHRaw.abs() < 0.05
        ? null
        : (adjustHRaw >= 0 ? ('right', '→') : ('left', '←'));
    final vLabel = adjustVRaw.abs() < 0.05
        ? null
        : (adjustVRaw >= 0 ? ('up', '↑') : ('down', '↓'));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(centroidLine, style: theme.textTheme.bodyMedium),
          if (hLabel != null || vLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              'Suggested zero adjust:',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            if (hLabel != null)
              Text(
                '${fmtIn(adjustHRaw)} ${hLabel.$1}'
                '${unit != 'inches' ? '  (${hLabel.$2} ${fmtAngle(adjustHRaw)})' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
            if (vLabel != null)
              Text(
                '${fmtIn(adjustVRaw)} ${vLabel.$1}'
                '${unit != 'inches' ? '  (${vLabel.$2} ${fmtAngle(adjustVRaw)})' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Group is centered — zero looks good.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
