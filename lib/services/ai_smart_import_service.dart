// FILE: lib/services/ai_smart_import_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Talks to Anthropic — directly with the user's own key (BYOK mode) or
// through LoadOut's Cloudflare Worker proxy (hosted mode) — to improve
// a low-confidence `RecipeDraft` produced by the on-device parser. The
// service has exactly one job:
//
//   `improveDraft(ocrText, initialDraft, catalogHints) → RecipeDraft`
//
// Everything else (UI, Pro gates, settings) lives elsewhere; this file
// is the network seam.
//
// Public surface:
//
//   - `AiSmartImportService({storage, entitlements, client, firebaseAuth})`
//     — constructor. `storage` is a `FlutterSecureStorage` for the
//     BYOK key. `entitlements` is the `EntitlementNotifier` so we can
//     check `isPro` synchronously without subscribing. `client` is
//     an injectable `http.Client` for tests. `firebaseAuth` is
//     injectable so tests don't need a real Firebase project.
//   - `improveDraft({...}) -> RecipeDraft` — the only public action.
//     Returns a NEW `RecipeDraft` with whatever fields the model
//     could improve. Fields it couldn't improve come back as the
//     original `initialDraft` value (or null).
//   - `hostedUsage() -> Future<HostedUsageStats?>` — reads the most
//     recent quota counters. Returns null in BYOK mode because no
//     proxy quota applies.
//   - `setByokKey(String? key)` / `getByokKey()` — secure-storage
//     wrappers for the user's own Anthropic key. Settings UI calls
//     these directly.
//   - `testByokKey(String key) -> Future<void>` — sanity-checks a
//     BYOK key by issuing a tiny one-token completion before the
//     user commits to saving it.
//
// Three exceptions:
//
//   - `ProRequiredException` — non-Pro user attempted to call the
//     service. Caller should trigger the paywall.
//   - `SmartImportNotConfiguredException` — proxy URL is the
//     placeholder (operator hasn't deployed the Worker yet) AND no
//     BYOK key is set. Caller should show "feature is being set up"
//     copy.
//   - `SmartImportException` — generic failure (network, model
//     refusal, parse error). Carries an optional `code` and
//     `statusCode` for refined UX.
//
// ============================================================================
// WIRE FORMAT (HOSTED MODE — Worker)
// ============================================================================
//   POST {proxyBaseUrl}/v1/smart-import
//   Authorization: Bearer <firebase_id_token>
//   content-type: application/json
//   body: {
//     "ocr_text": "...raw OCR string...",
//     "initial_draft": { ...JSON of `RecipeDraft.toJsonForAi()`... },
//     "catalog_hints": { ...optional disambiguation hints... },
//     "model": "claude-sonnet-4-5"
//   }
//
//   200 OK
//   body: {
//     "improved_draft": {...},
//     "fields_changed": ["powder", "powderChargeGr"],
//     "quota": { "used_this_month": 12, "monthly_cap": 30,
//                "resets_at": "2026-06-01T00:00:00Z" }
//   }
//
//   429 — quota exhausted; body matches the same `quota` shape so
//   the UI can show a "you've used 30/30 this month" state.
//
// ============================================================================
// WIRE FORMAT (BYOK MODE — direct Anthropic)
// ============================================================================
// We POST a single Messages-API turn with a system prompt that
// instructs the model to return STRICT JSON matching the same
// `improved_draft` shape the Worker emits. The model is told to
// preserve any field it cannot confidently improve.
//
//   POST https://api.anthropic.com/v1/messages
//   x-api-key: <user's key>
//   anthropic-version: 2023-06-01
//   content-type: application/json
//   body: {
//     "model": "claude-sonnet-4-5",
//     "max_tokens": 600,
//     "system": "...JSON-only system prompt...",
//     "messages": [{
//       "role": "user",
//       "content": "OCR_TEXT:\n...\n\nINITIAL_DRAFT:\n{...}\n..."
//     }]
//   }
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The on-device `RecipeParser` covers the easy 80% of handwritten
// notebook entries — clear handwriting, standard reloading vocabulary.
// The other 20% (cursive, smudged, unusual abbreviations, fast scrawl)
// is where AI helps. We deliberately keep the AI surface NARROW: it
// only ever sees OCR'd text the user just produced, never the user's
// saved recipes, firearms, or anything else from the on-device DB.
// This file is the only place that talks to Anthropic at all for
// Smart Import — every other surface (`PhotoImportReviewScreen`, the
// settings screen, tests) goes through this service.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Mode selection cannot ask the user.** The service is called
//    from inside an `onPressed:`; it has to decide hosted vs BYOK
//    transparently. The rule:
//      a) If a BYOK key is in secure storage, use BYOK.
//      b) Else if the user is Pro AND the Worker URL isn't a
//         placeholder, use hosted.
//      c) Else throw `ProRequiredException` (non-Pro) or
//         `SmartImportNotConfiguredException` (proxy not deployed).
// 2. **Firebase ID token shape.** The Worker validates the token
//    against Firebase's public JWKs. If the user is anonymous, the
//    token still works — Firebase signs anonymous users too. The
//    Worker treats "valid token" as the authentication signal and
//    relies on the client-side `ensurePro` gate for the entitlement
//    check (documented as a "needs hardening before scale" caveat
//    in the Worker README).
// 3. **JSON parsing of model output.** Anthropic's Messages API
//    returns the assistant text inside `content[].text`. We extract
//    the JSON, strip any markdown fence the model occasionally adds,
//    and decode. Bad JSON → `SmartImportException(code: 'parse')`.
// 4. **Field merge preserves user edits.** The service does NOT
//    merge into the user's currently-displayed form; it just returns
//    the improved draft. The caller (PhotoImportReviewScreen)
//    decides which fields to apply, comparing against the user's
//    edited state.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/screens/recipes/photo_import_review_screen.dart` — the
//   "Improve with AI" button calls `improveDraft`.
// - `lib/screens/settings/ai_settings_screen.dart` — calls
//   `setByokKey`, `getByokKey`, `testByokKey`, and `hostedUsage` for
//   the BYOK + usage UI.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - HTTPS POST to either the Worker URL or `api.anthropic.com`.
// - Reads/writes the BYOK key in `FlutterSecureStorage`.
// - Reads the current Firebase ID token in hosted mode.

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'ai_smart_import_config.dart';
import 'entitlement_notifier.dart';
import 'recipe_parser.dart';

/// Snapshot of a Pro user's hosted-mode usage. Returned by
/// [AiSmartImportService.hostedUsage]. `null` from that method means
/// BYOK is active (no proxy quota applies).
@immutable
class HostedUsageStats {
  const HostedUsageStats({
    required this.usedThisMonth,
    required this.monthlyCap,
    required this.resetsAt,
  });

  /// Hosted-mode improve calls successfully made this calendar month.
  final int usedThisMonth;

  /// Server-side cap (mirrors [AiSmartImportConfig.monthlyCap]).
  final int monthlyCap;

  /// UTC instant the counter resets (the 1st of next month at 00:00).
  final DateTime resetsAt;

  /// Convenience: did the user hit the cap?
  bool get isExhausted => usedThisMonth >= monthlyCap;
}

/// Thrown when a non-Pro user invokes [AiSmartImportService.improveDraft]
/// without a BYOK key configured. Caller should route to the paywall via
/// `ensurePro`.
class ProRequiredException implements Exception {
  const ProRequiredException(this.message);
  final String message;

  @override
  String toString() => 'ProRequiredException($message)';
}

/// Thrown when the Cloudflare Worker URL is still a placeholder AND
/// no BYOK key is set. Caller should show a "feature is being set up"
/// status — most likely scenario is a freshly-built dev / CI build.
class SmartImportNotConfiguredException implements Exception {
  const SmartImportNotConfiguredException(this.message);
  final String message;

  @override
  String toString() => 'SmartImportNotConfiguredException($message)';
}

/// Generic Smart Import failure. `code` and `statusCode` are optional
/// hints for refined UX.
class SmartImportException implements Exception {
  const SmartImportException(this.message, {this.code, this.statusCode});

  /// Human-readable message suitable for showing to the user.
  final String message;

  /// Machine-readable error code (`'quota_exceeded'`, `'parse'`, etc.).
  final String? code;

  /// HTTP status if the failure was an HTTP-level error.
  final int? statusCode;

  @override
  String toString() =>
      'SmartImportException($message, code=$code, statusCode=$statusCode)';
}

/// Sourcing the Firebase ID token. Production wiring uses
/// [FirebaseAuth.instance.currentUser]; tests can swap a stub that
/// returns a fixed token (or null to simulate signed-out).
typedef FirebaseIdTokenProvider = Future<String?> Function();

/// The only public-facing service for AI Smart Import. Constructed
/// once per app launch and provided through the widget tree.
class AiSmartImportService {
  AiSmartImportService({
    required this.entitlements,
    FlutterSecureStorage? storage,
    http.Client? client,
    FirebaseIdTokenProvider? idTokenProvider,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client(),
        _idTokenProvider = idTokenProvider ?? _defaultIdTokenProvider,
        _ownsClient = client == null;

  /// `true` when entitlement gates pass; throws [ProRequiredException]
  /// otherwise.
  final EntitlementNotifier entitlements;
  final FlutterSecureStorage _storage;
  final http.Client _client;
  final FirebaseIdTokenProvider _idTokenProvider;
  final bool _ownsClient;

  /// Production default: read the current user's ID token from the
  /// Firebase SDK. Returns null if no user is signed in.
  static Future<String?> _defaultIdTokenProvider() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  /// Cached usage stats from the most recent hosted-mode response.
  /// `null` until the first hosted call lands or BYOK mode is in use.
  HostedUsageStats? _lastHostedUsage;

  // ─────────────── public API ───────────────

  /// Improve [initialDraft] using AI. Throws [ProRequiredException]
  /// if neither hosted nor BYOK paths are available, or
  /// [SmartImportException] for any in-flight failure.
  Future<RecipeDraft> improveDraft({
    required String ocrText,
    required RecipeDraft initialDraft,
    Map<String, dynamic>? catalogHints,
  }) async {
    final mode = await _resolveMode();
    switch (mode) {
      case _Mode.byok:
        return _improveViaByok(
          ocrText: ocrText,
          initialDraft: initialDraft,
          catalogHints: catalogHints,
        );
      case _Mode.hosted:
        return _improveViaProxy(
          ocrText: ocrText,
          initialDraft: initialDraft,
          catalogHints: catalogHints,
        );
    }
  }

  /// Latest hosted-mode usage stats, or `null` if BYOK is active or
  /// no hosted call has landed yet this session.
  Future<HostedUsageStats?> hostedUsage() async {
    if (await getByokKey() != null) return null;
    return _lastHostedUsage;
  }

  /// Read the cached BYOK key, or `null` if the user hasn't set one.
  Future<String?> getByokKey() async {
    try {
      return await _storage.read(
        key: AiSmartImportConfig.byokSecureStorageKey,
      );
    } catch (e) {
      debugPrint('AiSmartImportService.getByokKey: $e');
      return null;
    }
  }

  /// Save (or, when [key] is `null`, delete) the user's BYOK key.
  Future<void> setByokKey(String? key) async {
    if (key == null || key.trim().isEmpty) {
      await _storage.delete(
        key: AiSmartImportConfig.byokSecureStorageKey,
      );
      return;
    }
    await _storage.write(
      key: AiSmartImportConfig.byokSecureStorageKey,
      value: key.trim(),
    );
  }

  /// One-shot sanity check that [key] can talk to Anthropic. Issues
  /// a tiny `max_tokens` request before the user commits the key to
  /// secure storage. Throws [SmartImportException] on failure.
  Future<void> testByokKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      throw const SmartImportException('Enter an API key first.');
    }
    final res = await _postToAnthropic(
      apiKey: trimmed,
      body: jsonEncode(<String, dynamic>{
        'model': AiSmartImportConfig.defaultModel,
        'max_tokens': AiSmartImportConfig.byokTestTokens,
        'messages': <Map<String, String>>[
          {'role': 'user', 'content': 'ping'},
        ],
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _throwAnthropicErrorBody(res.statusCode, res.body);
    }
  }

  /// Close the underlying HTTP client if we own it. Tests that
  /// passed in their own client own its lifecycle.
  void dispose() {
    if (_ownsClient) _client.close();
  }

  // ─────────────── mode selection ───────────────

  Future<_Mode> _resolveMode() async {
    final byok = await getByokKey();
    if (byok != null && byok.isNotEmpty) {
      return _Mode.byok;
    }
    if (!entitlements.isPro) {
      throw const ProRequiredException(
        'AI Smart Import is a Pro feature. Upgrade to Pro or set your '
        'own Anthropic key in Settings.',
      );
    }
    if (AiSmartImportConfig.isPlaceholder) {
      throw const SmartImportNotConfiguredException(
        'AI Smart Import is being set up — please try again later.',
      );
    }
    return _Mode.hosted;
  }

  // ─────────────── hosted (proxy) path ───────────────

  Future<RecipeDraft> _improveViaProxy({
    required String ocrText,
    required RecipeDraft initialDraft,
    Map<String, dynamic>? catalogHints,
  }) async {
    String? idToken;
    try {
      idToken = await _idTokenProvider();
    } catch (e) {
      throw SmartImportException(
        "Couldn't authenticate with LoadOut: $e",
        code: 'auth',
      );
    }
    if (idToken == null || idToken.isEmpty) {
      throw const SmartImportException(
        'Sign in to LoadOut to use the hosted AI Smart Import. Or set '
        'your own Anthropic key in Settings → AI.',
        code: 'no_user',
      );
    }

    final uri = Uri.parse(
      '${AiSmartImportConfig.proxyBaseUrl}'
      '${AiSmartImportConfig.smartImportPath}',
    );
    final payload = <String, dynamic>{
      'ocr_text': ocrText,
      'initial_draft': _draftToJson(initialDraft),
      'model': AiSmartImportConfig.defaultModel,
    };
    if (catalogHints != null) {
      payload['catalog_hints'] = catalogHints;
    }
    final body = jsonEncode(payload);

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: <String, String>{
              'authorization': 'Bearer $idToken',
              'content-type': 'application/json',
              'accept': 'application/json',
            },
            body: body,
          )
          .timeout(AiSmartImportConfig.requestTimeout);
    } on TimeoutException {
      throw const SmartImportException(
        'Network timeout. Check your connection and try again.',
        code: 'timeout',
      );
    } catch (e) {
      throw SmartImportException(
        'Network error: $e',
        code: 'network',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwProxyErrorBody(response.statusCode, response.body);
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw SmartImportException(
        "Couldn't read AI response: $e",
        code: 'parse',
      );
    }

    final quotaMap = decoded['quota'];
    if (quotaMap is Map<String, dynamic>) {
      _lastHostedUsage = _parseUsage(quotaMap);
    }

    final improved = decoded['improved_draft'];
    if (improved is! Map<String, dynamic>) {
      throw const SmartImportException(
        'AI response missing improved_draft.',
        code: 'parse',
      );
    }
    return _mergeDrafts(initialDraft, improved);
  }

  // ─────────────── BYOK (direct Anthropic) path ───────────────

  Future<RecipeDraft> _improveViaByok({
    required String ocrText,
    required RecipeDraft initialDraft,
    Map<String, dynamic>? catalogHints,
  }) async {
    final key = (await getByokKey()) ?? '';
    if (key.isEmpty) {
      throw const SmartImportException(
        'No Anthropic key set. Configure it in Settings → AI.',
        code: 'no_byok',
      );
    }

    final body = jsonEncode(<String, dynamic>{
      'model': AiSmartImportConfig.defaultModel,
      'max_tokens': 600,
      'system': _systemPrompt,
      'messages': <Map<String, dynamic>>[
        {
          'role': 'user',
          'content': _buildUserPrompt(
            ocrText: ocrText,
            initialDraft: initialDraft,
            catalogHints: catalogHints,
          ),
        },
      ],
    });

    final response = await _postToAnthropic(apiKey: key, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwAnthropicErrorBody(response.statusCode, response.body);
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw SmartImportException(
        "Couldn't read AI response: $e",
        code: 'parse',
      );
    }

    final content = decoded['content'];
    final assistantText = _extractAssistantText(content);
    if (assistantText.isEmpty) {
      throw const SmartImportException(
        'AI returned an empty response.',
        code: 'empty',
      );
    }

    final json = _stripJsonFence(assistantText);
    final Map<String, dynamic> improved;
    try {
      final parsed = jsonDecode(json);
      if (parsed is! Map<String, dynamic>) {
        throw const SmartImportException(
          "AI didn't return a JSON object.",
          code: 'parse',
        );
      }
      improved = parsed;
    } catch (e) {
      throw SmartImportException(
        "AI didn't return valid JSON: $e",
        code: 'parse',
      );
    }

    return _mergeDrafts(initialDraft, improved);
  }

  Future<http.Response> _postToAnthropic({
    required String apiKey,
    required String body,
  }) async {
    try {
      return await _client
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: <String, String>{
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
              'accept': 'application/json',
            },
            body: body,
          )
          .timeout(AiSmartImportConfig.requestTimeout);
    } on TimeoutException {
      throw const SmartImportException(
        'Network timeout talking to Anthropic.',
        code: 'timeout',
      );
    } catch (e) {
      throw SmartImportException(
        'Network error talking to Anthropic: $e',
        code: 'network',
      );
    }
  }

  // ─────────────── helpers ───────────────

  /// JSON-only system prompt for BYOK mode. Tight, terse, scoped.
  /// Reloaders are skeptical of AI — the prompt makes it clear the
  /// model's job is structured-data extraction, NOT advice.
  static const String _systemPrompt = '''
You translate handwritten reloading-notebook OCR into structured fields.

Output ONLY a single JSON object matching the shape provided. Do not add
explanations, refusals, or any other content. If you cannot improve a
field, omit it from the output. Never invent values not supported by the
OCR. You are NOT giving reloading advice — you are extracting what the
user already wrote.
''';

  String _buildUserPrompt({
    required String ocrText,
    required RecipeDraft initialDraft,
    Map<String, dynamic>? catalogHints,
  }) {
    final initial = jsonEncode(_draftToJson(initialDraft));
    final hints = catalogHints == null ? '{}' : jsonEncode(catalogHints);
    return '''
OCR_TEXT:
$ocrText

INITIAL_DRAFT (from on-device parser, may have low-confidence fields):
$initial

CATALOG_HINTS (known cartridges, powders, bullets — pick the closest match):
$hints

Return a JSON object with this shape (omit any field you cannot improve):
{
  "recipeName": "...",
  "caliber": "...",
  "powder": "...",
  "powderChargeGr": 41.5,
  "bullet": "...",
  "bulletWeightGr": 140,
  "primer": "...",
  "brass": "...",
  "coalIn": 2.825,
  "cbtoIn": 2.215,
  "notes": "..."
}
''';
  }

  /// Anthropic's content array can hold multiple blocks. Concatenate
  /// every `text` block into a single string.
  String _extractAssistantText(dynamic content) {
    if (content is! List) return '';
    final buffer = StringBuffer();
    for (final block in content) {
      if (block is Map<String, dynamic>) {
        final type = block['type'];
        if (type == 'text') {
          final text = block['text'];
          if (text is String) buffer.write(text);
        }
      }
    }
    return buffer.toString().trim();
  }

  /// The model occasionally wraps JSON in a fenced ```json … ``` block.
  /// Strip it before decoding.
  String _stripJsonFence(String s) {
    final trimmed = s.trim();
    final fence = RegExp(r'^```(?:json)?\s*', caseSensitive: false);
    if (fence.hasMatch(trimmed)) {
      var inner = trimmed.replaceFirst(fence, '');
      if (inner.endsWith('```')) {
        inner = inner.substring(0, inner.length - 3);
      }
      return inner.trim();
    }
    return trimmed;
  }

  /// Convert a `RecipeDraft` to the JSON shape the AI sees. Strips
  /// confidence scores and source text — the AI doesn't need them.
  Map<String, dynamic> _draftToJson(RecipeDraft d) {
    final json = <String, dynamic>{};
    if (d.recipeName != null) json['recipeName'] = d.recipeName;
    if (d.caliber != null) json['caliber'] = d.caliber!.value;
    if (d.powder != null) json['powder'] = d.powder!.value;
    if (d.powderChargeGr != null) {
      json['powderChargeGr'] = d.powderChargeGr!.value;
    }
    if (d.bullet != null) json['bullet'] = d.bullet!.value;
    if (d.bulletWeightGr != null) {
      json['bulletWeightGr'] = d.bulletWeightGr!.value;
    }
    if (d.primer != null) json['primer'] = d.primer!.value;
    if (d.brass != null) json['brass'] = d.brass!.value;
    if (d.coalIn != null) json['coalIn'] = d.coalIn!.value;
    if (d.cbtoIn != null) json['cbtoIn'] = d.cbtoIn!.value;
    if (d.notes != null) json['notes'] = d.notes;
    return json;
  }

  /// Merge an AI-emitted `improved_draft` JSON map onto the original
  /// `RecipeDraft`. Fields the AI omitted come from the original;
  /// fields the AI included replace the original with a high-
  /// confidence (0.85) `ParsedField`. The `sourceText` carries
  /// "AI Smart Import" as the provenance label so the review UI
  /// can show users where the value came from.
  RecipeDraft _mergeDrafts(
    RecipeDraft original,
    Map<String, dynamic> improved,
  ) {
    String? readString(String key) {
      final v = improved[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    double? readDouble(String key) {
      final v = improved[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim());
      return null;
    }

    ParsedField<String>? takeString(
      String key,
      ParsedField<String>? originalField,
    ) {
      final next = readString(key);
      if (next == null) return originalField;
      return ParsedField<String>(
        value: next,
        confidence: 0.85,
        sourceText: 'AI Smart Import',
      );
    }

    ParsedField<double>? takeDouble(
      String key,
      ParsedField<double>? originalField,
    ) {
      final next = readDouble(key);
      if (next == null) return originalField;
      return ParsedField<double>(
        value: next,
        confidence: 0.85,
        sourceText: 'AI Smart Import',
      );
    }

    return RecipeDraft(
      recipeName: readString('recipeName') ?? original.recipeName,
      caliber: takeString('caliber', original.caliber),
      powder: takeString('powder', original.powder),
      powderChargeGr: takeDouble('powderChargeGr', original.powderChargeGr),
      bullet: takeString('bullet', original.bullet),
      bulletWeightGr: takeDouble('bulletWeightGr', original.bulletWeightGr),
      primer: takeString('primer', original.primer),
      brass: takeString('brass', original.brass),
      coalIn: takeDouble('coalIn', original.coalIn),
      cbtoIn: takeDouble('cbtoIn', original.cbtoIn),
      notes: readString('notes') ?? original.notes,
    );
  }

  HostedUsageStats _parseUsage(Map<String, dynamic> quota) {
    final used = quota['used_this_month'];
    final cap = quota['monthly_cap'];
    final resets = quota['resets_at'];
    return HostedUsageStats(
      usedThisMonth: used is int ? used : 0,
      monthlyCap: cap is int ? cap : AiSmartImportConfig.monthlyCap,
      resetsAt: resets is String
          ? (DateTime.tryParse(resets) ?? _nextMonthUtc())
          : _nextMonthUtc(),
    );
  }

  DateTime _nextMonthUtc() {
    final now = DateTime.now().toUtc();
    final nextMonth = now.month == 12
        ? DateTime.utc(now.year + 1, 1, 1)
        : DateTime.utc(now.year, now.month + 1, 1);
    return nextMonth;
  }

  Never _throwProxyErrorBody(int status, String body) {
    String message =
        'AI Smart Import is unavailable (HTTP $status). Try again shortly.';
    String? code;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final m = decoded['error'] ?? decoded['message'];
        if (m is String && m.isNotEmpty) message = m;
        final c = decoded['code'];
        if (c is String) code = c;
        final quota = decoded['quota'];
        if (quota is Map<String, dynamic>) {
          _lastHostedUsage = _parseUsage(quota);
        }
      }
    } catch (_) {
      // body wasn't JSON — keep default message
    }
    if (status == 429 || code == 'quota_exceeded') {
      throw SmartImportException(
        message,
        code: 'quota_exceeded',
        statusCode: status,
      );
    }
    if (status == 401 || status == 403 || code == 'forbidden') {
      throw SmartImportException(
        message,
        code: 'forbidden',
        statusCode: status,
      );
    }
    throw SmartImportException(message, code: code, statusCode: status);
  }

  Never _throwAnthropicErrorBody(int status, String body) {
    String message =
        'Anthropic returned an error (HTTP $status).';
    String? code;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final err = decoded['error'];
        if (err is Map<String, dynamic>) {
          final m = err['message'];
          if (m is String && m.isNotEmpty) message = m;
          final t = err['type'];
          if (t is String) code = t;
        }
      }
    } catch (_) {
      // body wasn't JSON — keep default message
    }
    if (status == 401) {
      throw SmartImportException(
        'Anthropic rejected the API key. Double-check it in Settings.',
        code: 'invalid_key',
        statusCode: 401,
      );
    }
    throw SmartImportException(message, code: code, statusCode: status);
  }
}

enum _Mode { byok, hosted }
