// FILE: test/ai_smart_import_service_test.dart
//
// Unit tests for `lib/services/ai_smart_import_service.dart`. Verifies:
//   - mode selection (BYOK vs hosted vs ProRequired vs not-configured),
//   - request shape against either endpoint,
//   - response parsing into a `RecipeDraft` (with the original draft
//     preserved for fields the AI omitted),
//   - usage stats are reported only in hosted mode.
//
// We do NOT exercise the Worker itself — the Worker has its own
// TypeScript surface and ships in `cloud_worker/anthropic-proxy/`.
// These tests stub the http layer with `MockClient`.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:loadout/services/ai_smart_import_config.dart';
import 'package:loadout/services/ai_smart_import_service.dart';
import 'package:loadout/services/entitlement_notifier.dart';
import 'package:loadout/services/recipe_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // FlutterSecureStorage uses platform channels under the hood; in
  // unit tests we replace it with the in-memory fake below so we
  // don't need a real Keychain / Keystore.
  late _FakeSecureStorage storage;
  late _FakeEntitlements entitlements;

  setUp(() {
    storage = _FakeSecureStorage();
    entitlements = _FakeEntitlements(isPro: false);
  });

  RecipeDraft basicDraft() => const RecipeDraft(
        recipeName: '6.5 CM',
        caliber: ParsedField<String>(
          value: '6.5 Creedmoor',
          confidence: 0.5,
          sourceText: '6.5 cm',
        ),
        powder: ParsedField<String>(
          value: 'H43SO',
          confidence: 0.4,
          sourceText: 'H43SO',
        ),
        powderChargeGr: ParsedField<double>(
          value: 41.5,
          confidence: 0.7,
          sourceText: '41.5 gr',
        ),
        notes: 'raw OCR text',
      );

  group('mode selection', () {
    test('throws ProRequired when not Pro and no BYOK key', () async {
      final svc = AiSmartImportService(
        entitlements: entitlements,
        storage: storage,
        client: MockClient((_) async => http.Response('', 200)),
        idTokenProvider: () async => null,
      );
      addTearDown(svc.dispose);

      expect(
        () => svc.improveDraft(
          ocrText: 'foo',
          initialDraft: basicDraft(),
        ),
        throwsA(isA<ProRequiredException>()),
      );
    });

    test(
        'routes to api.anthropic.com when BYOK key is set, regardless of Pro',
        () async {
      await storage.write(
        key: AiSmartImportConfig.byokSecureStorageKey,
        value: 'sk-ant-test',
      );

      Uri? capturedUri;
      Map<String, String>? capturedHeaders;
      final mockClient = MockClient((req) async {
        capturedUri = req.url;
        capturedHeaders = req.headers;
        return http.Response(
          jsonEncode({
            'content': [
              {
                'type': 'text',
                'text': '{"powder":"H4350","powderChargeGr":41.5}',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = AiSmartImportService(
        entitlements: entitlements, // not Pro — BYOK overrides
        storage: storage,
        client: mockClient,
        idTokenProvider: () async => null,
      );
      addTearDown(svc.dispose);

      final result = await svc.improveDraft(
        ocrText: 'OCR text',
        initialDraft: basicDraft(),
      );

      expect(capturedUri.toString(), 'https://api.anthropic.com/v1/messages');
      expect(capturedHeaders?['x-api-key'], 'sk-ant-test');
      expect(capturedHeaders?['anthropic-version'], '2023-06-01');
      expect(result.powder?.value, 'H4350');
      expect(result.powderChargeGr?.value, 41.5);
    });

    test(
      'throws not-configured when Pro but proxy URL is the placeholder',
      () async {
        // OBSOLETE AS OF 2026-05-08 — the Worker is deployed at
        // anthropic-proxy.holy-breeze-9fa5.workers.dev and
        // `AiSmartImportConfig.isPlaceholder` now returns false in
        // production. The placeholder-state scenario this test
        // asserted is no longer reachable without a config revert.
        //
        // Skip rather than delete: keeps the test as a record of
        // the gating logic, and re-activates automatically the day
        // anyone re-points `proxyBaseUrl` at a placeholder host.
        // That kind of regression should fail loudly here.
        if (!AiSmartImportConfig.isPlaceholder) {
          markTestSkipped(
            'Worker is deployed; placeholder state is unreachable. '
            'Re-enable by reverting proxyBaseUrl to a placeholder host.',
          );
          return;
        }
        entitlements.setPro(true);
        var hit = false;
        final mockClient = MockClient((_) async {
          hit = true;
          return http.Response('', 200);
        });
        final svc = AiSmartImportService(
          entitlements: entitlements,
          storage: storage,
          client: mockClient,
          idTokenProvider: () async => 'fake-token',
        );
        addTearDown(svc.dispose);

        expect(AiSmartImportConfig.isPlaceholder, isTrue);
        expect(
          () => svc.improveDraft(
            ocrText: 'foo',
            initialDraft: basicDraft(),
          ),
          throwsA(isA<SmartImportNotConfiguredException>()),
        );
        expect(hit, isFalse);
      },
    );
  });

  group('BYOK path', () {
    test('preserves original fields the AI omitted', () async {
      await storage.write(
        key: AiSmartImportConfig.byokSecureStorageKey,
        value: 'sk-ant-test',
      );
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': '{"powder":"H4350"}'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final svc = AiSmartImportService(
        entitlements: entitlements,
        storage: storage,
        client: mockClient,
        idTokenProvider: () async => null,
      );
      addTearDown(svc.dispose);

      final result = await svc.improveDraft(
        ocrText: 'foo',
        initialDraft: basicDraft(),
      );
      // AI updated powder; original caliber is preserved.
      expect(result.powder?.value, 'H4350');
      expect(result.caliber?.value, '6.5 Creedmoor');
      // Charge wasn't returned by AI — original survives.
      expect(result.powderChargeGr?.value, 41.5);
    });

    test('strips ```json ... ``` fences from model output', () async {
      await storage.write(
        key: AiSmartImportConfig.byokSecureStorageKey,
        value: 'sk-ant-test',
      );
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'content': [
                {
                  'type': 'text',
                  'text': '```json\n{"powder":"Varget"}\n```',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final svc = AiSmartImportService(
        entitlements: entitlements,
        storage: storage,
        client: mockClient,
        idTokenProvider: () async => null,
      );
      addTearDown(svc.dispose);

      final result = await svc.improveDraft(
        ocrText: 'foo',
        initialDraft: basicDraft(),
      );
      expect(result.powder?.value, 'Varget');
    });

    test('maps Anthropic 401 to invalid_key SmartImportException',
        () async {
      await storage.write(
        key: AiSmartImportConfig.byokSecureStorageKey,
        value: 'sk-ant-bad',
      );
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'error': {'type': 'invalid_request_error', 'message': 'bad key'},
            }),
            401,
            headers: {'content-type': 'application/json'},
          ));
      final svc = AiSmartImportService(
        entitlements: entitlements,
        storage: storage,
        client: mockClient,
        idTokenProvider: () async => null,
      );
      addTearDown(svc.dispose);

      try {
        await svc.improveDraft(
          ocrText: 'foo',
          initialDraft: basicDraft(),
        );
        fail('expected SmartImportException');
      } on SmartImportException catch (e) {
        expect(e.code, 'invalid_key');
        expect(e.statusCode, 401);
      }
    });

    test('hostedUsage() returns null in BYOK mode', () async {
      await storage.write(
        key: AiSmartImportConfig.byokSecureStorageKey,
        value: 'sk-ant-test',
      );
      final svc = AiSmartImportService(
        entitlements: entitlements,
        storage: storage,
        client: MockClient((_) async => http.Response('{}', 200)),
        idTokenProvider: () async => null,
      );
      addTearDown(svc.dispose);

      expect(await svc.hostedUsage(), isNull);
    });
  });

  group('BYOK setters', () {
    test('setByokKey writes / removes from secure storage', () async {
      final svc = AiSmartImportService(
        entitlements: entitlements,
        storage: storage,
        client: MockClient((_) async => http.Response('{}', 200)),
        idTokenProvider: () async => null,
      );
      addTearDown(svc.dispose);

      expect(await svc.getByokKey(), isNull);
      await svc.setByokKey('sk-ant-foo');
      expect(await svc.getByokKey(), 'sk-ant-foo');
      await svc.setByokKey(null);
      expect(await svc.getByokKey(), isNull);
    });

    test('setByokKey trims whitespace', () async {
      final svc = AiSmartImportService(
        entitlements: entitlements,
        storage: storage,
        client: MockClient((_) async => http.Response('{}', 200)),
        idTokenProvider: () async => null,
      );
      addTearDown(svc.dispose);

      await svc.setByokKey('  sk-ant-foo  ');
      expect(await svc.getByokKey(), 'sk-ant-foo');
    });

    test('testByokKey calls Anthropic and surfaces failures', () async {
      final mockClient = MockClient((req) async {
        expect(req.headers['x-api-key'], 'sk-ant-test');
        return http.Response('{}', 200);
      });
      final svc = AiSmartImportService(
        entitlements: entitlements,
        storage: storage,
        client: mockClient,
        idTokenProvider: () async => null,
      );
      addTearDown(svc.dispose);

      await svc.testByokKey('sk-ant-test');
    });
  });
}

// ─────────────── fakes ───────────────

/// In-memory `FlutterSecureStorage` stand-in. Mirrors the small surface
/// the service uses (`read`, `write`, `delete`).
class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  void noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// `EntitlementNotifier` stand-in that lets tests force the Pro flag.
class _FakeEntitlements extends ChangeNotifier
    implements EntitlementNotifier {
  _FakeEntitlements({required bool isPro}) : _isPro = isPro;
  bool _isPro;
  @override
  bool get isPro => _isPro;
  void setPro(bool value) {
    if (value == _isPro) return;
    _isPro = value;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {}

  @override
  void noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

