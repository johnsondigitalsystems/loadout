// FILE: lib/screens/devices/device_scan_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Generic BLE scan + connect screen, parameterized by [DeviceScanKind].
// Originally Kestrel-only; now drives the pairing flow for every BLE
// device LoadOut talks to:
//
//   - Kestrel 5xxx Link weather meter
//   - Sig Sauer KILO BDX rangefinder
//   - Bushnell rangefinders (Forge / Prime / Phantom 2 / Engage / Elite)
//   - Vortex Razor HD 4000 / Fury HD AB
//   - Leica Geovid Pro
//   - Vectronix Terrapin X (mil/LE-grade LRF, magnetometer)
//
// The kind enum carries the per-brand service UUID, friendly title, and
// "looks like" matcher used for fallback name-based discovery (some
// firmware advertises the service UUID only in the scan-response, which
// the OS pre-filter would otherwise drop). On selection, the kind also
// owns the connect handler — each adapter has its own ChangeNotifier
// service in the provider tree.
//
// The scan uses an OS-level service-UUID filter for speed, with a name
// fallback in the result-handling code for devices whose firmware lies
// about advertising data. As before, the connection survives this
// screen's teardown — the live GATT subscription lives on the adapter
// service.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/devices/devices_screen.dart — pushes this screen as a
//   fullscreen dialog with a [DeviceScanKind] argument.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Starts a BLE scan (lasts up to 12 seconds or until the user backs
//   out).
// - On selection, opens a GATT connection that survives this screen's
//   teardown.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../../services/ble/ble_service.dart';
import '../../services/ble/bushnell_rangefinder_service.dart';
import '../../services/ble/kestrel_service.dart';
import '../../services/ble/leica_geovid_service.dart';
import '../../services/ble/sig_kilo_service.dart';
import '../../services/ble/vectronix_terrapin_service.dart';
import '../../services/ble/vortex_rangefinder_service.dart';

/// What kind of device this scan-and-connect flow is for. Each kind
/// carries its own service UUID, friendly title, and connect handler.
enum DeviceScanKind {
  kestrel,
  sigKilo,
  bushnell,
  vortex,
  leicaGeovid,
  vectronixTerrapin,
}

extension _DeviceScanKindCopy on DeviceScanKind {
  /// Title shown in the AppBar.
  String get title {
    switch (this) {
      case DeviceScanKind.kestrel:
        return 'Scan for Kestrel';
      case DeviceScanKind.sigKilo:
        return 'Scan for Sig KILO';
      case DeviceScanKind.bushnell:
        return 'Scan for Bushnell';
      case DeviceScanKind.vortex:
        return 'Scan for Vortex';
      case DeviceScanKind.leicaGeovid:
        return 'Scan for Leica';
      case DeviceScanKind.vectronixTerrapin:
        return 'Scan for Vectronix Terrapin';
    }
  }

  /// Empty-state label.
  String get emptyLabel {
    switch (this) {
      case DeviceScanKind.kestrel:
        return 'No Kestrel devices found.';
      case DeviceScanKind.sigKilo:
        return 'No Sig KILO devices found.';
      case DeviceScanKind.bushnell:
        return 'No Bushnell devices found.';
      case DeviceScanKind.vortex:
        return 'No Vortex devices found.';
      case DeviceScanKind.leicaGeovid:
        return 'No Leica devices found.';
      case DeviceScanKind.vectronixTerrapin:
        return 'No Vectronix Terrapin devices found.';
    }
  }

  /// Connected snackbar message.
  String get connectedMessage {
    switch (this) {
      case DeviceScanKind.kestrel:
        return 'Connected to Kestrel.';
      case DeviceScanKind.sigKilo:
        return 'Connected to Sig KILO.';
      case DeviceScanKind.bushnell:
        return 'Connected to Bushnell rangefinder.';
      case DeviceScanKind.vortex:
        return 'Connected to Vortex rangefinder.';
      case DeviceScanKind.leicaGeovid:
        return 'Connected to Leica Geovid.';
      case DeviceScanKind.vectronixTerrapin:
        return 'Connected to Vectronix Terrapin X.';
    }
  }

  /// Service UUIDs to filter on at scan time.
  List<Guid> get scanFilters {
    switch (this) {
      case DeviceScanKind.kestrel:
        return [kKestrelServiceUuid];
      case DeviceScanKind.sigKilo:
        return [kSigKiloServiceUuid];
      case DeviceScanKind.bushnell:
        return [kBushnellPrimaryServiceUuid];
      case DeviceScanKind.vortex:
        return [kVortexServiceUuid];
      case DeviceScanKind.leicaGeovid:
        return [kLeicaGeovidServiceUuid];
      case DeviceScanKind.vectronixTerrapin:
        return [kVectronixTerrapinServiceUuid];
    }
  }

  /// Whether a scan result looks like the kind of device we're hunting.
  bool matches(ScanResult r) {
    switch (this) {
      case DeviceScanKind.kestrel:
        return r.advertisementData.serviceUuids
                .contains(kKestrelServiceUuid) ||
            r.device.platformName.toLowerCase().startsWith('kestrel');
      case DeviceScanKind.sigKilo:
        return SigKiloService.looksLikeKilo(r);
      case DeviceScanKind.bushnell:
        return BushnellRangefinderService.looksLikeBushnell(r);
      case DeviceScanKind.vortex:
        return VortexRangefinderService.looksLikeVortex(r);
      case DeviceScanKind.leicaGeovid:
        return LeicaGeovidService.looksLikeLeica(r);
      case DeviceScanKind.vectronixTerrapin:
        return VectronixTerrapinService.looksLikeTerrapin(r);
    }
  }

  /// Leading icon for each device row.
  IconData get listIcon {
    switch (this) {
      case DeviceScanKind.kestrel:
        return Icons.air;
      case DeviceScanKind.sigKilo:
      case DeviceScanKind.bushnell:
      case DeviceScanKind.vortex:
      case DeviceScanKind.leicaGeovid:
      case DeviceScanKind.vectronixTerrapin:
        return Icons.gps_fixed;
    }
  }

  /// Empty-state hint shown under the spinner.
  String get emptyHint {
    switch (this) {
      case DeviceScanKind.kestrel:
        return 'Make sure the meter is powered on, in pairing mode, and within '
            'about 30 ft of this device.';
      case DeviceScanKind.sigKilo:
        return 'Make sure the KILO is powered on with Bluetooth enabled '
            '(BDX mode), and within about 30 ft of this device.';
      case DeviceScanKind.bushnell:
        return 'Make sure the rangefinder is powered on with Bluetooth '
            'enabled, and within about 30 ft of this device.';
      case DeviceScanKind.vortex:
        return 'Make sure the rangefinder / binocular is powered on with '
            'Bluetooth enabled, and within about 30 ft of this device.';
      case DeviceScanKind.leicaGeovid:
        return 'Make sure the Geovid Pro is powered on with Bluetooth '
            'enabled, and within about 30 ft of this device.';
      case DeviceScanKind.vectronixTerrapin:
        return 'Make sure the Terrapin X is powered on with Bluetooth '
            'enabled, and within about 30 ft of this device.';
    }
  }
}

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key, this.kind = DeviceScanKind.kestrel});

  /// What kind of device this scan is for. Drives filtering, copy, and
  /// the connect handler.
  final DeviceScanKind kind;

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  StreamSubscription<List<ScanResult>>? _sub;
  final Map<String, ScanResult> _seen = {};
  String? _connectingId;
  String? _error;
  bool _scanning = false;

  /// Cached `BleService` reference so [dispose] can call
  /// `stopScan()` without `context.read<>` on a deactivated
  /// element. Captured in [didChangeDependencies] (the standard
  /// safe site for ancestor lookups). Same bug class as the
  /// Range Day sensor cleanup — see `range_day_detail_screen.dart`
  /// for the precedent fix.
  BleService? _cachedBleService;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _startScan();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedBleService = context.read<BleService>();
  }

  Future<void> _startScan() async {
    setState(() {
      _seen.clear();
      _error = null;
      _scanning = true;
    });
    final ble = context.read<BleService>();
    try {
      final stream = await ble.startScan(
        timeout: const Duration(seconds: 12),
        withServices: widget.kind.scanFilters,
      );
      _sub = stream.listen((batch) {
        for (final r in batch) {
          if (widget.kind.matches(r)) {
            _seen[r.device.remoteId.str] = r;
          }
        }
        if (mounted) setState(() {});
      });
      // Auto-stop spinner after the package's timeout fires.
      Future<void>.delayed(const Duration(seconds: 13), () {
        if (mounted) setState(() => _scanning = false);
      });
    } on BleException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.userMessage;
        _scanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Scan failed: $e';
        _scanning = false;
      });
    }
  }

  @override
  void dispose() {
    // ignore: discarded_futures
    _sub?.cancel();
    // Use the cached service ref — `context.read<>` here would
    // throw "Looking up a deactivated widget's ancestor is unsafe".
    // ignore: discarded_futures
    _cachedBleService?.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _seen.values.toList(growable: false)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kind.title),
        actions: [
          if (_scanning)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh),
              tooltip: 'Scan again',
            ),
        ],
      ),
      body: _error != null
          ? _buildError()
          : results.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  itemBuilder: (_, i) => _buildResult(results[i]),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemCount: results.length,
                ),
    );
  }

  Widget _buildError() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              color: theme.colorScheme.error, size: 36),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Scan failed.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            onPressed: _startScan,
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _scanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
            color: theme.colorScheme.onSurfaceVariant,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            _scanning ? 'Scanning…' : widget.kind.emptyLabel,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            widget.kind.emptyHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(ScanResult r) {
    final theme = Theme.of(context);
    final id = r.device.remoteId.str;
    final connecting = _connectingId == id;
    final name = r.device.platformName.trim().isEmpty
        ? id
        : r.device.platformName.trim();
    return ListTile(
      leading: Icon(widget.kind.listIcon),
      title: Text(name),
      subtitle: Text(
        'Signal: ${r.rssi} dBm · $id',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: connecting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: connecting ? null : () => _onPick(r.device),
    );
  }

  Future<void> _onPick(BluetoothDevice device) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ble = context.read<BleService>();
    // Resolve the right adapter UP FRONT — using BuildContext after the
    // `await ble.stopScan()` async gap below would trip the
    // use_build_context_synchronously lint.
    final connectAdapter = _resolveConnect();
    setState(() => _connectingId = device.remoteId.str);
    try {
      await ble.stopScan();
      await connectAdapter(device);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(widget.kind.connectedMessage)),
      );
      navigator.pop();
    } on BleException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
      setState(() => _connectingId = null);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
      setState(() => _connectingId = null);
    }
  }

  /// Bind the connect handler from the right adapter for [widget.kind]
  /// using the current BuildContext, so the resulting closure can be
  /// invoked across an async gap without `context.read` re-entry.
  Future<void> Function(BluetoothDevice) _resolveConnect() {
    switch (widget.kind) {
      case DeviceScanKind.kestrel:
        final svc = context.read<KestrelService>();
        return svc.connect;
      case DeviceScanKind.sigKilo:
        final svc = context.read<SigKiloService>();
        return svc.connect;
      case DeviceScanKind.bushnell:
        final svc = context.read<BushnellRangefinderService>();
        return svc.connect;
      case DeviceScanKind.vortex:
        final svc = context.read<VortexRangefinderService>();
        return svc.connect;
      case DeviceScanKind.leicaGeovid:
        final svc = context.read<LeicaGeovidService>();
        return svc.connect;
      case DeviceScanKind.vectronixTerrapin:
        final svc = context.read<VectronixTerrapinService>();
        return svc.connect;
    }
  }
}
