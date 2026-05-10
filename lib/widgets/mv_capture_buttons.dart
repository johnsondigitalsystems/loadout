// FILE: lib/widgets/mv_capture_buttons.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Reusable affordance row that lets the user populate a Muzzle Velocity
// field from one of two real-world sources:
//
//   * **From Garmin Xero** — opens the OS file picker for a `.fit` file
//     the user exported from a Garmin Xero C1 Pro chronograph, parses
//     it via [GarminXeroService], and hands back the session AVERAGE
//     fps (the standard summary number a chrono reports at the end of
//     a string).
//   * **From Photo** — opens the camera or photo library, OCRs the
//     image with ML Kit (via [PhotoImportService]), pulls every number
//     in plausible-MV range (500–5000 fps), and lets the user confirm
//     one with a tap.
//
// On a successful capture the widget calls `onMvCaptured(double fps)`
// with the chosen velocity. The host screen writes that into its own
// MV field and renders a snackbar — this widget does NOT touch the
// host screen's text controllers directly, which keeps it agnostic of
// where it's embedded.
//
// Use it anywhere a Muzzle Velocity input lives. v1 sites:
//   * `lib/screens/ballistics/ballistics_screen.dart` — alongside the
//     "Don't Know Your MV?" inline link beneath the External Ballistics
//     MV field. Lets a chrono-equipped reloader skip the inline link
//     and just import their actual measured MV.
//   * `lib/screens/ballistics/ballistic_profile_form_screen.dart` —
//     beside the profile's MV field, since profiles are where MV
//     permanently lives now (after the schema v33 firearm-MV-column
//     drop).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// At schema v32 these capture handlers lived on the firearm form,
// adjacent to the firearm's `defaultMuzzleVelocityFps` column. The
// schema v33 drop of that column meant the buttons had no valid host —
// MV no longer belongs to the firearm conceptually (it changes per
// load). Rather than delete the affordances (the user invested
// engineering time in them and reloaders use both Garmin Xeros and
// chronograph photos every range trip), we lift them into a reusable
// widget and re-host where MV input actually lives now: on
// trajectory-solver / ballistic-profile surfaces.
//
// Lifting also collapsed code duplication that would have appeared if
// we re-implemented the same flows on each new surface. One copy of
// the file picker, one copy of the OCR + range-filter, one copy of
// the multi-candidate picker.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Pro gating happens INSIDE this widget (`ensurePro(context)`
//     before any work) so callers don't have to re-implement the
//     gate. A free user tapping either button is routed to the
//     paywall and the capture never starts.
//   * Photo OCR works only on iOS + Android (ML Kit doesn't ship for
//     macOS / Windows / Linux / web). The widget renders the Photo
//     button with a disabled state on unsupported platforms; tapping
//     shows a snackbar explaining why.
//   * The MV-extraction regex looks for 3-to-5-digit integers in the
//     500–5000 fps window. Tighter bands have been tried; this band
//     covers .22 LR subsonic at the bottom end and hot wildcat 6mm
//     at the top, with enough margin to suppress shot counters /
//     battery percentages / clock readouts / temperature in the
//     photo's other text.
//   * The widget is stateful because the camera / file picker / OCR
//     run async and the buttons need a busy-state during the call.
//     Caller-supplied `enabled: false` (e.g. when the host is itself
//     busy with a save) takes precedence.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/ballistics/ballistics_screen.dart
// - lib/screens/ballistics/ballistic_profile_form_screen.dart (when
//   the profile form gets one — rolled in alongside this widget at
//   the v33 split)
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Opens the OS file picker (Garmin import path).
// - Opens the camera / photo library (Photo OCR path).
// - Reads BLE service from Provider for the Garmin import (some
//   `.fit` parsing requires the BLE adapter for context — see
//   `GarminXeroService` for why).
// - Routes through `ensurePro(context)` which may push the paywall
//   modal.
// - Surfaces snackbars for success / error / unsupported-platform.

import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/ble/ble_service.dart';
import '../services/ble/garmin_xero_service.dart';
import '../services/photo_import_service.dart';
import 'pro_gate.dart';

/// Two-button row: "From Garmin Xero" + "From Photo". On capture,
/// invokes [onMvCaptured] with the muzzle velocity in fps.
class MvCaptureButtons extends StatefulWidget {
  const MvCaptureButtons({
    super.key,
    required this.onMvCaptured,
    this.enabled = true,
  });

  /// Fired when the user successfully captures an MV. Argument is
  /// in feet per second. The widget itself never writes to the host
  /// screen's controllers — the host listens here and decides what
  /// to do with the value (write to its own MV controller, persist
  /// to a profile, etc.).
  final ValueChanged<double> onMvCaptured;

  /// When false, both buttons render disabled regardless of the
  /// widget's own busy state. Callers pass `false` when the host
  /// screen is itself in a busy / saving state.
  final bool enabled;

  @override
  State<MvCaptureButtons> createState() => _MvCaptureButtonsState();
}

class _MvCaptureButtonsState extends State<MvCaptureButtons> {
  bool _busy = false;

  bool get _photoSupported {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled || _busy;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : _onImportFromGarminXero,
            icon: const Icon(Icons.bluetooth_searching, size: 16),
            label: const Text('From Garmin Xero'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : _onCaptureFromPhoto,
            icon: const Icon(Icons.camera_alt_outlined, size: 16),
            label: const Text('From Photo'),
          ),
        ),
      ],
    );
  }

  Future<void> _onImportFromGarminXero() async {
    if (!await ensurePro(context)) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ble = context.read<BleService>();
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['fit'],
        withData: false,
      );
      if (picked == null || picked.files.isEmpty) return;
      final path = picked.files.single.path;
      if (path == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't read the selected file.")),
        );
        return;
      }
      final session = await GarminXeroService(ble).importFitFile(path);
      if (!mounted) return;
      // Write the session AVERAGE fps — that's the standard summary
      // number a chrono reports at the end of a string. The user
      // can still edit by hand if they prefer a different statistic
      // (extreme high, best 10-shot subset, etc.).
      widget.onMvCaptured(session.averageFps);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${session.shots.length} shots. '
            'Avg ${session.averageFps.toStringAsFixed(0)} fps · '
            'SD ${session.standardDeviationFps.toStringAsFixed(1)}',
          ),
        ),
      );
    } on GarminXeroParseException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't import that file: $e")),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onCaptureFromPhoto() async {
    if (!await ensurePro(context)) return;
    if (!mounted) return;
    if (!_photoSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Photo capture isn't available on this platform.",
          ),
        ),
      );
      return;
    }
    final source = await _pickPhotoSource();
    if (source == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final svc = PhotoImportService();
    try {
      final result = await svc.captureAndRecognize(source: source);
      if (!mounted) return;
      if (result == null || result.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("No text found in that photo. Try again?"),
          ),
        );
        return;
      }
      final candidates = _extractMvCandidatesFps(result.fullText);
      if (candidates.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No muzzle-velocity-shaped numbers found '
              '(looking for 500-5000 fps).',
            ),
          ),
        );
        return;
      }
      double? chosen;
      if (candidates.length == 1) {
        chosen = candidates.first;
      } else {
        chosen = await _pickMvCandidate(candidates);
        if (!mounted || chosen == null) return;
      }
      widget.onMvCaptured(chosen);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Captured ${chosen.toStringAsFixed(0)} fps from photo.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't read that photo: $e")),
      );
    } finally {
      await svc.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<ImageSource?> _pickPhotoSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick from Library'),
              onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  /// Scan OCR'd text for numbers that look like a muzzle velocity in
  /// fps. Cutoffs (500–5000) cover every common chambering: a
  /// subsonic .22 LR at the low end, a hot wildcat 6mm at the top
  /// end, with margin to suppress clock readouts / shot counters /
  /// battery percentages / temperature in the photo's other text.
  /// Numbers returned in first-occurrence order so the picker
  /// reflects the photo top-to-bottom.
  List<double> _extractMvCandidatesFps(String text) {
    final out = <double>[];
    final seen = <int>{};
    final re = RegExp(r'\d{3,5}(?:\.\d+)?');
    for (final m in re.allMatches(text)) {
      final v = double.tryParse(m.group(0)!);
      if (v == null) continue;
      if (v < 500 || v > 5000) continue;
      final key = v.round();
      if (seen.add(key)) out.add(v);
    }
    return out;
  }

  Future<double?> _pickMvCandidate(List<double> candidates) {
    return showModalBottomSheet<double>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Pick the Muzzle Velocity',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final v in candidates)
              ListTile(
                leading: const Icon(Icons.speed),
                title: Text('${v.toStringAsFixed(0)} fps'),
                onTap: () => Navigator.of(sheetCtx).pop(v),
              ),
          ],
        ),
      ),
    );
  }
}
