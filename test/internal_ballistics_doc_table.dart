// ignore_for_file: avoid_print
//
// FILE: test/internal_ballistics_doc_table.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Generator script — prints the validation table as Markdown so it can
// be pasted into `docs/internal_ballistics_validation.md` verbatim.
// Reads the same `kValidationAnchors` list that
// `internal_ballistics_test.dart` uses, runs `predictLoad(...)` on each,
// and prints per-row deltas plus per-family / per-powder / per-weight
// aggregate statistics.
//
// File ends in `_doc_table.dart` rather than `_test.dart` so the
// default `flutter test` glob does NOT pick it up. Run explicitly:
//
//   flutter test test/internal_ballistics_doc_table.dart
//
// then copy the printed Markdown into the doc.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The validation document needs to stay in sync with the test data —
// a developer who adds a new anchor should regenerate the doc table
// rather than edit it by hand. This script is the single source of
// truth for the per-row predictions in the doc.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// The Flutter test runner, when run explicitly. Anyone updating
// `docs/internal_ballistics_validation.md`.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// stdout: prints Markdown.

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/ballistics/internal_ballistics.dart';

import 'internal_ballistics_test.dart' show kValidationAnchors;

void main() {
  test('PRINT VALIDATION TABLE for the doc', () {
    print('\n## Full Validation Table\n');
    print(
        '| Cartridge | Bullet | Powder | Charge gr | Pub MV | Pred MV | Δ% MV | Pub P | Pred P | Δ% P | Family | Source |');
    print(
        '|---|---|---|---|---|---|---|---|---|---|---|---|');
    final mvErrors = <double>[];
    final pErrors = <double>[];
    final familyMv = <String, List<double>>{};
    final familyP = <String, List<double>>{};
    final powderMv = <String, List<double>>{};
    final powderP = <String, List<double>>{};
    final weightMv = <String, List<double>>{};
    final weightP = <String, List<double>>{};

    for (final a in kValidationAnchors) {
      final r = predictLoad(a.toInput());
      if (r == null) {
        print('| ${a.cartridge} | ${a.bullet} | ${a.powder} | '
            '${a.chargeWeightGr.toStringAsFixed(1)} | '
            '${a.publishedMvFps.toStringAsFixed(0)} | NULL | — | '
            '${a.publishedPressurePsi.toStringAsFixed(0)} | NULL | — | '
            '${a.cartridgeFamily} | ${a.source} |');
        continue;
      }
      final mvD = (r.predictedMuzzleVelocityFps - a.publishedMvFps) /
          a.publishedMvFps *
          100;
      final pD = (r.predictedPeakPressurePsi - a.publishedPressurePsi) /
          a.publishedPressurePsi *
          100;
      mvErrors.add(mvD);
      pErrors.add(pD);
      familyMv.putIfAbsent(a.cartridgeFamily, () => []).add(mvD);
      familyP.putIfAbsent(a.cartridgeFamily, () => []).add(pD);
      powderMv.putIfAbsent(a.powderBurnBand, () => []).add(mvD);
      powderP.putIfAbsent(a.powderBurnBand, () => []).add(pD);
      weightMv.putIfAbsent(a.bulletWeightClass, () => []).add(mvD);
      weightP.putIfAbsent(a.bulletWeightClass, () => []).add(pD);
      print('| ${a.cartridge} | ${a.bullet} | ${a.powder} | '
          '${a.chargeWeightGr.toStringAsFixed(1)} | '
          '${a.publishedMvFps.toStringAsFixed(0)} | '
          '${r.predictedMuzzleVelocityFps.toStringAsFixed(0)} | '
          '${_signed(mvD)} | '
          '${a.publishedPressurePsi.toStringAsFixed(0)} | '
          '${r.predictedPeakPressurePsi.toStringAsFixed(0)} | '
          '${_signed(pD)} | ${a.cartridgeFamily} | ${a.source} |');
    }

    print('\n## Per-Family Aggregate Error\n');
    print('| Family | n | MV bias | MV MAE | MV p95 | P bias | P MAE | P p95 |');
    print('|---|---|---|---|---|---|---|---|');
    final familyKeys = familyMv.keys.toList()..sort();
    for (final k in familyKeys) {
      _printAggRow(k, familyMv[k]!, familyP[k]!);
    }

    print('\n## Per-Powder-Band Aggregate Error\n');
    print('| Burn band | n | MV bias | MV MAE | MV p95 | P bias | P MAE | P p95 |');
    print('|---|---|---|---|---|---|---|---|');
    final powderKeys = powderMv.keys.toList()..sort();
    for (final k in powderKeys) {
      _printAggRow(k, powderMv[k]!, powderP[k]!);
    }

    print('\n## Per-Bullet-Weight Aggregate Error\n');
    print('| Class | n | MV bias | MV MAE | MV p95 | P bias | P MAE | P p95 |');
    print('|---|---|---|---|---|---|---|---|');
    final weightKeys = weightMv.keys.toList()..sort();
    for (final k in weightKeys) {
      _printAggRow(k, weightMv[k]!, weightP[k]!);
    }

    print('\n## Overall Aggregate (n=${mvErrors.length})\n');
    _printAggRow('overall', mvErrors, pErrors);

    // Mid-rifle aggregate (rifle_small + rifle_medium combined),
    // matches the assertion in `internal_ballistics_test.dart`.
    final midMv = <double>[];
    final midP = <double>[];
    midMv.addAll(familyMv['rifle_small'] ?? const []);
    midMv.addAll(familyMv['rifle_medium'] ?? const []);
    midP.addAll(familyP['rifle_small'] ?? const []);
    midP.addAll(familyP['rifle_medium'] ?? const []);
    print('\n## Mid-rifle Aggregate (rifle_small + rifle_medium)\n');
    _printAggRow('mid-rifle', midMv, midP);
  });
}

String _signed(double v) {
  final s = v.toStringAsFixed(1);
  return v >= 0 ? '+$s%' : '$s%';
}

void _printAggRow(String label, List<double> mv, List<double> p) {
  if (mv.isEmpty) {
    print('| $label | 0 | — | — | — | — | — | — |');
    return;
  }
  final mvMean = mv.reduce((a, b) => a + b) / mv.length;
  final mvAbs = mv.map((e) => e.abs()).toList()..sort();
  final pMean = p.reduce((a, b) => a + b) / p.length;
  final pAbs = p.map((e) => e.abs()).toList()..sort();
  final mvMae = mvAbs.reduce((a, b) => a + b) / mvAbs.length;
  final pMae = pAbs.reduce((a, b) => a + b) / pAbs.length;
  final mvP95 =
      mvAbs[(mvAbs.length * 0.95).floor().clamp(0, mvAbs.length - 1)];
  final pP95 =
      pAbs[(pAbs.length * 0.95).floor().clamp(0, pAbs.length - 1)];
  print(
      '| $label | ${mv.length} | ${_signed(mvMean)} | ${mvMae.toStringAsFixed(1)}% | '
      '${mvP95.toStringAsFixed(1)}% | ${_signed(pMean)} | ${pMae.toStringAsFixed(1)}% | '
      '${pP95.toStringAsFixed(1)}% |');
}
