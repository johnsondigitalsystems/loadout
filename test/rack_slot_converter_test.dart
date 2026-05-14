// FILE: test/rack_slot_converter_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Round-trip and edge-case regression tests for the v40 (Phase 9.5
// Group C) `RackSlot` value class + its drift TypeConverter,
// `RackSlotsConverter`. The converter is what makes the v40 schema
// change tractable — every TargetRack's children ride inline as a
// JSON array, so the (de)serialisation logic has to be bulletproof.
// One null-cast crash in `RackSlot.fromJson` is a failed cold-start.
//
// Coverage:
//   * Single-slot round-trip via the converter — to/from SQL string.
//   * Multi-slot round-trip preserves position order even when the
//     input list is out of order (the converter sorts defensively
//     on read).
//   * Empty SQL string returns an empty list (degenerate-rack guard).
//   * Returned list is unmodifiable — caller can't accidentally
//     mutate cached reference data.
//   * Optional fields (`shape_id` null vs populated) survive the
//     round-trip with the correct nullable behaviour.
//   * Required-field absence raises (TypeError) so a malformed seed
//     is loud rather than silent.
//   * `toString()` produces a readable debug string (smoke test).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure JSON (de)serialisation tests against in-memory strings.

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/database/rack_slot.dart';

void main() {
  group('RackSlot value type', () {
    test('round-trip preserves every field', () {
      const slot = RackSlot(
        position: 3,
        shapeId: 'pepper_popper',
        name: 'Popper #4',
        category: 'special',
        widthIn: 8.0,
        heightIn: 18.0,
        offsetXIn: 12.0,
        offsetYIn: 0.0,
        sizeRank: 1,
        colorHex: '#3b3b3b',
      );
      final json = slot.toJson();
      final parsed = RackSlot.fromJson(json);
      expect(parsed.position, slot.position);
      expect(parsed.shapeId, slot.shapeId);
      expect(parsed.name, slot.name);
      expect(parsed.category, slot.category);
      expect(parsed.widthIn, slot.widthIn);
      expect(parsed.heightIn, slot.heightIn);
      expect(parsed.offsetXIn, slot.offsetXIn);
      expect(parsed.offsetYIn, slot.offsetYIn);
      expect(parsed.sizeRank, slot.sizeRank);
      expect(parsed.colorHex, slot.colorHex);
    });

    test('null shapeId survives the round-trip', () {
      const slot = RackSlot(
        position: 0,
        name: 'Plate 1',
        category: 'circle',
        widthIn: 4.0,
        heightIn: 4.0,
        offsetXIn: -12.0,
        offsetYIn: 0.0,
        sizeRank: 1,
        colorHex: '#ffffff',
      );
      // toJson should OMIT the shape_id key when null — keeps the
      // stored JSON lean for the 80% of slots that don't need it.
      final json = slot.toJson();
      expect(json.containsKey('shape_id'), isFalse);
      final parsed = RackSlot.fromJson(json);
      expect(parsed.shapeId, isNull);
    });

    test('defaults: sizeRank=1, colorHex="#ffffff"', () {
      // The defaults exist for forward-compat with seed files that
      // pre-date the per-slot sizeRank / colorHex fields. fromJson
      // is the consumer of those defaults; toJson always emits.
      final parsed = RackSlot.fromJson(<String, dynamic>{
        'position': 0,
        'name': 'no-default-row',
        'category': 'circle',
        'width_in': 4,
        'height_in': 4,
        'x_offset_in': 0,
        'y_offset_in': 0,
      });
      expect(parsed.sizeRank, 1);
      expect(parsed.colorHex, '#ffffff');
    });

    test('missing required field throws TypeError (loud fail)', () {
      // No 'category' field — fromJson should throw on the `as
      // String` cast. Better than silently producing a malformed
      // RackSlot that crashes deep inside the painter.
      expect(
        () => RackSlot.fromJson(<String, dynamic>{
          'position': 0,
          'name': 'missing-category',
          'width_in': 4,
          'height_in': 4,
          'x_offset_in': 0,
          'y_offset_in': 0,
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('toString produces a readable debug string', () {
      const slot = RackSlot(
        position: 2,
        name: 'Plate 3',
        category: 'circle',
        widthIn: 3.0,
        heightIn: 3.0,
        offsetXIn: -4.0,
        offsetYIn: 0.0,
        sizeRank: 3,
        colorHex: '#ffffff',
      );
      final s = slot.toString();
      expect(s, contains('#2'));
      expect(s, contains('circle'));
      expect(s, contains('Plate 3'));
    });
  });

  group('RackSlotsConverter — drift TypeConverter', () {
    const converter = RackSlotsConverter();

    test('toSql / fromSql round-trip preserves a 5-slot rack', () {
      const slots = <RackSlot>[
        RackSlot(
          position: 0,
          name: 'Plate 1 (5 in)',
          category: 'circle',
          widthIn: 5,
          heightIn: 5,
          offsetXIn: -28,
          offsetYIn: 0,
          sizeRank: 1,
          colorHex: '#ffffff',
        ),
        RackSlot(
          position: 1,
          name: 'Plate 2 (4 in)',
          category: 'circle',
          widthIn: 4,
          heightIn: 4,
          offsetXIn: -16,
          offsetYIn: 0,
          sizeRank: 2,
          colorHex: '#ffffff',
        ),
        RackSlot(
          position: 2,
          name: 'Plate 3 (3 in)',
          category: 'circle',
          widthIn: 3,
          heightIn: 3,
          offsetXIn: -4,
          offsetYIn: 0,
          sizeRank: 3,
          colorHex: '#ffffff',
        ),
      ];
      final encoded = converter.toSql(slots);
      final decoded = converter.fromSql(encoded);
      expect(decoded.length, slots.length);
      for (var i = 0; i < slots.length; i++) {
        expect(decoded[i].position, slots[i].position);
        expect(decoded[i].category, slots[i].category);
        expect(decoded[i].widthIn, slots[i].widthIn);
      }
    });

    test('fromSql sorts by position defensively', () {
      // Hand-crafted JSON with slots in REVERSE position order. The
      // converter should re-sort so callers (painter, picker) never
      // have to.
      const malordered = '['
          '{"position":4,"name":"e","category":"circle","width_in":1,'
          '"height_in":1,"x_offset_in":0,"y_offset_in":0},'
          '{"position":0,"name":"a","category":"circle","width_in":1,'
          '"height_in":1,"x_offset_in":0,"y_offset_in":0},'
          '{"position":2,"name":"c","category":"circle","width_in":1,'
          '"height_in":1,"x_offset_in":0,"y_offset_in":0}'
          ']';
      final decoded = converter.fromSql(malordered);
      expect(decoded.map((s) => s.position), <int>[0, 2, 4]);
      expect(decoded.map((s) => s.name), <String>['a', 'c', 'e']);
    });

    test('fromSql with empty string returns empty unmodifiable list', () {
      final decoded = converter.fromSql('');
      expect(decoded, isEmpty);
      // Calling .add on the returned list should throw — caller
      // can't accidentally mutate the cached reference list.
      expect(
        () => decoded.add(const RackSlot(
          position: 0,
          name: 'x',
          category: 'circle',
          widthIn: 1,
          heightIn: 1,
          offsetXIn: 0,
          offsetYIn: 0,
          sizeRank: 1,
          colorHex: '#fff',
        )),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('returned list is unmodifiable', () {
      const slots = <RackSlot>[
        RackSlot(
          position: 0,
          name: 'a',
          category: 'circle',
          widthIn: 1,
          heightIn: 1,
          offsetXIn: 0,
          offsetYIn: 0,
          sizeRank: 1,
          colorHex: '#fff',
        ),
      ];
      final decoded = converter.fromSql(converter.toSql(slots));
      expect(
        () => decoded.removeAt(0),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('fromSql throws on non-list JSON (loud fail)', () {
      // A JSON object (not an array) is malformed input — fromSql
      // should not silently coerce, it should throw.
      expect(
        () => converter.fromSql('{"position":0}'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
