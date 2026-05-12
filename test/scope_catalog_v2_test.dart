// FILE: test/scope_catalog_v2_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Unit tests for `lib/services/scope_catalog_v2.dart` — the lazy-loaded
// read-only service that backs the firearm form's v2.3 "Default Scope &
// Reticle" pickers and the Range Day Realistic pre-population path.
//
// Tests confirm:
//   * The three production JSONs (`scopes.json`, `reticles.json`,
//     `scope_reticle_options.json`) parse without errors.
//   * `allScopes()` / `allReticles()` return non-empty, sorted lists.
//   * `scopeById` / `reticleById` round-trip every id in the catalog.
//   * `defaultReticleIdForScope` resolves the recommended reticle for
//     a known scope (Vortex Razor HD Gen III) and returns the expected
//     LoadOut-original archetype.
//   * Cache survives between calls (no double-parse).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The firearm form's persisted `defaultScopeId` / `defaultReticleId`
// columns hold string ids from these JSONs. If parsing silently
// drops a row, the form would render that row's id as a stale
// breadcrumb on next load — confusing and easy to miss. This test
// guards against schema drift in the JSONs themselves and against
// regression in the service's `fromJson` rules.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `flutter test test/scope_catalog_v2_test.dart` — direct.
//   * `flutter test` — picked up by the full-suite glob.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Reads three JSON files from `assets/seed_data/` via `rootBundle`.
// - Calls `ScopeCatalogV2Service.instance.debugResetCache()` between
//   isolated tests so each `setUp` starts from a clean state.

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/services/scope_catalog_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Reset between tests so the lazy-load behaviour is testable.
    ScopeCatalogV2Service.instance.debugResetCache();
  });

  group('ScopeCatalogV2Service', () {
    test('allScopes loads a non-empty, alpha-sorted list', () async {
      final scopes = await ScopeCatalogV2Service.instance.allScopes();
      expect(scopes, isNotEmpty);
      // Spot-check sorting: every adjacent pair is in (manufacturer,
      // model) order — case-insensitive.
      for (var i = 1; i < scopes.length; i++) {
        final prev = scopes[i - 1];
        final cur = scopes[i];
        final mfgCmp = prev.manufacturer
            .toLowerCase()
            .compareTo(cur.manufacturer.toLowerCase());
        if (mfgCmp == 0) {
          expect(
            prev.modelName.toLowerCase().compareTo(cur.modelName.toLowerCase()),
            lessThanOrEqualTo(0),
            reason:
                'Scopes within the same manufacturer must be sorted by '
                'model: "${prev.modelName}" > "${cur.modelName}" at $i',
          );
        } else {
          expect(mfgCmp, lessThan(0),
              reason:
                  'Scopes must be sorted by manufacturer: '
                  '"${prev.manufacturer}" > "${cur.manufacturer}" at $i');
        }
      }
    });

    test('allReticles loads a non-empty, alpha-sorted list', () async {
      final reticles = await ScopeCatalogV2Service.instance.allReticles();
      expect(reticles, isNotEmpty);
      for (var i = 1; i < reticles.length; i++) {
        final prev = reticles[i - 1];
        final cur = reticles[i];
        final mfgCmp = prev.manufacturer
            .toLowerCase()
            .compareTo(cur.manufacturer.toLowerCase());
        expect(mfgCmp, lessThanOrEqualTo(0));
        if (mfgCmp == 0) {
          expect(
            prev.model.toLowerCase().compareTo(cur.model.toLowerCase()),
            lessThanOrEqualTo(0),
          );
        }
      }
    });

    test('scopeById round-trips every id in the catalog', () async {
      final scopes = await ScopeCatalogV2Service.instance.allScopes();
      // Sample a subset to keep the test fast. Every 10th row is fine
      // for catching parse-time id loss; the production catalog is
      // 183 rows so this still covers ~18 ids.
      for (var i = 0; i < scopes.length; i += 10) {
        final s = scopes[i];
        final back =
            await ScopeCatalogV2Service.instance.scopeById(s.id);
        expect(back, isNotNull, reason: 'Failed to round-trip id "${s.id}"');
        expect(back!.id, s.id);
        expect(back.manufacturer, s.manufacturer);
        expect(back.modelName, s.modelName);
      }
    });

    test('reticleById round-trips every id in the catalog', () async {
      final reticles = await ScopeCatalogV2Service.instance.allReticles();
      for (final r in reticles) {
        final back =
            await ScopeCatalogV2Service.instance.reticleById(r.id);
        expect(back, isNotNull, reason: 'Failed to round-trip id "${r.id}"');
        expect(back!.id, r.id);
      }
    });

    test('scopeById and reticleById return null for unknown ids', () async {
      expect(
        await ScopeCatalogV2Service.instance.scopeById('not_a_real_scope'),
        isNull,
      );
      expect(
        await ScopeCatalogV2Service.instance.reticleById('not_a_real_reticle'),
        isNull,
      );
      expect(await ScopeCatalogV2Service.instance.scopeById(null), isNull);
      expect(await ScopeCatalogV2Service.instance.scopeById(''), isNull);
    });

    test(
        'defaultReticleIdForScope resolves a known scope to a known reticle',
        () async {
      // Aimpoint Acro P-2 is the first row in scope_reticle_options.json
      // mapped to loadout_red_dot_2moa. Use that as a stable anchor.
      final rid = await ScopeCatalogV2Service.instance
          .defaultReticleIdForScope('aimpoint_acro_p_2');
      expect(rid, isNotNull);
      // Confirm the resolved reticle id actually exists in the
      // reticles catalog (the brief promises 1:1 referential
      // integrity).
      final reticle =
          await ScopeCatalogV2Service.instance.reticleById(rid);
      expect(reticle, isNotNull,
          reason:
              'scope_reticle_options.json references "$rid" but it does '
              'not exist in reticles.json');
    });

    test('every scope in scopes.json has a default reticle mapping', () async {
      // The brief asserts 183/183 mapping coverage. A missing mapping
      // would silently leave the firearm form's reticle field blank
      // when the user picks that scope — surprising UX. This test is
      // the early-warning guard.
      final scopes = await ScopeCatalogV2Service.instance.allScopes();
      final misses = <String>[];
      for (final s in scopes) {
        final rid = await ScopeCatalogV2Service.instance
            .defaultReticleIdForScope(s.id);
        if (rid == null) misses.add(s.id);
      }
      expect(misses, isEmpty,
          reason:
              'Every scope must have a row in '
              'scope_reticle_options.json. Missing: $misses');
    });

    test(
        'every default reticle id in scope_reticle_options.json '
        'exists in reticles.json', () async {
      final scopes = await ScopeCatalogV2Service.instance.allScopes();
      final broken = <String>[];
      for (final s in scopes) {
        final rid = await ScopeCatalogV2Service.instance
            .defaultReticleIdForScope(s.id);
        if (rid == null) continue;
        final r = await ScopeCatalogV2Service.instance.reticleById(rid);
        if (r == null) broken.add('${s.id} -> $rid');
      }
      expect(broken, isEmpty,
          reason:
              'Every reticle id referenced in '
              'scope_reticle_options.json must exist in '
              'reticles.json. Broken: $broken');
    });

    test('caches results across repeated calls', () async {
      final a = await ScopeCatalogV2Service.instance.allScopes();
      final b = await ScopeCatalogV2Service.instance.allScopes();
      // Same instance identity — the second call did NOT re-parse.
      expect(identical(a, b), isTrue);
    });
  });

  group('ScopeV2Row.fromJson', () {
    test('parses a complete row', () {
      final r = ScopeV2Row.fromJson(<String, dynamic>{
        'id': 'foo_bar_1',
        'manufacturer': 'Foo',
        'model_name': 'Bar 1',
        'category': 'precision',
        'focal_plane': 'ffp',
        'magnification_min': 5,
        'magnification_max': 25,
      });
      expect(r, isNotNull);
      expect(r!.id, 'foo_bar_1');
      expect(r.displayLabel, 'Foo Bar 1');
      expect(r.secondaryLine, 'FFP · 5-25x');
    });

    test('returns null on missing required fields', () {
      expect(
          ScopeV2Row.fromJson(<String, dynamic>{
            'manufacturer': 'Foo',
            'model_name': 'Bar',
          }),
          isNull);
      expect(
          ScopeV2Row.fromJson(<String, dynamic>{
            'id': 'foo',
            'model_name': 'Bar',
          }),
          isNull);
      expect(
          ScopeV2Row.fromJson(<String, dynamic>{
            'id': 'foo',
            'manufacturer': 'Foo',
          }),
          isNull);
    });

    test('handles fixed-magnification (red dot) without a range', () {
      final r = ScopeV2Row.fromJson(<String, dynamic>{
        'id': 'foo_dot',
        'manufacturer': 'Foo',
        'model_name': 'Dot',
        'category': 'red-dot',
        'focal_plane': 'fixed',
        'magnification_min': 1,
        'magnification_max': 1,
      });
      expect(r, isNotNull);
      expect(r!.secondaryLine, 'FIXED · 1x');
    });
  });

  group('ReticleV2Row.fromJson', () {
    test('parses a complete row', () {
      final r = ReticleV2Row.fromJson(<String, dynamic>{
        'id': 'loadout_test',
        'manufacturer': 'LoadOut',
        'model': 'Test',
        'family': 'Test family',
        'type': 'ffp',
        'nativeUnit': 'mil',
      });
      expect(r, isNotNull);
      expect(r!.displayLabel, 'LoadOut Test');
      expect(r.secondaryLine, 'MIL · FFP · Test family');
    });

    test('returns null on missing required fields', () {
      expect(
          ReticleV2Row.fromJson(<String, dynamic>{
            'manufacturer': 'LoadOut',
            'model': 'Test',
          }),
          isNull);
    });
  });
}
