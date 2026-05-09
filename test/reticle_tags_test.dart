// FILE: test/reticle_tags_test.dart
//
// Unit tests for `lib/data/reticle_tags.dart`. Confirms the tag
// derivation behaves the way the picker expects:
//
//   * Searching "tremor3" matches every Tremor3 reticle regardless
//     of brand (Nightforce TReMoR3, Schmidt & Bender Tremor3).
//   * Searching "horus" surfaces every Horus-licensed reticle
//     (Tremor3, H59, etc.) even when "Horus" doesn't appear in the
//     reticle's name string.
//   * The kPopularReticleTags catalog stays the canonical 10 entries
//     called out in the picker spec.

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/data/reticle_tags.dart';

void main() {
  group('deriveReticleTags', () {
    test('words from manufacturer/model/family land in the tag set', () {
      final tags = deriveReticleTags(
        manufacturer: 'Vortex',
        model: 'EBR-7C MRAD',
        family: 'Razor HD Gen II reticles',
      );
      expect(tags, contains('vortex'));
      expect(tags, contains('ebr'));
      expect(tags, contains('mrad'));
      expect(tags, contains('razor'));
    });

    test('Schmidt & Bender becomes "schmidtbender" and "schmidt" both work', () {
      final tags = deriveReticleTags(
        manufacturer: 'Schmidt & Bender',
        model: 'P4F',
        family: null,
      );
      expect(tags, contains('schmidt'));
      expect(tags, contains('bender'));
      expect(tags, contains('schmidtbender'));
      expect(tags, contains('p4f'));
    });

    test('Tremor3 attaches both "tremor3" and "horus" tags', () {
      final tags = deriveReticleTags(
        manufacturer: 'Nightforce',
        model: 'TReMoR3',
        family: null,
      );
      expect(tags, contains('tremor3'));
      expect(tags, contains('horus'));
    });

    test('H59 attaches "h59" and "horus" tags', () {
      final tags = deriveReticleTags(
        manufacturer: 'Schmidt & Bender',
        model: 'H59',
        family: null,
      );
      expect(tags, contains('h59'));
      expect(tags, contains('horus'));
    });

    test('Mil-Dot variants land in the same "mildot" tag', () {
      final variants = ['Mil-Dot', 'MIL-DOT', 'Mil Dot', 'MIL Dot', 'MilDot'];
      for (final v in variants) {
        final tags =
            deriveReticleTags(manufacturer: 'Generic', model: v, family: null);
        expect(tags, contains('mildot'),
            reason: 'Expected "mildot" in tags for "$v"');
      }
    });
  });

  group('reticleMatchesQuery', () {
    test('"tremor3" matches Tremor3 reticles across brands', () {
      final brands = [
        ('Nightforce', 'TReMoR3'),
        ('Schmidt & Bender', 'Tremor3'),
      ];
      for (final (m, model) in brands) {
        expect(
          reticleMatchesQuery(
            query: 'tremor3',
            manufacturer: m,
            model: model,
            family: null,
          ),
          isTrue,
          reason: '$m $model should match "tremor3"',
        );
      }
    });

    test('"horus" matches Horus-licensed reticles even without Horus in name',
        () {
      // Schmidt & Bender's Tremor3 has no "horus" in the model string.
      expect(
        reticleMatchesQuery(
          query: 'horus',
          manufacturer: 'Schmidt & Bender',
          model: 'Tremor3',
          family: null,
        ),
        isTrue,
      );
      // Nightforce's TReMoR3 likewise.
      expect(
        reticleMatchesQuery(
          query: 'horus',
          manufacturer: 'Nightforce',
          model: 'TReMoR3',
          family: null,
        ),
        isTrue,
      );
      // H59 too — Horus design.
      expect(
        reticleMatchesQuery(
          query: 'horus',
          manufacturer: 'Schmidt & Bender',
          model: 'H59',
          family: null,
        ),
        isTrue,
      );
    });

    test('Empty query matches every reticle', () {
      expect(
        reticleMatchesQuery(
          query: '',
          manufacturer: 'Anyone',
          model: 'Anything',
          family: null,
        ),
        isTrue,
      );
    });

    test('Partial prefix matches a tag', () {
      // "trem" is a prefix of "tremor3" and "tremor"
      expect(
        reticleMatchesQuery(
          query: 'trem',
          manufacturer: 'Nightforce',
          model: 'TReMoR3',
          family: null,
        ),
        isTrue,
      );
    });

    test('Punctuation-stripped variants match', () {
      // Searching "ebr2c" with no hyphen matches "EBR-2C".
      expect(
        reticleMatchesQuery(
          query: 'ebr2c',
          manufacturer: 'Vortex',
          model: 'EBR-2C MRAD',
          family: null,
        ),
        isTrue,
      );
    });

    test('Non-matching query returns false', () {
      expect(
        reticleMatchesQuery(
          query: 'xyznonexistent',
          manufacturer: 'Vortex',
          model: 'EBR-7C MRAD',
          family: null,
        ),
        isFalse,
      );
    });
  });

  group('reticleHasPopularTag', () {
    test('Tremor3 model gets the tremor3 popular tag', () {
      expect(
        reticleHasPopularTag(
          popularTag: 'tremor3',
          manufacturer: 'Nightforce',
          model: 'TReMoR3',
          family: null,
        ),
        isTrue,
      );
    });

    test('A non-Tremor reticle does not match the tremor3 popular tag', () {
      expect(
        reticleHasPopularTag(
          popularTag: 'tremor3',
          manufacturer: 'Vortex',
          model: 'EBR-7C MRAD',
          family: null,
        ),
        isFalse,
      );
    });
  });

  group('kPopularReticleTags', () {
    test('Catalog has 10 entries (the canonical popular reticles)', () {
      expect(kPopularReticleTags.length, 10);
    });

    test('All entries have unique tags', () {
      final tags = kPopularReticleTags.map((e) => e.tag).toSet();
      expect(tags.length, kPopularReticleTags.length);
    });

    test('Catalog covers the spec list (Tremor3, MIL-Dot, EBR, etc.)', () {
      final tags = kPopularReticleTags.map((e) => e.tag).toSet();
      const required = {
        'tremor3',
        'mildot',
        'ebr',
        'gap',
        'scr',
        'h59',
        'msr2',
        'milxt',
      };
      for (final r in required) {
        expect(tags, contains(r),
            reason: 'Popular reticles should include "$r"');
      }
    });
  });
}
