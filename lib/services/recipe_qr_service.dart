// FILE: lib/services/recipe_qr_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Encodes a `UserLoadRow` into a compact, QR-friendly text payload and
// decodes that payload back into a `UserLoadsCompanion` ready to insert.
// The payload is the only on-disk / over-the-wire shape — we deliberately
// do NOT serialize the full Drift row because (a) most of the 50+ columns
// won't fit inside a single QR and (b) lot ids / timestamps / sort metadata
// aren't meaningful on a different device. The "shareable subset" is the
// recipe identity + the columns a reloader cares about reading off paper:
// cartridge, powder + charge, bullet (label + weight + diameter), primer,
// brass, COAL / CBTO, optional seating depth, and free-form notes
// (truncated to 500 characters).
//
// Public surface:
//
//   * `RecipeQrService.encodeRecipe(row)` — returns the share string
//     `"LO1:<base64url(gzip(json))>"`. Throws [RecipeQrPayloadTooLargeError]
//     if the encoded payload exceeds the QR-safe budget (2500 bytes).
//   * `RecipeQrService.decodeShareString(s)` — parses an `LO1:` payload
//     back into a `(RecipeQrPayload, UserLoadsCompanion)` pair. Throws
//     [RecipeQrInvalidPayloadError] for any prefix mismatch / corruption.
//   * `RecipeQrService.lookLikesLoadOutQr(s)` — fast prefix check used by
//     the scanner to decide whether to attempt a decode at all.
//   * `RecipeQrPayload` — the value-typed intermediate. Useful for dedupe
//     before insert (`name + cartridge + powder + charge`).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Recipe sharing already supports PDF (polished marketing artifact) and
// plain text (copy-pasteable). Both require the receiver to either OCR the
// PDF or hand-type the recipe. QR is the "two phones in the same room"
// path: one user shares, the other scans, the recipe lands in the local
// SQLite DB without a single keystroke. Local-first, no server, no
// account — fully aligned with the privacy posture in CLAUDE.md § 13.
//
// If this file were deleted, the scan-screen and share-sheet widgets
// would have to re-implement the encode pipeline themselves, and the
// magic-prefix discrimination ("is this our QR or not?") would land in
// scanner UI code where it doesn't belong.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **QR capacity is tight.** A QR code at error-correction level M holds
//    ~2.3 KB of binary data; level L holds ~2.9 KB. A naive JSON dump of
//    a populated recipe (50+ columns, plus user-typed notes) easily blows
//    past that — even with mostly-null fields. Two compression layers fix
//    this: drop the columns that don't survive the trip (lot ids,
//    timestamps, autoincrement id, custom-fields JSON), then gzip what
//    remains. Notes are truncated to 500 chars before encoding so a
//    pasted novel doesn't blow the budget. We still surface a hard
//    "recipe too long" error so the share sheet can fall back to PDF.
//
// 2. **Magic prefix discrimination is mandatory.** A camera scanning the
//    world will pick up Wi-Fi QRs, contact cards, store coupons, URLs,
//    etc. We tag every LoadOut payload with `LO1:` so the scanner can
//    instantly reject anything else with a friendly "Not a LoadOut QR"
//    snackbar instead of garbling random bytes through a JSON parser.
//    The `1` is a version digit; future encoders can bump to `LO2:` and
//    keep this decoder around as a fallback.
//
// 3. **base64-URL, not vanilla base64.** QR alphanumeric mode (the
//    densest reasonable encoding for ASCII payloads) accepts `A-Z`,
//    `0-9`, and a small punctuation set. Standard base64 uses `+` and
//    `/` which fall outside that set; `base64Url` substitutes them for
//    `-` and `_`. We strip padding to save bytes.
//
// 4. **Round-trip integrity beats round-trip totality.** The decoder
//    builds a `UserLoadsCompanion` with `Value(...)` for every column
//    actually present and lets the rest fall through as `Value.absent()`
//    so the DB defaults take over. That's the right behavior — if the
//    sender's recipe didn't have a primer name, we don't want to overwrite
//    the receiver's eventual primer with an empty string.
//
// 5. **Custom fields stay local.** The schema-v4 `UserCustomFields` /
//    `UserCustomFieldValues` tables are on-purpose excluded. They're
//    keyed by `fieldId`, which only makes sense in the sender's DB.
//    Materialising them on the receiver's side would either silently
//    drop the values or invent fake field rows. Both are worse than
//    leaving them out.
//
// 6. **Notes truncation is one-way.** We trim to 500 characters with a
//    trailing ellipsis so the recipient sees that the source was longer
//    than the QR could carry. The marker is a literal `...` (three
//    ASCII dots), not a Unicode `…`, so it survives every
//    downstream font.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/widgets/recipe_qr_share_sheet.dart — calls `encodeRecipe` and
//   feeds the result to `qr_flutter` for rendering, plus a copy-to-
//   clipboard button on the same string.
// - lib/screens/recipes/recipe_qr_scan_screen.dart — calls
//   `lookLikesLoadOutQr` on every detected barcode, and `decodeShareString`
//   when the prefix matches. Inserts via `RecipeRepository`.
// - test/recipe_qr_service_test.dart — round-trip integrity test.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - None. Pure functions. The service holds no state and touches no I/O.

import 'dart:convert';
import 'dart:io' show GZipCodec;

import 'package:drift/drift.dart' show Value;

import '../database/database.dart';

/// Magic prefix identifying a LoadOut recipe-share QR. The trailing `1`
/// is a payload version digit — bump to `LO2:` if the encoded shape ever
/// changes incompatibly, and keep the legacy decoder around so older QRs
/// still scan.
const String kRecipeQrMagicPrefix = 'LO1:';

/// Maximum encoded payload size (in bytes, post-base64) we'll write to a
/// QR. A QR at error-correction level M tops out around 2331 bytes of
/// payload data; we keep a small buffer below that for the magic prefix
/// and any future header.
const int kRecipeQrMaxPayloadBytes = 2500;

/// Notes are truncated to this many characters before encoding. Anything
/// longer is replaced with the head + a trailing `...`. The truncation
/// is one-way and visible to the recipient, who knows to ask the sender
/// for the full text if needed.
const int kRecipeQrMaxNotesChars = 500;

/// Thrown when an encoded payload exceeds [kRecipeQrMaxPayloadBytes].
/// The share sheet catches this and surfaces the "Recipe too long for a
/// QR. Use file or PDF share instead." copy.
class RecipeQrPayloadTooLargeError implements Exception {
  RecipeQrPayloadTooLargeError(this.actualBytes);

  /// Actual encoded byte count — surfaced for diagnostics / debug logs.
  final int actualBytes;

  @override
  String toString() =>
      'RecipeQrPayloadTooLargeError: encoded payload is $actualBytes bytes '
      '(limit $kRecipeQrMaxPayloadBytes).';
}

/// Thrown when a candidate string fails to decode — wrong prefix,
/// corrupt base64, gunzip failure, JSON parse error, or missing required
/// fields. The scan screen catches this and shows "Not a LoadOut QR".
class RecipeQrInvalidPayloadError implements Exception {
  RecipeQrInvalidPayloadError(this.reason);

  final String reason;

  @override
  String toString() => 'RecipeQrInvalidPayloadError: $reason';
}

/// Strongly-typed intermediate between the wire format and a Drift
/// companion. Held as a value class so the scan screen can dedupe
/// against the local DB before inserting (see
/// `recipe_qr_scan_screen.dart`'s `_dedupeKeyOf`).
///
/// Fields mirror the shareable subset described in this file's header.
/// All non-name fields are nullable because a sender's recipe may not
/// have populated every one.
class RecipeQrPayload {
  const RecipeQrPayload({
    required this.name,
    this.caliber,
    this.powder,
    this.powderChargeGr,
    this.bullet,
    this.bulletWeightGr,
    this.bulletLengthIn,
    this.primer,
    this.brass,
    this.coalIn,
    this.cbtoIn,
    this.seatingDepthIn,
    this.notes,
  });

  final String name;
  final String? caliber;
  final String? powder;
  final double? powderChargeGr;
  final String? bullet;
  final double? bulletWeightGr;
  final double? bulletLengthIn;
  final String? primer;
  final String? brass;
  final double? coalIn;
  final double? cbtoIn;
  final double? seatingDepthIn;
  final String? notes;

  /// JSON shape we serialize over the wire. Short keys to save QR
  /// capacity — every byte counts. Any null value drops out instead of
  /// rendering as `"k": null` so the encoded payload is as small as
  /// possible. Decoder is symmetric: a missing key becomes a null
  /// field, which becomes `Value.absent()` on the companion side.
  Map<String, Object?> toShortJson() {
    final m = <String, Object?>{'n': name};
    if (caliber != null) m['cl'] = caliber;
    if (powder != null) m['p'] = powder;
    if (powderChargeGr != null) m['pc'] = powderChargeGr;
    if (bullet != null) m['b'] = bullet;
    if (bulletWeightGr != null) m['bw'] = bulletWeightGr;
    if (bulletLengthIn != null) m['bl'] = bulletLengthIn;
    if (primer != null) m['pr'] = primer;
    if (brass != null) m['br'] = brass;
    if (coalIn != null) m['co'] = coalIn;
    if (cbtoIn != null) m['cb'] = cbtoIn;
    if (seatingDepthIn != null) m['sd'] = seatingDepthIn;
    if (notes != null) m['nt'] = notes;
    return m;
  }

  /// Inverse of [toShortJson]. Tolerant of missing fields — required
  /// only `n` (name). Throws [RecipeQrInvalidPayloadError] if `n` is
  /// missing, blank, or not a string, since a recipe with no name has
  /// no identity.
  static RecipeQrPayload fromShortJson(Map<String, Object?> j) {
    final rawName = j['n'];
    if (rawName is! String || rawName.trim().isEmpty) {
      throw RecipeQrInvalidPayloadError('payload is missing recipe name');
    }
    return RecipeQrPayload(
      name: rawName.trim(),
      caliber: _asString(j['cl']),
      powder: _asString(j['p']),
      powderChargeGr: _asDouble(j['pc']),
      bullet: _asString(j['b']),
      bulletWeightGr: _asDouble(j['bw']),
      bulletLengthIn: _asDouble(j['bl']),
      primer: _asString(j['pr']),
      brass: _asString(j['br']),
      coalIn: _asDouble(j['co']),
      cbtoIn: _asDouble(j['cb']),
      seatingDepthIn: _asDouble(j['sd']),
      notes: _asString(j['nt']),
    );
  }

  /// Dedupe key for "is this recipe already in my library?" — used by
  /// the scanner before insert to avoid creating exact duplicates. The
  /// shape mirrors the spec in the user request (`name + cartridge +
  /// powder + charge`); each component is normalised (trimmed and
  /// lowercased) so trivial whitespace / case differences still
  /// collapse. Numeric `powderChargeGr` is rounded to two decimals so
  /// a sender's `41.50` and a receiver's `41.5` collapse to the same
  /// key.
  String dedupeKey() {
    final n = name.trim().toLowerCase();
    final c = (caliber ?? '').trim().toLowerCase();
    final p = (powder ?? '').trim().toLowerCase();
    final pc = powderChargeGr == null
        ? ''
        : (powderChargeGr! * 100).round().toString();
    return '$n|$c|$p|$pc';
  }

  /// Convert to a Drift insert companion. Every nullable field becomes
  /// `Value(...)` if present and `Value.absent()` if not, which lets the
  /// DB defaults handle the rest (status, useCase, all the boolean
  /// pressure flags, the schema-v16 powder-temp defaults, etc.).
  UserLoadsCompanion toCompanion() {
    return UserLoadsCompanion.insert(
      name: name,
      caliber: Value(caliber),
      powder: Value(powder),
      powderChargeGr: Value(powderChargeGr),
      bullet: Value(bullet),
      bulletWeightGr: Value(bulletWeightGr),
      bulletLengthIn: Value(bulletLengthIn),
      primer: Value(primer),
      brass: Value(brass),
      coalIn: Value(coalIn),
      cbtoIn: Value(cbtoIn),
      seatingDepthIn: Value(seatingDepthIn),
      notes: Value(notes),
    );
  }

  static String? _asString(Object? v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    return v.toString();
  }

  static double? _asDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

/// Stateless namespace for the encode/decode functions. Constructor takes
/// no arguments and the methods could equally have been top-level; we
/// keep a class so callers can declare a single `final _qr =
/// RecipeQrService();` and have a stable injection point for tests.
class RecipeQrService {
  const RecipeQrService();

  /// Build the share string `"LO1:<base64url(gzip(json))>"` for [row].
  /// Throws [RecipeQrPayloadTooLargeError] if the encoded result
  /// exceeds [kRecipeQrMaxPayloadBytes] — caller should fall back to
  /// PDF share. Raw row → payload → JSON → gzip → base64url.
  String encodeRecipe(UserLoadRow row) {
    final payload = payloadFromRow(row);
    return encodePayload(payload);
  }

  /// Encode a [RecipeQrPayload] directly. Useful in tests where we want
  /// to drive the encoder without first constructing a full Drift row.
  String encodePayload(RecipeQrPayload payload) {
    final jsonStr = jsonEncode(payload.toShortJson());
    final jsonBytes = utf8.encode(jsonStr);
    final gz = GZipCodec().encode(jsonBytes);
    final b64 = base64UrlEncode(gz);
    // Strip the `=` padding bytes since the decoder re-pads on read.
    // Saves up to 2 bytes per encode.
    final stripped = b64.replaceAll('=', '');
    final share = '$kRecipeQrMagicPrefix$stripped';
    if (share.length > kRecipeQrMaxPayloadBytes) {
      throw RecipeQrPayloadTooLargeError(share.length);
    }
    return share;
  }

  /// Project a Drift row down to the shareable subset and apply the
  /// notes-truncation rule. Public so tests can round-trip without
  /// going through `encodeRecipe`.
  RecipeQrPayload payloadFromRow(UserLoadRow row) {
    return RecipeQrPayload(
      name: row.name,
      caliber: _emptyToNull(row.caliber),
      powder: _emptyToNull(row.powder),
      powderChargeGr: row.powderChargeGr,
      bullet: _emptyToNull(row.bullet),
      bulletWeightGr: row.bulletWeightGr,
      bulletLengthIn: row.bulletLengthIn,
      primer: _emptyToNull(row.primer),
      brass: _emptyToNull(row.brass),
      coalIn: row.coalIn,
      cbtoIn: row.cbtoIn,
      seatingDepthIn: row.seatingDepthIn,
      notes: _truncateNotes(_emptyToNull(row.notes)),
    );
  }

  /// Cheap prefix discriminator for the scanner — call before paying
  /// for a base64 / gzip / json round trip. Returns `false` for null,
  /// empty, or non-LoadOut QRs.
  bool lookLikesLoadOutQr(String? candidate) {
    if (candidate == null || candidate.isEmpty) return false;
    return candidate.startsWith(kRecipeQrMagicPrefix);
  }

  /// Decode a share string into a `(RecipeQrPayload, UserLoadsCompanion)`
  /// pair. Throws [RecipeQrInvalidPayloadError] on every failure mode
  /// the scanner cares about — wrong prefix, corrupt base64, gunzip
  /// failure, JSON parse error, missing required fields.
  ({RecipeQrPayload payload, UserLoadsCompanion companion}) decodeShareString(
    String share,
  ) {
    if (!lookLikesLoadOutQr(share)) {
      throw RecipeQrInvalidPayloadError(
        'missing magic prefix "$kRecipeQrMagicPrefix"',
      );
    }
    final body = share.substring(kRecipeQrMagicPrefix.length);
    // base64Url decoder demands a length divisible by 4. Re-pad with
    // `=` because we strip it during encode to save bytes.
    final padded = _padBase64(body);
    final List<int> gz;
    try {
      gz = base64Url.decode(padded);
    } catch (e) {
      throw RecipeQrInvalidPayloadError('base64 decode failed: $e');
    }
    final List<int> jsonBytes;
    try {
      jsonBytes = GZipCodec().decode(gz);
    } catch (e) {
      throw RecipeQrInvalidPayloadError('gunzip failed: $e');
    }
    final String jsonStr;
    try {
      jsonStr = utf8.decode(jsonBytes);
    } catch (e) {
      throw RecipeQrInvalidPayloadError('utf-8 decode failed: $e');
    }
    final Object? raw;
    try {
      raw = jsonDecode(jsonStr);
    } catch (e) {
      throw RecipeQrInvalidPayloadError('json parse failed: $e');
    }
    if (raw is! Map<String, Object?>) {
      throw RecipeQrInvalidPayloadError(
        'top-level json is not an object (was ${raw.runtimeType})',
      );
    }
    final payload = RecipeQrPayload.fromShortJson(raw);
    return (payload: payload, companion: payload.toCompanion());
  }

  // ─────────────────────────── Helpers ───────────────────────────

  /// Map `null` AND empty / whitespace-only strings to `null`. Both are
  /// equivalent semantically and there's no point shipping the empty
  /// string over the wire.
  static String? _emptyToNull(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  /// Truncate notes to [kRecipeQrMaxNotesChars] characters with a
  /// trailing `...` marker so the receiver knows the source was longer.
  /// Idempotent on already-short strings.
  static String? _truncateNotes(String? s) {
    if (s == null) return null;
    if (s.length <= kRecipeQrMaxNotesChars) return s;
    // Reserve 3 chars for the `...` marker. Trim trailing whitespace to
    // avoid an awkward "abc   ..." result on word-boundary truncation.
    final head = s.substring(0, kRecipeQrMaxNotesChars - 3).trimRight();
    return '$head...';
  }

  /// Re-pad a base64 string with `=` to a length divisible by 4 so the
  /// stdlib decoder accepts it. We strip these on encode to save QR
  /// bytes; this is the inverse.
  static String _padBase64(String s) {
    final mod = s.length % 4;
    if (mod == 0) return s;
    return s + ('=' * (4 - mod));
  }
}
