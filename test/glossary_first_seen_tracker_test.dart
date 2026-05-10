// FILE: test/glossary_first_seen_tracker_test.dart
//
// Unit tests for `lib/services/glossary_first_seen_tracker.dart`.
// Pure in-memory ChangeNotifier-style service — no providers, no
// drift, no platform plugins. Verifies the four bits of contract
// the [GlossaryLabel] widget relies on:
//
//   1. A fresh tracker reports nothing as seen.
//   2. `markSeen` records the term.
//   3. `markSeen` is idempotent — calling twice doesn't bump
//      `seenCount`.
//   4. Different terms accumulate independently.
//
// We do NOT test "notifyListeners is not called" because the
// service deliberately avoids notifying — see the file header on
// `GlossaryFirstSeenTracker` for the rationale (a notify would
// rebuild every label currently rendering, which is both wrong
// and a perf hit). Listener wiring is the widget's job.

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/services/glossary_first_seen_tracker.dart';

void main() {
  group('GlossaryFirstSeenTracker', () {
    late GlossaryFirstSeenTracker tracker;

    setUp(() {
      tracker = GlossaryFirstSeenTracker();
    });

    test('reports nothing as seen on construction', () {
      expect(tracker.hasSeen('CBTO'), isFalse);
      expect(tracker.hasSeen('Drop'), isFalse);
      expect(tracker.seenCount, 0);
    });

    test('markSeen records the term', () {
      tracker.markSeen('CBTO');
      expect(tracker.hasSeen('CBTO'), isTrue);
      expect(tracker.hasSeen('Drop'), isFalse);
      expect(tracker.seenCount, 1);
    });

    test('markSeen is idempotent', () {
      tracker.markSeen('Mil');
      tracker.markSeen('Mil');
      tracker.markSeen('Mil');
      expect(tracker.hasSeen('Mil'), isTrue);
      expect(tracker.seenCount, 1);
    });

    test('different terms accumulate independently', () {
      tracker.markSeen('Spin drift');
      tracker.markSeen('Coriolis effect');
      tracker.markSeen('Density altitude');
      expect(tracker.hasSeen('Spin drift'), isTrue);
      expect(tracker.hasSeen('Coriolis effect'), isTrue);
      expect(tracker.hasSeen('Density altitude'), isTrue);
      expect(tracker.hasSeen('Wind drift'), isFalse);
      expect(tracker.seenCount, 3);
    });

    test('term names are case-sensitive (matches glossary entries verbatim)', () {
      // GlossaryLookup.find performs case-insensitive matching, but
      // the tracker stores the canonical-key string the lookup
      // returns — typically the GlossaryTerm's `term` field
      // verbatim. This test pins the case-sensitivity behaviour so
      // a future refactor that lowercases keys is caught here.
      tracker.markSeen('CBTO');
      expect(tracker.hasSeen('CBTO'), isTrue);
      expect(tracker.hasSeen('cbto'), isFalse);
      expect(tracker.hasSeen('Cbto'), isFalse);
    });

    test('empty string is a valid (if useless) term key', () {
      // The tracker doesn't validate keys — it's the caller's job
      // to pass a meaningful glossary term. This test pins the
      // current "no validation" contract so an accidental
      // `markSeen('')` doesn't silently corrupt the seen-count.
      tracker.markSeen('');
      expect(tracker.hasSeen(''), isTrue);
      expect(tracker.seenCount, 1);
    });
  });
}
