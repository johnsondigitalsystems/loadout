// FILE: lib/screens/devices/devices_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// "Connected Devices" — single-stop UI for pairing every piece of gear
// LoadOut talks to over Bluetooth:
//
//   - Garmin Xero C1 Pro chronograph (.fit import + future BLE)
//   - Kestrel 5xxx Link weather meter (BLE live data)
//   - Sig Sauer KILO BDX rangefinder (BLE range push)
//   - Bushnell rangefinders (BLE range push, scan-and-display only)
//   - Vortex Razor HD 4000 / Fury HD AB (BLE range push)
//   - Leica Geovid Pro (BLE range push)
//
// Reached from Settings → Devices.
//
// Tile structure:
//   1. Bluetooth status banner. Surfaces "Bluetooth is off" / "Not
//      available on this device" when the radio isn't usable.
//   2. Chronograph section: Garmin Xero card.
//   3. Weather Meter section: Kestrel card.
//   4. Rangefinders section: one card per supported brand. Each card
//      shows the connection state, a Scan button (Pro-gated), and a
//      BETA badge so the user knows we expect to iterate. The same
//      DeviceScanScreen handles all four — it's parameterized by
//      DeviceScanKind.
//   5. System: deep-link to OS bluetooth permissions.
//
// Live BLE pairing is Pro-gated; manual entry stays free across the
// app (the distance picker on Range Day still accepts typed values).
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/settings/settings_screen.dart — pushes this screen.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Pushes the [DeviceScanScreen] modal which starts a BLE scan.
// - Calls into the platform `app_settings` deep-link.
// - Opens the OS file picker for the .fit import.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../../services/ble/ble_service.dart';
import '../../services/ble/bushnell_rangefinder_service.dart';
import '../../services/ble/garmin_xero_service.dart';
import '../../services/ble/kestrel_service.dart';
import '../../services/ble/leica_geovid_service.dart';
import '../../services/ble/rangefinder_reading.dart';
import '../../services/ble/sig_kilo_service.dart';
import '../../services/ble/vortex_rangefinder_service.dart';
import '../../widgets/pro_gate.dart';
import 'device_scan_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  bool _bleAvailable = true;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _checkBleAvailability();
  }

  Future<void> _checkBleAvailability() async {
    final available = await context.read<BleService>().isAvailable();
    if (!mounted) return;
    setState(() => _bleAvailable = available);
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final kestrel = context.watch<KestrelService>();
    final sigKilo = context.watch<SigKiloService>();
    final bushnell = context.watch<BushnellRangefinderService>();
    final vortex = context.watch<VortexRangefinderService>();
    final leica = context.watch<LeicaGeovidService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Connected Devices')),
      body: ListView(
        children: [
          if (!_bleAvailable) _bleUnavailableBanner(),
          if (_bleAvailable && !ble.isAdapterOn) _bluetoothOffBanner(ble),
          const _SectionHeader('Chronograph'),
          _GarminXeroCard(),
          const SizedBox(height: 8),
          const _SectionHeader('Weather Meter'),
          _KestrelCard(kestrel: kestrel),
          const SizedBox(height: 8),
          const _SectionHeader('Rangefinders'),
          _RangefinderCard(
            kind: DeviceScanKind.sigKilo,
            title: 'Sig Sauer KILO BDX',
            subtitle:
                'KILO1600BDX / 2200BDX / 2400BDX / 3000BDX / 5K / 6K / 8K-ABS / 10K-ABS HD',
            device: sigKilo.device,
            lastReading: sigKilo.lastReading,
            onDisconnect: () => sigKilo.disconnect(),
          ),
          _RangefinderCard(
            kind: DeviceScanKind.bushnell,
            title: 'Bushnell',
            subtitle:
                'Elite 1 Mile · Forge · Prime · Phantom 2 · Engage / Engage X',
            device: bushnell.device,
            lastReading: bushnell.lastReading,
            onDisconnect: () => bushnell.disconnect(),
            footer: 'Scan-and-display only. The device pushes a value '
                'each time you fire the laser.',
          ),
          _RangefinderCard(
            kind: DeviceScanKind.vortex,
            title: 'Vortex Razor HD 4000 / Fury HD AB',
            subtitle: 'Razor HD 4000 · Razor HD 4000 GB · Fury HD 5000 AB',
            device: vortex.device,
            lastReading: vortex.lastReading,
            onDisconnect: () => vortex.disconnect(),
            footer: 'Scan-and-display only. The device pushes a value '
                'each time you fire the laser.',
          ),
          _RangefinderCard(
            kind: DeviceScanKind.leicaGeovid,
            title: 'Leica Geovid Pro',
            subtitle: 'Geovid Pro 32 · Geovid Pro 42 · Geovid Pro AB+ · Rangemaster CRF Pro',
            device: leica.device,
            lastReading: leica.lastReading,
            onDisconnect: () => leica.disconnect(),
            footer: 'Scan-and-display only. The device pushes a value '
                'each time you fire the laser.',
          ),
          const SizedBox(height: 16),
          const _SectionHeader('System'),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Manage permissions'),
            subtitle: const Text(
              'Open the OS settings to grant or revoke Bluetooth permission.',
            ),
            onTap: () async {
              await context.read<BleService>().openAppSettingsPage();
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _bleUnavailableBanner() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth_disabled,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bluetooth is not available on this device. '
              'You can still import a Garmin .fit file below.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bluetoothOffBanner(BleService ble) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth_disabled, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bluetooth is turned off. Turn it on in Settings to scan '
              'for devices.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () async {
              await ble.openAppSettingsPage();
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Garmin Xero ───────────────────────

class _GarminXeroCard extends StatefulWidget {
  @override
  State<_GarminXeroCard> createState() => _GarminXeroCardState();
}

class _GarminXeroCardState extends State<_GarminXeroCard> {
  bool _importing = false;
  GarminXeroSession? _lastSession;
  String? _lastSessionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = _lastSession;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Garmin Xero C1 Pro',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        session == null
                            ? 'Status: Not paired'
                            : 'Imported · ${session.shots.length} shots, '
                                'avg ${session.averageFps.toStringAsFixed(0)} fps',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.bluetooth, size: 18),
                  onPressed: _onPlaceholderPair,
                  label: const Text('Pair via Bluetooth'),
                ),
                FilledButton.icon(
                  icon: _importing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_open_outlined, size: 18),
                  onPressed: _importing ? null : _onImportFit,
                  label: const Text('Import .fit file'),
                ),
              ],
            ),
            if (_lastSessionLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                _lastSessionLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Live BLE pairing is coming soon. For now, export a session '
              'to .fit from the Garmin Connect app and import it here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPlaceholderPair() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Live Garmin Xero pairing is coming soon. Use Import .fit for now.',
        ),
      ),
    );
  }

  Future<void> _onImportFit() async {
    if (!await ensurePro(context)) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ble = context.read<BleService>();
    setState(() => _importing = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['fit'],
        withData: false,
      );
      if (picked == null || picked.files.isEmpty) return;
      final path = picked.files.single.path;
      if (path == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't read the selected file.")),
        );
        return;
      }
      final svc = GarminXeroService(ble);
      final session = await svc.importFitFile(path);
      if (!mounted) return;
      setState(() {
        _lastSession = session;
        _lastSessionLabel =
            'Loaded ${session.shots.length} shots · avg '
            '${session.averageFps.toStringAsFixed(0)} fps · '
            'ES ${session.extremeSpreadFps.toStringAsFixed(0)} · '
            'SD ${session.standardDeviationFps.toStringAsFixed(1)}';
      });
      messenger.showSnackBar(
        SnackBar(
          content:
              Text('Loaded ${session.shots.length} shots from .fit file.'),
        ),
      );
    } on GarminXeroParseException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't import that file: $e")),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}

// ─────────────────────── Kestrel ───────────────────────

class _KestrelCard extends StatelessWidget {
  const _KestrelCard({required this.kestrel});

  final KestrelService kestrel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = kestrel.device;
    final reading = kestrel.lastReading;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.air, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Kestrel 5xxx Link',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const _BetaBadge(),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        device == null
                            ? 'Status: Not connected'
                            : 'Connected · ${_friendlyName(device)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (device == null)
                  FilledButton.icon(
                    icon: const Icon(Icons.search, size: 18),
                    onPressed: () => _onScan(context),
                    label: const Text('Scan for devices'),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.bluetooth_disabled, size: 18),
                    onPressed: () => _onDisconnect(context),
                    label: const Text('Disconnect'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (reading != null)
              Text(
                'Last reading: '
                '${reading.tempF.toStringAsFixed(1)}°F · '
                '${reading.stationPressureInHg.toStringAsFixed(2)} inHg · '
                '${reading.humidityPct.toStringAsFixed(0)}% RH · '
                'Wind ${reading.windSpeedMph.toStringAsFixed(1)} mph '
                'from ${reading.windDirectionDeg.toStringAsFixed(0)}°',
                style: theme.textTheme.bodySmall,
              )
            else
              Text(
                'Last reading: —',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Beta — feedback welcome. Verified Kestrel UUIDs require a real '
              'meter for end-to-end testing; if readings look off, email '
              'support so we can iterate.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onScan(BuildContext context) async {
    if (!await ensurePro(context)) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DeviceScanScreen(kind: DeviceScanKind.kestrel),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _onDisconnect(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await context.read<KestrelService>().disconnect();
    messenger.showSnackBar(
      const SnackBar(content: Text('Disconnected from Kestrel.')),
    );
  }

  String _friendlyName(BluetoothDevice d) {
    final n = d.platformName.trim();
    if (n.isNotEmpty) return n;
    return d.remoteId.str;
  }
}

// ─────────────────────── Generic rangefinder card ───────────────────────

/// One card per supported rangefinder brand. Driven by [DeviceScanKind]
/// so we don't repeat the same UI four times.
class _RangefinderCard extends StatelessWidget {
  const _RangefinderCard({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.device,
    required this.lastReading,
    required this.onDisconnect,
    this.footer,
  });

  final DeviceScanKind kind;
  final String title;
  final String subtitle;
  final BluetoothDevice? device;
  final RangefinderReading? lastReading;
  final Future<void> Function() onDisconnect;
  /// Optional small italic footer copy below the buttons. Falls back to
  /// the standard "Beta — feedback welcome" line.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gps_fixed, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const _BetaBadge(),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        device == null
                            ? 'Status: Not connected'
                            : 'Connected · ${_friendlyName(device!)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (device == null)
                  FilledButton.icon(
                    icon: const Icon(Icons.search, size: 18),
                    onPressed: () => _onScan(context),
                    label: const Text('Scan'),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.bluetooth_disabled, size: 18),
                    onPressed: () => _onDisconnect(context),
                    label: const Text('Disconnect'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (lastReading != null)
              Text(
                _formatReading(lastReading!),
                style: theme.textTheme.bodySmall,
              )
            else
              Text(
                'Last reading: —',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              footer ??
                  'Beta — feedback welcome. The protocol UUIDs are best-effort '
                      'and need real-device validation; if readings look off, '
                      'email support so we can iterate.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatReading(RangefinderReading r) {
    final yd = r.rangeYd.toStringAsFixed(0);
    final m = r.rangeM.toStringAsFixed(0);
    final pieces = <String>['Last range: $yd yd ($m m)'];
    if (r.angleDeg != null) {
      pieces.add('angle ${r.angleDeg!.toStringAsFixed(1)}°');
    }
    if (r.inclineCorrectedRangeYd != null) {
      pieces.add(
          'shoot-to ${r.inclineCorrectedRangeYd!.toStringAsFixed(0)} yd');
    }
    return pieces.join(' · ');
  }

  Future<void> _onScan(BuildContext context) async {
    if (!await ensurePro(context)) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceScanScreen(kind: kind),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _onDisconnect(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await onDisconnect();
    messenger.showSnackBar(
      SnackBar(content: Text('Disconnected from $title.')),
    );
  }

  String _friendlyName(BluetoothDevice d) {
    final n = d.platformName.trim();
    if (n.isNotEmpty) return n;
    return d.remoteId.str;
  }
}

class _BetaBadge extends StatelessWidget {
  const _BetaBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'BETA',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
