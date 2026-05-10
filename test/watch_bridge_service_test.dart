// FILE: test/watch_bridge_service_test.dart
//
// Verifies the [WatchBridgeService] envelope contract — every typed
// `send*` method packs the right reserved path + payload into the
// outgoing `send` MethodCall, and incoming events from the platform
// land on the right stream.
//
// The test uses [TestDefaultBinaryMessengerBinding.defaultBinaryMessenger]
// to intercept the MethodChannel calls that the service makes, plus a
// helper that fires fake EventChannel events into the stream.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/models/watch_payloads.dart';
import 'package:loadout/services/watch_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Capture every MethodCall the service emits on
  // `loadout/watch_bridge`. The fake handler records the call and
  // returns the canned response declared by `_pendingMethodResponses`.
  final methodCalls = <MethodCall>[];
  final pendingResponses = <String, Object?>{};
  const methodChannel = MethodChannel('loadout/watch_bridge');
  const eventChannel = EventChannel('loadout/watch_bridge/events');

  setUp(() {
    methodCalls.clear();
    pendingResponses.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      methodCalls.add(call);
      return pendingResponses[call.method];
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  // The bridge probes platform support via `Platform.is*`; in unit
  // tests we override that flag to `true` so the channel calls
  // actually fire.
  WatchBridgeService newBridge() => WatchBridgeService(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
        isSupportedOverride: true,
      );

  group('WatchBridgeService', () {
    test('sendActiveLoad packs ActiveLoadSnapshot under the active_load path',
        () async {
      final bridge = newBridge();
      const snap = ActiveLoadSnapshot(
        name: 'PRS Match Load',
        cartridgeName: '6.5 Creedmoor',
        powderName: 'H4350',
        powderChargeGr: 41.5,
        bulletName: '140 ELD-M',
        bulletWeightGr: 140,
        primer: 'CCI 200',
        brass: 'Lapua',
        coalIn: 2.825,
        cbtoIn: 2.255,
      );

      await bridge.sendActiveLoad(snap);

      // Filter to the `send` calls — the constructor also fires
      // `isWatchPaired` / `isWatchAppInstalled` / `isReachable` probes.
      final sendCalls =
          methodCalls.where((c) => c.method == 'send').toList(growable: false);
      expect(sendCalls, hasLength(1));
      final args = Map<String, Object?>.from(
        sendCalls.first.arguments as Map<dynamic, dynamic>,
      );
      expect(args['path'], WatchPaths.activeLoad);
      expect(args['lossy'], true);
      final payload = Map<String, Object?>.from(
        args['payload'] as Map<dynamic, dynamic>,
      );
      expect(payload['n'], 'PRS Match Load');
      expect(payload['cart'], '6.5 Creedmoor');
      expect(payload['p'], 'H4350');
      expect(payload['pgr'], 41.5);
      expect(payload['b'], '140 ELD-M');
    });

    test('sendDope packs DopeSnapshot under the dope path', () async {
      final bridge = newBridge();
      final rows = <DopeRow>[
        const DopeRow(
          rangeYd: 600,
          dropMil: 5.4,
          windMil: 0.8,
          velocityFps: 1780,
          timeOfFlightSec: 0.92,
        ),
      ];
      final snap = DopeSnapshot(
        cartridgeName: '6.5 CM',
        bulletGr: 140,
        bulletName: 'ELD-M',
        muzzleVelocityFps: 2700,
        zeroRangeYd: 100,
        windSpeedMph: 8,
        windFromDeg: 270,
        dragModel: 'g7',
        bc: 0.315,
        rows: rows,
        generatedAtMs: 1730000000000,
      );

      await bridge.sendDope(snap);

      final sendCalls =
          methodCalls.where((c) => c.method == 'send').toList(growable: false);
      expect(sendCalls, hasLength(1));
      final args = Map<String, Object?>.from(
        sendCalls.first.arguments as Map<dynamic, dynamic>,
      );
      expect(args['path'], WatchPaths.dope);
      expect(args['lossy'], true);
      final payload = Map<String, Object?>.from(
        args['payload'] as Map<dynamic, dynamic>,
      );
      expect(payload['cart'], '6.5 CM');
      // single-letter row keys preserved through the channel envelope
      final rowsJson = payload['rows'] as List<dynamic>;
      expect(rowsJson, hasLength(1));
      expect(
        Map<String, Object?>.from(rowsJson.first as Map<dynamic, dynamic>),
        containsPair('r', 600),
      );
    });

    test('sendFirearmGlance packs FirearmGlanceSnapshot under firearm_glance',
        () async {
      final bridge = newBridge();
      const glance = FirearmGlanceSnapshot(
        name: 'Tikka T3x CTR',
        shotsFired: 1234,
        caliber: '6.5 Creedmoor',
      );

      await bridge.sendFirearmGlance(glance);

      final sendCalls =
          methodCalls.where((c) => c.method == 'send').toList(growable: false);
      expect(sendCalls, hasLength(1));
      final args = Map<String, Object?>.from(
        sendCalls.first.arguments as Map<dynamic, dynamic>,
      );
      expect(args['path'], WatchPaths.firearmGlance);
      expect(args['lossy'], true);
      final payload = Map<String, Object?>.from(
        args['payload'] as Map<dynamic, dynamic>,
      );
      expect(payload['n'], 'Tikka T3x CTR');
      expect(payload['s'], 1234);
      expect(payload['c'], '6.5 Creedmoor');
    });

    test('sendTimerEvent packs TimerEvent under timer_event (non-lossy)',
        () async {
      final bridge = newBridge();
      const event = TimerEvent(
        kind: 'start',
        atMsSinceEpoch: 1730000000000,
        totalSec: 120,
      );

      await bridge.sendTimerEvent(event);

      final sendCalls =
          methodCalls.where((c) => c.method == 'send').toList(growable: false);
      expect(sendCalls, hasLength(1));
      final args = Map<String, Object?>.from(
        sendCalls.first.arguments as Map<dynamic, dynamic>,
      );
      expect(args['path'], WatchPaths.timerEvent);
      expect(
        args['lossy'],
        false,
        reason: 'timer events must not be coalesced',
      );
      final payload = Map<String, Object?>.from(
        args['payload'] as Map<dynamic, dynamic>,
      );
      expect(payload['k'], 'start');
      expect(payload['tot'], 120);
    });

    test(
        'send is a silent no-op when the bridge probe says the platform is '
        'unsupported', () async {
      final bridge = WatchBridgeService(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
        isSupportedOverride: false,
      );
      const snap = ActiveLoadSnapshot(name: 'Foo', cartridgeName: 'Bar');
      await bridge.sendActiveLoad(snap);
      final sendCalls =
          methodCalls.where((c) => c.method == 'send').toList(growable: false);
      expect(sendCalls, isEmpty);
    });

    test(
        'oversized DopeSnapshot is dropped silently rather than blowing the '
        '16 KiB transport budget', () async {
      final bridge = newBridge();
      // Build a payload way past the 16 KiB cap (10K rows × ~50 bytes).
      final rows = <DopeRow>[
        for (var i = 0; i < 10000; i++)
          DopeRow(
            rangeYd: i,
            dropMil: 5.4,
            windMil: 0.8,
            velocityFps: 1780,
            timeOfFlightSec: 0.92,
          ),
      ];
      final snap = DopeSnapshot(
        cartridgeName: '6.5 CM',
        bulletGr: 140,
        bulletName: 'ELD-M',
        muzzleVelocityFps: 2700,
        zeroRangeYd: 100,
        windSpeedMph: 8,
        windFromDeg: 270,
        dragModel: 'g7',
        bc: 0.315,
        rows: rows,
        generatedAtMs: 1730000000000,
      );
      expect(snap.jsonByteSize, greaterThan(16 * 1024));

      await bridge.sendDope(snap);

      // No `send` call should fire — the payload is dropped silently.
      final sendCalls =
          methodCalls.where((c) => c.method == 'send').toList(growable: false);
      expect(sendCalls, isEmpty);
    });
  });
}
