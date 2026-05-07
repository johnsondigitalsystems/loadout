// FILE: lib/services/photo_import_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Captures (or picks) a photo of a reloader's notebook page, then runs
// Google ML Kit's on-device text recognizer over it. Returns the
// recognised text plus the per-block bounding boxes so the review screen
// can show the user which OCR blob each parsed field came from.
//
// Public surface:
//
//   - `PhotoImportService()` — no-arg constructor.
//   - `captureAndRecognize({required ImageSource source})` — runs the
//     `image_picker` (camera or photo library), then OCRs the result.
//     Returns `null` if the user cancelled.
//   - `recognizeFile(File)` — lower-level: OCR an existing image on disk.
//   - `dispose()` — closes the underlying ML Kit text recognizer.
//
// The `OcrResult` data class wraps:
//   - `fullText` — newline-joined block text, ready for the heuristic
//     parser.
//   - `blocks` — every recognised block with its raw text and bounding
//     rect. The review screen doesn't render the rects today but
//     storing them keeps future "tap a field on the photo" UX cheap.
//   - `imagePath` — absolute path to the captured image on disk so the
//     review screen can show a thumbnail.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Survey data: 66% of reloaders track loads in pen-and-paper notebooks.
// CSV import handles the spreadsheet cohort; photo import handles the
// notebook cohort. The point of this service is to be the single place
// that owns the camera/picker plumbing AND the OCR pass, so the UI
// layer just calls one method and gets back text it can hand to the
// parser.
//
// Privacy posture: nothing in this flow touches the network. ML Kit's
// text recognizer is fully on-device — Google ships the model with the
// SDK (or downloads it once into local app storage on first launch).
// The captured photo lives in the OS-supplied temp directory the
// picker hands us. We never upload, log, or copy it anywhere LoadOut
// controls.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Permissions vs cancellation.** `image_picker` returns `null` for
//    *both* "user denied permission" and "user tapped cancel". The
//    caller can't tell the two apart from the picker alone, so the
//    service surfaces both as `null` and lets the UI provide a generic
//    "couldn't capture an image" prompt with a link to system settings.
//
// 2. **macOS gating.** `google_mlkit_text_recognition` does not ship a
//    macOS implementation. Constructing a `TextRecognizer` works on
//    macOS but invoking `processImage` throws `MissingPluginException`.
//    The service itself is platform-agnostic — the gating happens in
//    the entry-point UI (see `lib/screens/recipes/photo_import_screen.dart`).
//
// 3. **Resource lifecycle.** ML Kit's text recognizer holds native
//    resources. We construct it lazily in the constructor and require
//    callers to `dispose()` when they're done. The screen creates one
//    instance per push and disposes it in its `State.dispose` —
//    matches the lifecycle of every other service in the app.
//
// 4. **First-call latency.** ML Kit downloads the OCR model into the
//    app's local storage on first invocation (one-time, ~30MB). On a
//    cold launch the user sees the spinner for a few extra seconds.
//    There is no public API to trigger the download earlier; we just
//    let the first user-initiated capture pay the cost.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/recipes/photo_import_screen.dart — the camera/gallery
//   chooser screen calls `captureAndRecognize` and pushes the review
//   screen with the resulting `OcrResult`.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Opens the OS camera or photo-library picker (image_picker plugin).
// - Reads the picked file from disk.
// - Holds a native `TextRecognizer` resource until `dispose()`.
// - On first invocation (per device install), ML Kit downloads its
//   text-recognition model into the app's local storage. This is a
//   one-time on-device action; nothing about the recognised content
//   leaves the device.

import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Wraps `image_picker` + Google ML Kit's text recognizer into a single
/// "capture or pick a photo and OCR it" call.
class PhotoImportService {
  PhotoImportService();

  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  final ImagePicker _picker = ImagePicker();

  /// Run the platform camera or photo-library picker, then OCR the
  /// result. Returns `null` if the user cancelled or the picker was
  /// otherwise unable to provide an image.
  Future<OcrResult?> captureAndRecognize({
    required ImageSource source,
  }) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      // Cap the longest edge so OCR processes a sensible amount of
      // pixels — full-resolution iPhone photos are 4032x3024 and ML
      // Kit doesn't benefit from anything over ~2500px on the long
      // edge for handwriting.
      maxWidth: 2500,
      maxHeight: 2500,
      // 85 keeps text edges crisp while shrinking the file payload.
      imageQuality: 85,
    );
    if (pickedFile == null) return null;
    final file = File(pickedFile.path);
    return recognizeFile(file);
  }

  /// Lower-level: OCR an existing image file. Returns the recognised
  /// text plus per-block bounding boxes for downstream UI.
  Future<OcrResult> recognizeFile(File image) async {
    final input = InputImage.fromFile(image);
    final recognised = await _recognizer.processImage(input);
    final blocks = recognised.blocks
        .map(
          (b) => OcrBlock(
            text: b.text,
            left: b.boundingBox.left,
            top: b.boundingBox.top,
            right: b.boundingBox.right,
            bottom: b.boundingBox.bottom,
          ),
        )
        .toList(growable: false);
    return OcrResult(
      fullText: recognised.text,
      blocks: blocks,
      imagePath: image.path,
    );
  }

  /// Releases the ML Kit text recognizer's native resources. Must be
  /// called when the consuming screen is disposed.
  Future<void> dispose() async {
    await _recognizer.close();
  }
}

/// One block of OCR output. Bounding-box coordinates are in image
/// pixels with the origin at the top-left, matching ML Kit's
/// convention.
class OcrBlock {
  const OcrBlock({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
}

/// Result of one photo-import OCR pass.
class OcrResult {
  const OcrResult({
    required this.fullText,
    required this.blocks,
    required this.imagePath,
  });

  /// Newline-joined block text — what the heuristic parser consumes.
  final String fullText;

  /// Every recognised block with its bounding rectangle. Stored for
  /// future UI features (overlay highlights, tap-to-focus); the
  /// review screen does not render them in the v1 cut.
  final List<OcrBlock> blocks;

  /// Absolute path to the captured / picked image on disk. The review
  /// screen reads this with `Image.file(...)` to show a thumbnail.
  final String imagePath;

  bool get isEmpty => fullText.trim().isEmpty;
}
