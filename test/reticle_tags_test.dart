// FILE: test/reticle_tags_test.dart
//
// Unit tests for `lib/data/reticle_tags.dart`. Confirms the tag
// derivation behaves the way the picker expects:
//
//   * Searching "dense" matches every dense LoadOut mil tree
//     archetype (`loadout_mil_tree_dense`,
//     `loadout_mil_tree_christmas`).
//   * Searching "compact" matches the compact archetypes.
//   * The kPopularReticleTags catalog stays the canonical set of
//     archetype categories called out in the picker spec.

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/data/reticle_tags.dart';

void main() {
  group('deriveReticleTags', () {
    test('words from manufacturer/model/family land in the tag set', () {
      final tags = deriveReticleTags(
        manufacturer: 'LoadOut',
        model: 'Mil Tree - Compact',
        family: 'LoadOut Mil reticles',
      );
      expect(tags, contains('loadout'));
      expect(tags, contains('mil'));
      expect(tags, contains('tree'));
      expect(tags, contains('compact'));
    });

    test('Public domain becomes "publicdomain" and "public" both work', () {
      final tags = deriveReticleTags(
        manufacturer: 'Public domain',
        model: 'Plex',
        family: 'Public-domain reticles',
      );
      expect(tags, contains('public'));
      expect(tags, contains('domain'));
      expect(tags, contains('publicdomain'));
      expect(tags, contains('plex'));
    });

    test('Christmas Tree archetype gets both christmas-tree and dense tags',
        () {
      final tags = deriveReticleTags(
        manufacturer: 'LoadOut',
        model: 'Mil Tree - Christmas Tree',
        family: 'LoadOut Mil reticles',
      );
      expect(tags, contains('christmas-tree'));
      expect(tags, contains('dense-mil-tree'));
    });

    test('Mil-Dot variants land in the same "mil-dot" tag', () {
      final variants = ['Mil-Dot', 'MIL-DOT', 'Mil Dot', 'MIL Dot', 'MilDot'];
      for (final v in variants) {
        final tags = deriveReticleTags(
          manufacturer: 'Public domain',
          model: v,
          family: null,
        );
        expect(tags, contains('mil-dot'),
            reason: 'Expected "mil-dot" in tags for "$v"');
      }
    });
  });

  group('reticleMatchesQuery', () {
    test('"dense" matches dense archetypes', () {
      final brands = [
        ('LoadOut', 'Mil Tree - Dense'),
        ('LoadOut', 'MOA Tree - Dense'),
      ];
      for (final (m, model) in brands) {
        expect(
          reticleMatchesQuery(
            query: 'dense',
            manufacturer: m,
            model: model,
            family: null,
          ),
          isTrue,
          reason: '$m $model should match "dense"',
        );
      }
    });

    test('"christmas" matches the Christmas-tree archetypes', () {
      expect(
        reticleMatchesQuery(
          query: 'christmas',
          manufacturer: 'LoadOut',
          model: 'Mil Tree - Christmas Tree',
          family: 'LoadOut Mil reticles',
        ),
        isTrue,
      );
      expect(
        reticleMatchesQuery(
          query: 'christmas',
          manufacturer: 'LoadOut',
          model: 'MOA Tree - Christmas Tree',
          family: 'LoadOut MOA reticles',
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
      // "tre" is a prefix of "tree" and "trees"
      expect(
        reticleMatchesQuery(
          query: 'tre',
          manufacturer: 'LoadOut',
          model: 'Mil Tree - Compact',
          family: null,
        ),
        isTrue,
      );
    });

    test('Punctuation-stripped variants match', () {
      // Searching "miltree" with no spaces matches "Mil Tree".
      expect(
        reticleMatchesQuery(
          query: 'miltree',
          manufacturer: 'LoadOut',
          model: 'Mil Tree - Compact',
          family: null,
        ),
        isTrue,
      );
    });

    test('Non-matching query returns false', () {
      expect(
        reticleMatchesQuery(
          query: 'xyznonexistent',
          manufacturer: 'LoadOut',
          model: 'Mil Tree - Compact',
          family: null,
        ),
        isFalse,
      );
    });
  });

  group('reticleHasPopularTag', () {
    test('Christmas Tree model gets the christmas-tree popular tag', () {
      expect(
        reticleHasPopularTag(
          popularTag: 'christmas-tree',
          manufacturer: 'LoadOut',
          model: 'Mil Tree - Christmas Tree',
          family: null,
        ),
        isTrue,
      );
    });

    test('Compact archetype does not match the dense-mil-tree popular tag',
        () {
      expect(
        reticleHasPopularTag(
          popularTag: 'dense-mil-tree',
          manufacturer: 'LoadOut',
          model: 'Mil Tree - Compact',
          family: null,
        ),
        isFalse,
      );
    });
  });

  group('kPopularReticleTags', () {
    test('Catalog has the canonical set of popular entries', () {
      expect(kPopularReticleTags.length, greaterThanOrEqualTo(10));
    });

    test('All entries have unique tags', () {
      final tags = kPopularReticleTags.map((e) => e.tag).toSet();
      expect(tags.length, kPopularReticleTags.length);
    });

    test('Catalog covers the LoadOut archetype categories', () {
      final tags = kPopularReticleTags.map((e) => e.tag).toSet();
      const required = {
        'dense-mil-tree',
        'christmas-tree',
        'medium-mil',
        'compact-mil',
        'mil-hash',
        'mil-dot',
        'bdc',
        'combat',
        'red-dot',
        'holographic',
      };
      for (final r in required) {
        expect(tags, contains(r),
            reason: 'Popular reticles should include "$r"');
      }
    });
  });
}
