// FILE: lib/services/hang_detector.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Catches situations where the LoadOut UI thread freezes (or stutters
// badly enough to feel like a freeze) and ships a non-fatal report to
// Firebase Crashlytics through the existing `CrashReporter` chokepoint.
// Two complementary detectors live in one singleton:
//
//   * **Heartbeat hang detection.** A `Timer.periodic` schedules itself
//     every `tickInterval` (default 1s). On each fire, it compares NOW
//     against the time the previous tick computed for "expected next
//     fire". If actual lateness > `hangThreshold` (default 3s), the UI
//     thread was blocked for at least that long — Dart's single-isolate
//     event loop couldn't service the timer. We log a non-fatal error
//     with the duration, the current scheduler phase, and the (already-
//     set) `current_route` custom key. Catches:
//       - Synchronous heavy work on the main isolate (parsing, image
//         decode, ballistics solver if it ever ran sync).
//       - Native plugin deadlocks that block the platform channel.
//       - Pathological build loops that don't quite throw but spin the
//         framework forever.
//
//   * **Slow-frame detection.** A `SchedulerBinding.addTimingsCallback`
//     observer inspects every rendered frame's wall-clock duration.
//     Frames > `slowFrameThreshold` (default 1s) get a distinct
//     non-fatal report. Catches:
//       - Animations that overshoot a single frame budget badly enough
//         to feel like a freeze.
//       - Range Day / ballistics charts that try to redraw with a huge
//         dataset in one pass.
//       - Layout passes that re-flow the entire scroll view.
//
// Public surface:
//
//   * `HangDetector.instance` — singleton.
//   * `start({ tickInterval, hangThreshold, slowFrameThreshold,
//     minReportSpacing })` — wires both detectors. Idempotent: a second
//     call replaces the active config.
//   * `stop()` — cancels the heartbeat + removes the timings callback.
//   * `debugSetEnabled(bool)` — visible-for-tests so widget tests can
//     suppress reports without having to spin up Firebase.
//
// Both detectors are no-ops when:
//   * `CrashReporter.instance.isEnabled` is false (user opted out, or
//     platform unsupported).
//   * The app is not in the foreground (we pause on
//     `AppLifecycleState.paused` / `inactive` / `hidden` so the OS
//     suspending the process doesn't get counted as a "hang").
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `CrashReporter` catches THROWN errors. Crashes that look like "the
// app froze for 10 seconds and then I force-closed it" never throw —
// the UI thread just stops servicing input. Without a hang detector,
// these never surface to engineering. Native ANR (Android) and
// MetricKit hang reports (iOS) cover the most pathological cases at
// the OS level, but they:
//   * Fire only after long thresholds (5s ANR, 250ms iOS hang) and
//     only on specific platforms.
//   * Don't have access to Flutter-side context (current route,
//     current schema version, breadcrumb log).
//   * Don't surface jank-level slow frames at all.
//
// A Dart-side hang detector closes the gap: every freeze longer than
// `hangThreshold` gets the SAME `current_route` custom key, the same
// `app_version` / `db_schema_version` / `platform`, and the same
// breadcrumb tail as a real crash report. An engineer triaging a
// "the app keeps locking up on the Range Day Solution screen" report
// can reconstruct the user's path the same way they would for any
// other crash.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The heartbeat itself runs on the UI thread. When the UI thread
//     is blocked, the timer DOESN'T fire — it queues. The detector
//     only sees the hang AFTER the thread unblocks and fires the
//     queued callback. That's fine for our use-case ("tell us a hang
//     happened, with how long it was") but means we can't intervene
//     mid-hang. Real-time intervention would need a second isolate or
//     a native watchdog, both of which are more weight than the
//     problem warrants.
//
//   * When the UI thread unblocks after a long hang, MULTIPLE timer
//     ticks may fire in rapid succession. Without spam protection
//     we'd record the same hang 10 times. We track the last report
//     time and refuse to report again within `minReportSpacing`
//     (default 30s).
//
//   * Foreground/background gating is mandatory. If we measured during
//     `AppLifecycleState.paused`, every backgrounded session would
//     report a multi-hour "hang" the moment the user reopened the
//     app. We hook `WidgetsBindingObserver.didChangeAppLifecycleState`
//     and pause/resume the timer accordingly. The frame-timings
//     callback naturally pauses with the framework, but we still
//     filter its reports with a foreground check to be safe.
//
//   * The `expectedNextTick` math has to RESET after every reported
//     hang. Otherwise a 30s hang would generate one report at t=3s,
//     then the next tick at t=30s would compare against the
//     pre-hang baseline and report ANOTHER hang of 27s, and so on.
//     We reset the baseline as soon as we record a hang.
//
//   * Slow-frame reports can fire dozens of times per second during
//     a real animation issue. The same `minReportSpacing` throttle
//     applies; we skip emit but keep the count for the eventual
//     report's `slow_frame_burst_count` key.
//
//   * Widget tests routinely take 100s of ms to perform initial
//     pumps (asset load, drift open, mock provider wiring). Without
//     a test gate, every test session would emit hang reports. We
//     never auto-`start` from `main.dart` during a test (`main.dart`
//     never runs in tests), and `debugSetEnabled(false)` is
//     available for any test that does explicitly start the
//     detector.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   - lib/main.dart — calls `start()` after `CrashReporter.initialize`.
//   - test/hang_detector_test.dart — exercises the heartbeat math and
//     the spam-throttle logic without a live Firebase connection.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
//   * Installs a `WidgetsBindingObserver` (lifecycle taps).
//   * Installs a `SchedulerBinding.addTimingsCallback` (per-frame).
//   * Owns a `Timer.periodic` that ticks every `tickInterval`.
//   * Calls `CrashReporter.recordError` (which may upload to Firebase
//     if Crashlytics is enabled and the network is up).
//   * `debugPrint`s every detected hang / slow frame in dev so
//     engineers see the same signal locally that ships to Firebase.

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'crash_reporter.dart';

/// Synthetic exception type the hang detector throws (well, records — we
/// never actually `throw` it) so Crashlytics groups all hang reports
/// under a single, recognisable issue. Keep the type stable; engineers
/// rely on the issue title being constant across releases for triage.
class AppHangDetected implements Exception {
  AppHangDetected(this.message);
  final String message;
  @override
  String toString() => 'AppHangDetected: $message';
}

/// Companion synthetic exception for the slow-frame detector. Distinct
/// type so Crashlytics groups slow-frame reports separately from
/// full-on hangs — different signal, different fix typically.
class SlowFrameDetected implements Exception {
  SlowFrameDetected(this.message);
  final String message;
  @override
  String toString() => 'SlowFrameDetected: $message';
}

/// Singleton hang + slow-frame detector. Wire from `main.dart` AFTER
/// `CrashReporter.initialize` so reports route through the same
/// privacy-aware pipeline as everything else.
class HangDetector with WidgetsBindingObserver {
  HangDetector._();
  static final HangDetector instance = HangDetector._();

  // ─────────────────── Configuration ───────────────────

  Duration _tickInterval = const Duration(seconds: 1);
  Duration _hangThreshold = const Duration(seconds: 3);
  Duration _slowFrameThreshold = const Duration(seconds: 1);
  Duration _minReportSpacing = const Duration(seconds: 30);

  // ─────────────────── Runtime state ───────────────────

  Timer? _heartbeat;
  DateTime? _expectedNextTick;
  DateTime? _lastHangReportAt;
  DateTime? _lastSlowFrameReportAt;
  TimingsCallback? _timingsCallback;
  bool _isForeground = true;
  bool _enabled = true;
  bool _started = false;

  // Counters for back-to-back slow frames that get throttled — we
  // surface the swallowed count on the next report we DO emit so the
  // engineer knows the burst was bigger than a single frame.
  int _suppressedSlowFrameBurst = 0;

  /// Visible for tests. When false, `start` becomes a no-op and any
  /// pending detection paths refuse to emit.
  @visibleForTesting
  void debugSetEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) stop();
  }

  /// True when the detector is currently observing. Useful for tests
  /// and for any future "diagnostics" surface in Settings.
  bool get isRunning => _started;

  /// Wire both detectors. Safe to call again to change thresholds —
  /// the previous timer + callback are torn down first.
  ///
  /// Defaults are tuned for the LoadOut workload:
  ///   * `tickInterval = 1s` — fine-grained enough to catch sub-second
  ///     blocks, cheap enough that the periodic timer is invisible in
  ///     a profile.
  ///   * `hangThreshold = 3s` — anything shorter than this looks like
  ///     ordinary jank; users start force-quitting around 5s; 3s is
  ///     the sweet spot for "definitely a freeze, but we caught it
  ///     before the user gave up".
  ///   * `slowFrameThreshold = 1s` — well above any legitimate frame
  ///     budget (60fps = 16ms, 120fps = 8ms). A 1s frame is always
  ///     a bug; lower thresholds would flood the report stream with
  ///     normal scroll/paint jank.
  ///   * `minReportSpacing = 30s` — protects against a single freeze
  ///     producing N piled-up timer ticks all reporting "yep,
  ///     something hung".
  void start({
    Duration tickInterval = const Duration(seconds: 1),
    Duration hangThreshold = const Duration(seconds: 3),
    Duration slowFrameThreshold = const Duration(seconds: 1),
    Duration minReportSpacing = const Duration(seconds: 30),
  }) {
    if (!_enabled) return;
    // Re-entrant: rebuild from scratch with the new config.
    stop();

    _tickInterval = tickInterval;
    _hangThreshold = hangThreshold;
    _slowFrameThreshold = slowFrameThreshold;
    _minReportSpacing = minReportSpacing;

    final binding = WidgetsBinding.instance;
    binding.addObserver(this);

    _expectedNextTick = DateTime.now().add(_tickInterval);
    _heartbeat = Timer.periodic(_tickInterval, _onHeartbeat);

    _timingsCallback = _onFrameTimings;
    binding.addTimingsCallback(_timingsCallback!);

    _started = true;
  }

  /// Tear down the heartbeat + timings callback. Safe to call when
  /// already stopped.
  void stop() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _expectedNextTick = null;

    final binding = WidgetsBinding.instance;
    binding.removeObserver(this);
    final cb = _timingsCallback;
    if (cb != null) {
      binding.removeTimingsCallback(cb);
      _timingsCallback = null;
    }
    _started = false;
  }

  // ─────────────────── Lifecycle observer ───────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foregroundNow = state == AppLifecycleState.resumed;
    // When transitioning OUT of foreground, drop the timer baseline so
    // we don't measure suspended-process time as a hang the moment we
    // resume. When transitioning back IN, set a fresh baseline before
    // the next tick fires.
    if (_isForeground && !foregroundNow) {
      _expectedNextTick = null;
    } else if (!_isForeground && foregroundNow) {
      _expectedNextTick = DateTime.now().add(_tickInterval);
    }
    _isForeground = foregroundNow;
  }

  // ─────────────────── Heartbeat detector ───────────────────

  void _onHeartbeat(Timer _) {
    if (!_enabled || !_isForeground) return;
    final now = DateTime.now();
    final expected = _expectedNextTick;
    _expectedNextTick = now.add(_tickInterval);
    if (expected == null) return;

    final lateness = now.difference(expected);
    if (lateness <= _hangThreshold) return;

    if (_recentlyReported(_lastHangReportAt)) return;
    _lastHangReportAt = now;

    // Capture the framework's current phase as a stable identifier —
    // helps distinguish "blocked during build" from "blocked during
    // an idle period waiting on a microtask".
    final phase = SchedulerBinding.instance.schedulerPhase.name;
    final lateMs = lateness.inMilliseconds;

    debugPrint(
      '[HangDetector] UI thread blocked for ${lateMs}ms '
      '(phase=$phase). Recording non-fatal.',
    );

    // ignore: discarded_futures
    CrashReporter.instance.recordError(
      AppHangDetected('UI thread blocked for ${lateMs}ms'),
      StackTrace.current,
      reason: 'app_hang',
      fatal: false,
      extras: <String, Object>{
        'hang_duration_ms': lateMs,
        'hang_threshold_ms': _hangThreshold.inMilliseconds,
        'scheduler_phase': phase,
      },
    );
  }

  // ─────────────────── Slow-frame detector ───────────────────

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_enabled || !_isForeground) return;
    for (final t in timings) {
      final total = t.totalSpan;
      if (total < _slowFrameThreshold) continue;

      if (_recentlyReported(_lastSlowFrameReportAt)) {
        _suppressedSlowFrameBurst++;
        continue;
      }
      final burst = _suppressedSlowFrameBurst;
      _suppressedSlowFrameBurst = 0;
      _lastSlowFrameReportAt = DateTime.now();

      final totalMs = total.inMilliseconds;
      final buildMs = t.buildDuration.inMilliseconds;
      final rasterMs = t.rasterDuration.inMilliseconds;

      debugPrint(
        '[HangDetector] slow frame: ${totalMs}ms '
        '(build=${buildMs}ms raster=${rasterMs}ms, '
        'suppressed_burst=$burst).',
      );

      // ignore: discarded_futures
      CrashReporter.instance.recordError(
        SlowFrameDetected('Frame took ${totalMs}ms to render'),
        StackTrace.current,
        reason: 'slow_frame',
        fatal: false,
        extras: <String, Object>{
          'frame_total_ms': totalMs,
          'frame_build_ms': buildMs,
          'frame_raster_ms': rasterMs,
          'frame_threshold_ms': _slowFrameThreshold.inMilliseconds,
          'slow_frame_burst_count': burst,
        },
      );
      // One report per timings batch is plenty — the spacing throttle
      // would catch any extras anyway.
      return;
    }
  }

  bool _recentlyReported(DateTime? last) {
    if (last == null) return false;
    return DateTime.now().difference(last) < _minReportSpacing;
  }
}
