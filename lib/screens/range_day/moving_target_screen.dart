// FILE: lib/screens/range_day/moving_target_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Pro full-screen surface for the Moving Target lead calculator + the
// animated mover. The user picks a mover speed (mph) and a direction
// (R→L or L→R), and the screen renders the required lead in the active
// correction unit (MOA / mil / inches), broken out into "Center" hold
// and "Front edge" hold. An animated horizontal sweep visualizes the
// target moving across the field of view at the chosen speed, with the
// computed lead drawn as an offset reticle so the shooter sees what the
// hold actually looks like before they take the field shot.
//
// Entry point is the "Moving Target" launcher tile in
// `range_day_detail_screen.dart`. The launcher tile fires `ensurePro`
// before pushing this route, so by the time we render the body the user
// is already entitled — but we keep the inner ProGate wrap on the
// animated-mover affordance for defense-in-depth.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Moving-target lead is a "verification / training" surface, not a
// between-shots glance. The user practices reading lead by sitting with
// the speed knob, watching the animated mover, and getting comfortable
// with what 0.4 mil of lead actually looks like at 600 yd. That belongs
// on its own screen, away from the firing-solution / target-plot
// surfaces the user lives in mid-session. Hoisting it out also shaves
// the Range Day Detail screen's render path, which helps with the
// layout-time crashes the operator has been chasing.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// * The animation controller's lifecycle MUST be tied to this screen's
//   `dispose`. SingleTickerProviderStateMixin is the cleanest way to do
//   that — it auto-disposes the ticker. Forgetting to dispose leaks a
//   wall-clock subscription and bleeds CPU after the user pops back to
//   the detail screen.
// * Lead math: `lead_inches = speed_mph * 17.6 * tof_sec`. 1 mph = 17.6
//   inches/second; the TOF comes from the parent's solver. If the
//   parent didn't pass a TOF (no firing solution at this distance), the
//   lead is undefined — render an explanatory placeholder rather than
//   showing 0.0 (which would look like "no lead needed" and is wrong).
// * Front-edge hold is `center_lead - target_width/2`. When the user is
//   ambushing the leading edge of the target instead of the center,
//   they hold less lead because the target's own width is part of the
//   intercept. Negative front-edge values are physically meaningful
//   (the target is wider than the lead — hold straight on the leading
//   edge). We surface them as-is rather than clamping.
// * Layout safety: phone-first single-column layout. Tablet keeps the
//   same one-column layout — moving target is not a master/detail
//   surface. No `Row + Expanded(button)` inside `Column.stretch` (the
//   pattern that crashed the screen previously). Action rows use bare
//   buttons or `Wrap`.
// * Pro gating is double-walled: the launcher in the parent calls
//   `ensurePro` before pushing, AND the body wraps the animated mover
//   in `ProGate`. The lead-numbers panel itself stays Pro since the
//   entire screen is Pro, but the inner gate keeps the visual mover
//   gracefully locked even if the screen is reachable through a future
//   surface that bypasses the launcher.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/range_day/range_day_detail_screen.dart (only call site).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// * Drives an animation controller (no GPU work — paints a single
//   horizontally-translated rect inside a CustomPaint).
// * No database, no network, no sensor reads. Pure render of the
//   constructor inputs plus a local UI knob (mover speed / direction).

import 'package:flutter/material.dart';

import '../../database/database.dart';
import '../../services/ballistics/solver.dart';
import '../../services/ballistics/units.dart' as bu;
import '../../widgets/glossary_label.dart';
import '../../widgets/pro_gate.dart';
import '../../widgets/range_day_safety.dart';

/// Full-screen Pro presentation of the moving-target lead calculator
/// and animated mover. Mover speed / direction are local to this screen
/// and forgotten on pop — they're "what if" knobs, not session state.
class MovingTargetScreen extends StatefulWidget {
  const MovingTargetScreen({
    super.key,
    required this.solution,
    required this.distanceYd,
    required this.correctionUnit,
    this.target,
  });

  /// Firing-solution sample for the active distance, computed by the
  /// parent. We need [TrajectorySample.timeSec] for the lead math; the
  /// rest of the sample is not used directly here. Null when the parent
  /// hasn't produced a solution yet — the screen renders an explanatory
  /// placeholder in the lead block rather than fabricating a number.
  final TrajectorySample? solution;

  /// Session distance (yards). Used for MOA / mil conversions and the
  /// AppBar subtitle.
  final double distanceYd;

  /// 'mil' | 'moa' | 'inches' — the parent's session-level correction
  /// unit. Drives which value is the headline ("0.4 MOA" vs "0.12 mil"
  /// vs "1.5 in") so the user reads the lead in the system they're
  /// already dialing in.
  final String correctionUnit;

  /// Optional target row, used to compute the front-edge lead and
  /// render the animated mover at the right relative width. Null when
  /// no target is selected — the front-edge breakdown is hidden.
  final TargetRow? target;

  @override
  State<MovingTargetScreen> createState() => _MovingTargetScreenState();
}

class _MovingTargetScreenState extends State<MovingTargetScreen>
    with SingleTickerProviderStateMixin {
  // ─────────────────────── Local UI state ───────────────────────
  /// Mover speed in mph. Default of 3 mph matches a brisk walking
  /// human / common deer pace; the user can dial up to running speeds.
  late final TextEditingController _speedCtrl;

  /// Mover direction. 'rtl' = right-to-left (the more common spec for a
  /// tactical mover), 'ltr' = left-to-right.
  String _direction = 'rtl';

  // ─────────────────────── Animation state ───────────────────────
  /// True when the visual mover is sweeping. Default off — the user
  /// taps Play to start the animation. Keeping it off on mount means
  /// the screen is quiet for users who only want the lead numbers.
  bool _animating = false;

  /// Sweep duration multiplier. 1.0 = real-time at 1× the chosen mph
  /// (a 3 mph mover sweeping a 60 ft FOV takes ~13.6 s); higher
  /// multipliers slow the animation down for clearer visual study.
  /// Range is [_minMultiplier, _maxMultiplier].
  double _slowdown = 1.0;
  static const double _minMultiplier = 0.5;
  static const double _maxMultiplier = 4.0;

  /// Base sweep duration at slowdown=1× and speed=1mph. Re-computed
  /// when the user changes speed so the animation visually matches the
  /// chosen mph. Floored to a sane minimum so 50 mph doesn't try to
  /// sweep in 0.05s and chew CPU.
  static const int _baseSweepMsAt1Mph = 13600; // ~60ft / 1mph
  static const int _minSweepMs = 600;

  late AnimationController _moverController;

  @override
  void initState() {
    super.initState();
    // Empty default — user enters the actual mover speed (CLAUDE.md
    // § 0 anti-fake-data rule). Lead computation hides until a
    // value is typed.
    _speedCtrl = TextEditingController();
    _moverController = AnimationController(
      vsync: this,
      duration: _computeSweepDuration(),
    );
  }

  @override
  void dispose() {
    _speedCtrl.dispose();
    _moverController.dispose();
    super.dispose();
  }

  /// Sweep duration based on the current speed and slowdown multiplier.
  /// Faster mph → shorter sweep. Higher slowdown → longer sweep. Result
  /// is clamped so the controller never gets a 0-ms duration.
  Duration _computeSweepDuration() {
    final speed = double.tryParse(_speedCtrl.text.trim()) ?? 3.0;
    final effectiveSpeed = speed.clamp(0.5, 30.0);
    final ms = (_baseSweepMsAt1Mph * _slowdown / effectiveSpeed).round();
    return Duration(milliseconds: ms < _minSweepMs ? _minSweepMs : ms);
  }

  /// Restart the controller's sweep timer at the current speed /
  /// slowdown. Called on speed changes, slowdown changes, and when the
  /// user toggles Play.
  void _resyncMover() {
    final wasRunning = _moverController.isAnimating;
    _moverController.duration = _computeSweepDuration();
    if (wasRunning) {
      _moverController.repeat(reverse: true);
    }
  }

  void _toggleAnimation(bool on) {
    setState(() => _animating = on);
    if (on) {
      _moverController.repeat(reverse: true);
    } else {
      _moverController.stop();
      _moverController.value = 0.5;
    }
  }

  /// Subtitle for the AppBar — orients the user to which session
  /// context they're computing lead for.
  String? _subtitle() {
    final pieces = <String>[];
    if (widget.target != null) pieces.add(widget.target!.name);
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Moving Target'),
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
        label: 'moving target',
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _leadCard(theme),
                const SizedBox(height: 12),
                ProGate(
                  feature: 'Animated mover',
                  child: _animatedMoverCard(theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Speed + direction" inputs and the computed Center / Front-edge
  /// lead numbers. Free of any animation — works whether or not the
  /// user has Pro (the launcher in the parent already gated us, but
  /// this card stands alone to keep the lead numbers visible even if
  /// the animated mover below is locked).
  Widget _leadCard(ThemeData theme) {
    final tof = widget.solution?.timeSec;
    final speedMph = double.tryParse(_speedCtrl.text.trim()) ?? 0;
    final yards = widget.distanceYd;

    // Lead calc: lead_inches = speed_mph * mph_to_ips * tof.
    // 1 mph = 17.6 inches/second.
    final leadIn = (tof == null) ? null : speedMph * 17.6 * tof;
    final leadMoa = (leadIn == null || yards <= 0)
        ? null
        : bu.inchesToMoaAtYards(leadIn, yards);
    final leadMil = (leadIn == null || yards <= 0)
        ? null
        : bu.inchesToMilAtYards(leadIn, yards);
    final centerLeadIn = leadIn;
    final frontEdgeLeadIn = (leadIn == null || widget.target == null)
        ? null
        : leadIn - widget.target!.widthIn / 2;
    final frontEdgeLeadMoa = (frontEdgeLeadIn == null || yards <= 0)
        ? null
        : bu.inchesToMoaAtYards(frontEdgeLeadIn, yards);
    final frontEdgeLeadMil = (frontEdgeLeadIn == null || yards <= 0)
        ? null
        : bu.inchesToMilAtYards(frontEdgeLeadIn, yards);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_run,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                GlossaryLabel(
                  text: 'Lead Calculator',
                  glossaryTerm: 'Lead',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _speedCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      // `label:` (Widget) lets the GlossaryLabel
                      // provide tap-to-define for the Speed field.
                      // Soft-fails if no entry exists yet.
                      label: GlossaryLabel(
                        text: 'Speed',
                        glossaryTerm: 'Lead',
                      ),
                      suffixText: 'mph',
                      isDense: true,
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _resyncMover();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'rtl', label: Text('R→L')),
                      ButtonSegment(value: 'ltr', label: Text('L→R')),
                    ],
                    selected: {_direction},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _direction = s.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (tof == null)
              Text(
                'Lead requires a firing solution at the current distance. '
                'Set up a load and distance back on the Range Day screen, '
                'then return here.',
                style: theme.textTheme.bodySmall,
              )
            else ...[
              _bigStat(
                label: 'Center',
                primary: centerLeadIn == null
                    ? '—'
                    : _headlineLead(
                        leadIn: centerLeadIn,
                        leadMoa: leadMoa,
                        leadMil: leadMil,
                      ),
                secondary: centerLeadIn == null
                    ? '—'
                    : _secondaryLead(
                        leadIn: centerLeadIn,
                        leadMoa: leadMoa,
                        leadMil: leadMil,
                      ),
              ),
              const SizedBox(height: 8),
              _bigStat(
                label: 'Front',
                primary: frontEdgeLeadIn == null
                    ? '—'
                    : _headlineLead(
                        leadIn: frontEdgeLeadIn,
                        leadMoa: frontEdgeLeadMoa,
                        leadMil: frontEdgeLeadMil,
                      ),
                secondary: frontEdgeLeadIn == null
                    ? '—'
                    : _secondaryLead(
                        leadIn: frontEdgeLeadIn,
                        leadMoa: frontEdgeLeadMoa,
                        leadMil: frontEdgeLeadMil,
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                'Front-edge hold = center lead minus half the target’s '
                'visual width. Mover travels '
                '${_direction == 'rtl' ? 'right to left' : 'left to right'}.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Primary (headline) string for a lead value, in the parent's
  /// preferred unit.
  String _headlineLead({
    required double leadIn,
    required double? leadMoa,
    required double? leadMil,
  }) {
    switch (widget.correctionUnit) {
      case 'mil':
        return leadMil == null
            ? '—'
            : '${leadMil.toStringAsFixed(2)} mil';
      case 'moa':
        return leadMoa == null
            ? '—'
            : '${leadMoa.toStringAsFixed(1)} MOA';
      default:
        return '${leadIn.toStringAsFixed(1)} in';
    }
  }

  /// Secondary line — the two units the user did NOT pick, for cross-
  /// reference. Ordering keeps inches at the end so the eye lands on
  /// the angular value first.
  String _secondaryLead({
    required double leadIn,
    required double? leadMoa,
    required double? leadMil,
  }) {
    final pieces = <String>[];
    switch (widget.correctionUnit) {
      case 'mil':
        if (leadMoa != null) pieces.add('${leadMoa.toStringAsFixed(1)} MOA');
        pieces.add('${leadIn.toStringAsFixed(1)} in');
        break;
      case 'moa':
        if (leadMil != null) pieces.add('${leadMil.toStringAsFixed(2)} mil');
        pieces.add('${leadIn.toStringAsFixed(1)} in');
        break;
      default:
        if (leadMoa != null) pieces.add('${leadMoa.toStringAsFixed(1)} MOA');
        if (leadMil != null) pieces.add('${leadMil.toStringAsFixed(2)} mil');
        break;
    }
    return pieces.join(' · ');
  }

  /// Animated horizontal sweep visualization. Pro-gated via the outer
  /// `ProGate` wrap — non-Pro users see the lock tile and can tap
  /// through to the paywall.
  Widget _animatedMoverCard(ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.animation,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Animated Mover',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Watch the target sweep across the field of view at the chosen '
              'speed. The reticle stays put; the lead is shown as the visible '
              'gap between reticle and target leading edge when the mover is '
              'at center FOV.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            // Single Wrap (not Row+Expanded) so we never trip the
            // Column.stretch / Expanded crash documented in the file
            // header. Wrap will line-break gracefully at narrow widths.
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _toggleAnimation(!_animating),
                  icon: Icon(_animating
                      ? Icons.pause
                      : Icons.play_arrow),
                  label: Text(_animating ? 'Pause' : 'Play'),
                ),
                Text(
                  'Slowdown ${_slowdown.toStringAsFixed(1)}×',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            Slider(
              value: _slowdown,
              min: _minMultiplier,
              max: _maxMultiplier,
              divisions: 7,
              label: '${_slowdown.toStringAsFixed(1)}×',
              onChanged: (v) {
                setState(() => _slowdown = v);
                _resyncMover();
              },
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: AnimatedBuilder(
                animation: _moverController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _MoverPainter(
                      // Animation controller value sweeps 0..1..0..1 in
                      // reverse mode. Map to a horizontal position
                      // (-1..1) honoring the chosen direction so R→L
                      // starts at the right edge.
                      progress: _moverController.value,
                      direction: _direction,
                      targetWidthRel: _targetWidthRelative(),
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: theme.colorScheme.primary,
                      lineColor:
                          theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      reticleColor:
                          theme.colorScheme.onSurface.withValues(
                        alpha: 0.85,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _animating
                  ? 'Sweeping at ${_speedDisplay()} mph (slowed ${_slowdown.toStringAsFixed(1)}×).'
                  : 'Tap Play to sweep the target across the FOV.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Target width as a fraction of the FOV width [0..1]. Falls back to
  /// 0.18 when no target is selected — enough to draw a visible blob
  /// without the user having configured the screen first.
  double _targetWidthRelative() {
    if (widget.target == null) return 0.18;
    // Picture the FOV as ~6 mil wide at 10x — 36 inches per yard, so a
    // 60 ft (720 in) field at the rendered range. Compute the target's
    // visible fraction of that field.
    final yards = widget.distanceYd <= 0 ? 100.0 : widget.distanceYd;
    final fovInches = yards * 36.0 * 0.1; // 0.1 = arbitrary scale knob
    if (fovInches <= 0) return 0.18;
    return (widget.target!.widthIn / fovInches).clamp(0.04, 0.40);
  }

  String _speedDisplay() {
    final v = double.tryParse(_speedCtrl.text.trim());
    return v == null ? '—' : v.toStringAsFixed(1);
  }

  /// Inline copy of the parent's `_bigStat` helper so the lead numbers
  /// stay visually identical to the rest of the Range Day screens.
  Widget _bigStat({
    required String label,
    required String primary,
    required String secondary,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            // GlossaryLabel here gives "Lead" labels (when used) the
            // (?) tap-to-define affordance. "Center" / "Front" labels
            // soft-fail to plain Text; that's the intended behavior.
            child: GlossaryLabel(
              text: label,
              glossaryTerm: label == 'Center' || label == 'Front'
                  ? 'Lead'
                  : null,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primary,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  secondary,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the animated mover. Draws a horizon line, a
/// fixed crosshair reticle in the FOV center, and the moving target as
/// a colored rectangle whose position is driven by [progress].
///
/// The animation controller runs 0..1..0..1 in reverse mode. We re-map
/// to a horizontal screen position based on the chosen [direction] so
/// "R→L" starts at the right edge and travels left.
class _MoverPainter extends CustomPainter {
  _MoverPainter({
    required this.progress,
    required this.direction,
    required this.targetWidthRel,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.lineColor,
    required this.reticleColor,
  });

  final double progress;
  final String direction; // 'rtl' | 'ltr'
  final double targetWidthRel; // [0..1] fraction of canvas width
  final Color backgroundColor;
  final Color foregroundColor;
  final Color lineColor;
  final Color reticleColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Background.
    final bg = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, bg);

    // Horizon line — visual anchor so the moving target reads as
    // moving across a field, not floating in space.
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;
    final horizonY = size.height * 0.6;
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      linePaint,
    );

    // Reticle — fixed crosshair at FOV center.
    final reticlePaint = Paint()
      ..color = reticleColor
      ..strokeWidth = 1.5;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.shortestSide * 0.06;
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), reticlePaint);
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), reticlePaint);
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.18,
      Paint()..color = reticleColor,
    );

    // Target — a soft rectangle traveling left/right.
    final w = size.width * targetWidthRel;
    final h = size.height * 0.32;
    // Map progress (0..1, ping-pong via reverse) to a horizontal sweep.
    // For LTR the target enters from the left at progress=0; for RTL
    // it enters from the right at progress=0.
    final t = direction == 'rtl' ? (1.0 - progress) : progress;
    final x = (size.width + w) * t - w;
    final y = horizonY - h * 0.85;
    final rect = Rect.fromLTWH(x, y, w, h);
    final fg = Paint()..color = foregroundColor.withValues(alpha: 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _MoverPainter old) =>
      old.progress != progress ||
      old.direction != direction ||
      old.targetWidthRel != targetWidthRel ||
      old.foregroundColor != foregroundColor;
}
