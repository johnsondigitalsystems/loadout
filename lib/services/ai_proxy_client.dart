// FILE: lib/services/ai_proxy_client.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// HTTP client for the LoadOut AI proxy backend. The proxy is the planned
// replacement for "Anthropic key embedded in the app binary": it accepts
// a chat request from the client, looks up the caller's RevenueCat
// entitlement + monthly quota server-side, and forwards the conversation
// to Anthropic's Messages API on the server's Anthropic key.
//
// What ships here:
//
//   - `AiProxyMessage` — minimal `{role, content}` value type matching
//     the Anthropic Messages shape the proxy expects.
//   - `AiProxyResponse` — the parsed reply from the proxy: assistant
//     text (assembled from streaming events) plus optional quota and
//     entitlement metadata.
//   - `AiProxyClient` — the workhorse. POSTs `{messages, user_id}` to
//     `${AiProxyConfig.backendUrl}${AiProxyConfig.chatPath}` and parses
//     the response body. Supports both line-delimited streaming
//     (one JSON object per line, each carrying a chunk of the assistant
//     reply) and a single-JSON fallback for simpler proxy
//     implementations.
//   - `AiProxyException` family — thrown for network failures,
//     non-2xx responses, quota exhaustion, and proxy-reported safety
//     refusals. Lets `AiChatService` map proxy errors to the same
//     `AiChatResult` cases the UI already understands.
//
// The wire format the proxy is expected to honor:
//
//     POST {backendUrl}/v1/chat
//     headers: { content-type: application/json }
//     body: {
//       "messages": [
//         {"role": "user",      "content": "..."},
//         {"role": "assistant", "content": "..."},
//         ...
//       ],
//       "user_id": "<RevenueCat appUserID>"
//     }
//
//     200 OK
//     content-type: application/x-ndjson  (or text/event-stream, or
//                                          application/json)
//     body, one JSON object per line:
//       {"type":"delta",  "text":"Hello"}
//       {"type":"delta",  "text":" there"}
//       {"type":"done",   "stop_reason":"end_turn"}
//       {"type":"meta",   "questions_used_this_month":12,
//                          "monthly_quota":30}
//
//     If the server prefers a single JSON object instead of a stream:
//       {"text":"...","questions_used_this_month":12,"monthly_quota":30}
//
//     Errors return non-2xx with:
//       {"error":"<short message>","code":"quota_exceeded"|"forbidden"|...}
//
// `AiProxyClient` accepts both shapes because the server hasn't been
// built yet and we don't want to lock the proxy author into a
// particular framing today. As soon as the proxy lands and a final
// shape is chosen, the parser can be tightened.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `AiChatService` was the only file that knew about Anthropic. With the
// proxy migration we want a clean seam: `AiChatService` keeps its
// public surface (quota tracking, the `looksLikeLoadData` regex
// backstop, the `AiChatResult` sum type) and delegates the actual HTTP
// to this file when a real backend URL is configured. Everything
// related to "what does the proxy URL look like, what headers does it
// take, how is the response framed" stays here.
//
// The RevenueCat `appUserID` is the only identifier we send. It's the
// same opaque id the SDK manages on-device. The proxy uses it to call
// RevenueCat's REST API server-side, verify the Pro entitlement is
// active, increment its own quota counter, and reject requests when
// the user is not entitled or has burned through the monthly cap. No
// Firebase Auth token is sent because RevenueCat is the source of
// truth for "is this person allowed to use AI chat at all" — Firebase
// Auth only governs cloud backup and (eventually) shared loads.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. STREAMING PARSE STATE MACHINE. The response body is parsed as
//    UTF-8 with a pluggable line splitter so partial lines at chunk
//    boundaries don't get lost. Each line is decoded as JSON; bad
//    lines are skipped (the proxy may emit comments / heartbeats).
//    A single JSON-object response is detected by sniffing the first
//    non-whitespace byte — `{` followed by no newline before EOF.
// 2. TIMEOUT BEHAVIOUR. We bound the whole call (including stream
//    duration) by `AiProxyConfig.requestTimeout`. If a chunk hasn't
//    arrived in that window the call is cancelled and surfaced as a
//    network error.
// 3. ERROR SHAPING. Proxy errors must map cleanly onto the existing
//    `AiChatResult` cases. We model that with a small exception
//    hierarchy so callers can `try/catch` on `AiProxyQuotaException`
//    specifically and fall through to `AiProxyException` for
//    everything else.
// 4. NO STATEFUL CONNECTION. The client is intentionally stateless;
//    every call constructs a fresh request. The HTTP `Client` is
//    injectable for tests but defaults to a real `http.Client`.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/services/ai_chat_service.dart` — instantiates an
//   `AiProxyClient` once and calls `sendMessage` from `sendMessage`
//   when `AiProxyConfig.isPlaceholder` is false.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - HTTPS POST to the proxy's `/v1/chat` endpoint.
// - `debugPrint` on parse failures so developers can spot proxy-shape
//   mismatches during integration.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ai_proxy_config.dart';

/// One turn in the conversation history sent to the proxy.
@immutable
class AiProxyMessage {
  const AiProxyMessage({required this.role, required this.content});

  /// `'user'` or `'assistant'`.
  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Parsed result of a proxy call. The proxy is permitted to emit
/// quota/entitlement metadata alongside the assistant text; both fields
/// are optional so the client tolerates a minimal proxy implementation
/// that returns nothing more than `text`.
@immutable
class AiProxyResponse {
  const AiProxyResponse({
    required this.text,
    this.questionsUsedThisMonth,
    this.monthlyQuota,
    this.stopReason,
  });

  /// Final assistant text, with all streamed deltas concatenated.
  final String text;

  /// If the proxy reports it, the user's monthly question count after
  /// this call. The client prefers this value over its own
  /// SharedPreferences counter when present.
  final int? questionsUsedThisMonth;

  /// If the proxy reports it, the monthly quota cap.
  final int? monthlyQuota;

  /// Anthropic-style stop reason if the proxy passes it through.
  final String? stopReason;
}

/// Base exception for proxy failures.
class AiProxyException implements Exception {
  AiProxyException(this.message, {this.code, this.statusCode});

  /// Human-readable error string suitable for showing to the user.
  final String message;

  /// Machine-readable code if the proxy returned one.
  final String? code;

  /// HTTP status code, if the failure was an HTTP-level error.
  final int? statusCode;

  @override
  String toString() => 'AiProxyException($message, code=$code, '
      'statusCode=$statusCode)';
}

/// Thrown when the proxy reports the caller has exhausted their
/// monthly question quota. `AiChatService` maps this to
/// `AiChatResult.quotaExceeded`.
class AiProxyQuotaException extends AiProxyException {
  AiProxyQuotaException({
    required String message,
    this.questionsUsedThisMonth,
    this.monthlyQuota,
  }) : super(message, code: 'quota_exceeded', statusCode: 429);

  final int? questionsUsedThisMonth;
  final int? monthlyQuota;
}

/// Thrown when the proxy refuses the call because the caller is not
/// Pro-entitled. The UI should redirect to the paywall.
class AiProxyForbiddenException extends AiProxyException {
  AiProxyForbiddenException({required String message})
      : super(message, code: 'forbidden', statusCode: 403);
}

/// HTTP client for the LoadOut AI proxy. Injectable `http.Client` for
/// tests; default constructor uses a real `http.Client()`.
class AiProxyClient {
  AiProxyClient({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  /// POST [messages] (with the new user turn already appended) plus the
  /// caller's RevenueCat [userId] to the configured proxy. Throws
  /// [AiProxyException] (or one of its subclasses) on failure.
  ///
  /// Streams the response body line-by-line and accumulates the
  /// assistant text. Falls back to single-JSON parsing if the body
  /// turns out to be one object instead of a newline-delimited stream.
  Future<AiProxyResponse> sendMessage({
    required List<AiProxyMessage> messages,
    required String userId,
  }) async {
    if (AiProxyConfig.isPlaceholder) {
      throw AiProxyException(
        'AI proxy is not configured.',
        code: 'not_configured',
      );
    }

    final uri = Uri.parse(
      '${AiProxyConfig.backendUrl}${AiProxyConfig.chatPath}',
    );
    final body = jsonEncode({
      'messages': [for (final m in messages) m.toJson()],
      'user_id': userId,
    });

    final request = http.Request('POST', uri)
      ..headers['content-type'] = 'application/json'
      ..headers['accept'] = 'application/x-ndjson, application/json'
      ..body = body;

    http.StreamedResponse streamed;
    try {
      streamed = await _client
          .send(request)
          .timeout(AiProxyConfig.requestTimeout);
    } on TimeoutException {
      throw AiProxyException(
        'Network timeout. Check your connection and try again.',
        code: 'timeout',
      );
    } catch (e) {
      throw AiProxyException(
        'Network error. Check your connection and try again.',
        code: 'network',
      );
    }

    final status = streamed.statusCode;
    final responseBytes =
        await streamed.stream.toBytes().timeout(
              AiProxyConfig.requestTimeout,
              onTimeout: () => throw AiProxyException(
                'Network timeout reading response.',
                code: 'timeout',
              ),
            );
    final responseText = utf8.decode(responseBytes, allowMalformed: true);

    if (status < 200 || status >= 300) {
      _throwForErrorBody(status, responseText);
    }

    return _parseSuccess(responseText);
  }

  /// Parse a 2xx body. Tries newline-delimited JSON first; if that
  /// produces no events, falls back to parsing as a single JSON object.
  AiProxyResponse _parseSuccess(String body) {
    final buffer = StringBuffer();
    int? quotaUsed;
    int? quotaCap;
    String? stopReason;
    var sawAnyEvent = false;

    for (final rawLine in const LineSplitter().convert(body)) {
      // SSE-style "data: {...}" framing tolerated as well.
      var line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('data:')) {
        line = line.substring(5).trim();
        if (line.isEmpty) continue;
      }
      if (line == '[DONE]') {
        // Conventional SSE terminator — nothing to read.
        sawAnyEvent = true;
        continue;
      }
      Map<String, dynamic>? event;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) event = decoded;
      } catch (_) {
        // Non-JSON line. Could be a comment / heartbeat — skip.
      }
      if (event == null) continue;
      sawAnyEvent = true;

      final type = event['type'];
      if (type == 'delta') {
        final text = event['text'];
        if (text is String) buffer.write(text);
      } else if (type == 'meta') {
        final used = event['questions_used_this_month'];
        if (used is int) quotaUsed = used;
        final cap = event['monthly_quota'];
        if (cap is int) quotaCap = cap;
      } else if (type == 'done') {
        final reason = event['stop_reason'];
        if (reason is String) stopReason = reason;
      } else if (type == 'error') {
        final message = event['message'] ?? 'Assistant error.';
        final code = event['code'];
        if (code == 'quota_exceeded') {
          throw AiProxyQuotaException(
            message: message is String ? message : 'Quota exceeded.',
            questionsUsedThisMonth: quotaUsed,
            monthlyQuota: quotaCap,
          );
        }
        throw AiProxyException(
          message is String ? message : 'Assistant error.',
          code: code is String ? code : null,
        );
      } else if (type == null) {
        // Single-shot JSON object using the {"text": "..."} shape.
        final text = event['text'];
        if (text is String) buffer.write(text);
        final used = event['questions_used_this_month'];
        if (used is int) quotaUsed = used;
        final cap = event['monthly_quota'];
        if (cap is int) quotaCap = cap;
      }
    }

    // Single-JSON fallback for proxies that don't stream.
    if (!sawAnyEvent && body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          final text = decoded['text'];
          if (text is String) buffer.write(text);
          final used = decoded['questions_used_this_month'];
          if (used is int) quotaUsed = used;
          final cap = decoded['monthly_quota'];
          if (cap is int) quotaCap = cap;
          final reason = decoded['stop_reason'];
          if (reason is String) stopReason = reason;
        }
      } catch (e) {
        debugPrint('AiProxyClient: parse error on single-JSON body: $e');
        throw AiProxyException(
          "Couldn't read assistant response.",
          code: 'parse',
        );
      }
    }

    final text = buffer.toString().trim();
    if (text.isEmpty) {
      throw AiProxyException(
        'Assistant returned an empty response.',
        code: 'empty',
      );
    }

    return AiProxyResponse(
      text: text,
      questionsUsedThisMonth: quotaUsed,
      monthlyQuota: quotaCap,
      stopReason: stopReason,
    );
  }

  /// Maps a non-2xx response onto a typed exception.
  Never _throwForErrorBody(int status, String body) {
    String message =
        'Assistant unavailable (HTTP $status). Try again shortly.';
    String? code;
    int? quotaUsed;
    int? quotaCap;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final m = decoded['error'] ?? decoded['message'];
        if (m is String && m.isNotEmpty) message = m;
        final c = decoded['code'];
        if (c is String) code = c;
        final used = decoded['questions_used_this_month'];
        if (used is int) quotaUsed = used;
        final cap = decoded['monthly_quota'];
        if (cap is int) quotaCap = cap;
      }
    } catch (_) {
      // Body wasn't JSON — keep the default message.
    }

    if (status == 429 || code == 'quota_exceeded') {
      throw AiProxyQuotaException(
        message: message,
        questionsUsedThisMonth: quotaUsed,
        monthlyQuota: quotaCap,
      );
    }
    if (status == 403 || code == 'forbidden') {
      throw AiProxyForbiddenException(message: message);
    }
    throw AiProxyException(message, code: code, statusCode: status);
  }

  /// Close the underlying HTTP client if we created it. Tests that
  /// passed in their own client are responsible for closing it.
  void dispose() {
    if (_ownsClient) _client.close();
  }
}
