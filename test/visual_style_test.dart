// FILE: test/visual_style_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Round-trip + safe-fallback regression tests for the [VisualStyle]
// enum's persistence contract (Phase 10 Group A). Pins:
//
//   1. `enum.persistKey` matches `enum.name` for every value (the
//      stable storage shape).
//   2. `fromPersistKey` returns the matching enum for every known
//      key string.
//   3. `fromPersistKey` falls back to `cartoon` for null / empty /
//      unknown strings (the safe default).
//   4. Round-trip: `VisualStyle.fromPersistKey(value.persistKey) ==
//      value` for every value.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure enum value-type tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/models/visual_style.dart';

void main() {
  group('VisualStyle — persistKey + fromPersistKey contract', () {
    test('persistKey matches enum.name for every value', () {
      expect(VisualStyle.cartoon.persistKey, 'cartoon');
      expect(VisualStyle.polished.persistKey, 'polished');
      expect(VisualStyle.photo.persistKey, 'photo');
    });

    test('fromPersistKey returns the matching enum for known keys', () {
      expect(VisualStyle.fromPersistKey('cartoon'), VisualStyle.cartoon);
      expect(VisualStyle.fromPersistKey('polished'), VisualStyle.polished);
      expect(VisualStyle.fromPersistKey('photo'), VisualStyle.photo);
    });

    test('fromPersistKey falls back to cartoon for null', () {
      expect(VisualStyle.fromPersistKey(null), VisualStyle.cartoon);
    });

    test('fromPersistKey falls back to cartoon for empty string', () {
      expect(VisualStyle.fromPersistKey(''), VisualStyle.cartoon);
    });

    test('fromPersistKey falls back to cartoon for unknown strings', () {
      expect(VisualStyle.fromPersistKey('high_contrast'),
          VisualStyle.cartoon);
      expect(VisualStyle.fromPersistKey('night_vision'),
          VisualStyle.cartoon);
      expect(VisualStyle.fromPersistKey('CARTOON'), VisualStyle.cartoon,
          reason:
              'Case-sensitive — only the lowercase enum.name string '
              'parses. Pinning this catches a future bug where someone '
              'normalises the input mid-flight.');
    });

    test('round-trip preserves every value', () {
      for (final v in VisualStyle.values) {
        expect(VisualStyle.fromPersistKey(v.persistKey), v);
      }
    });
  });

  group('VisualStyle — pref-key constant', () {
    test('kVisualStylePrefKey is stable', () {
      expect(kVisualStylePrefKey, 'visual_style');
    });
  });
}
