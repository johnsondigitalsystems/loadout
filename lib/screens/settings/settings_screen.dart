// FILE: lib/screens/settings/settings_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Top-level Settings directory. Splits what used to be a single flat
// list of switches and tiles into thematic submenus, each of which
// owns the controls relevant to one slice of the app:
//
//   Settings
//   ├─ Account                  ← AccountSettingsScreen
//   │     ├─ Sign in / Sign out
//   │     ├─ Email
//   │     └─ Restore purchases
//   ├─ App preferences          ← AppPreferencesScreen
//   │     ├─ Beginner Mode
//   │     ├─ Auto-save
//   │     ├─ Language
//   │     └─ Units of measurement
//   ├─ Cloud Sync               ← CloudSyncScreen (existing, linked)
//   ├─ Watch & Wear             ← WatchSettingsScreen
//   │     ├─ Connection status
//   │     ├─ Stage timer defaults
//   │     ├─ Glanceable DOPE prefs
//   │     └─ Shot capture sensitivity
//   ├─ Connected Devices        ← DevicesScreen (existing, linked)
//   ├─ AI features              ← AiSettingsScreen
//   ├─ Privacy & Data           ← PrivacyDataScreen
//   │     ├─ Crashlytics opt-in
//   │     ├─ Export my data
//   │     ├─ Delete my data
//   │     └─ Privacy / Terms / Disclaimer
//   └─ Help & Support           ← HelpSupportScreen
//         ├─ Email support
//         ├─ Print sample notebook
//         ├─ Restore from backup
//         └─ About / version
//
// Each tile pushes its own destination screen via a standard
// `MaterialPageRoute`. The system back gesture pops back to this
// directory cleanly.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The old single-list Settings screen was 700+ lines and growing every
// release. Splitting it gives each submenu its own narrow scope, makes
// each easier to test in isolation, and reduces the cognitive load on
// users who used to scroll to find a single switch.
//
// User-facing labels are stable: every label below was the label that
// was on the flat list, so screenshots, support replies, and muscle
// memory all still find the same controls — just one tap deeper.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/home/home_screen.dart — the Home drawer pushes
//   `SettingsScreen()` from the "Settings" tile.
// - The five new submenu files in this directory each receive
//   navigation from this directory.

import 'package:flutter/material.dart';

import '../devices/devices_screen.dart';
import '../sync/cloud_sync_screen.dart';
import 'account_settings_screen.dart';
import 'ai_settings_screen.dart';
import 'app_preferences_screen.dart';
import 'help_support_screen.dart';
import 'privacy_data_screen.dart';
import 'watch_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _CategoryTile(
            icon: Icons.account_circle_outlined,
            title: 'Account',
            subtitle: 'Sign-in, email, restore purchases.',
            destinationBuilder: (_) => const AccountSettingsScreen(),
          ),
          _CategoryTile(
            icon: Icons.tune_outlined,
            title: 'App preferences',
            subtitle: 'Beginner Mode, auto-save, language, units.',
            destinationBuilder: (_) => const AppPreferencesScreen(),
          ),
          _CategoryTile(
            icon: Icons.cloud_sync_outlined,
            title: 'Cloud Sync',
            subtitle:
                'Continuously sync your data to your own iCloud, Google '
                'Drive, or OneDrive. End-to-end encrypted (Pro).',
            destinationBuilder: (_) => const CloudSyncScreen(),
          ),
          _CategoryTile(
            icon: Icons.watch_outlined,
            title: 'Watch & Wear',
            subtitle:
                'Apple Watch / Wear OS connection, shot-capture sensitivity.',
            destinationBuilder: (_) => const WatchSettingsScreen(),
          ),
          _CategoryTile(
            icon: Icons.bluetooth_outlined,
            title: 'Connected Devices',
            subtitle:
                'Pair a Bluetooth chronograph, Kestrel, or rangefinder.',
            destinationBuilder: (_) => const DevicesScreen(),
          ),
          _CategoryTile(
            icon: Icons.auto_awesome_outlined,
            title: 'AI features',
            subtitle:
                'Optional AI assist for messy handwriting in Smart Import.',
            destinationBuilder: (_) => const AiSettingsScreen(),
          ),
          _CategoryTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy & Data',
            subtitle:
                'Crashlytics, export, delete, privacy policy / disclaimer.',
            destinationBuilder: (_) => const PrivacyDataScreen(),
          ),
          _CategoryTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle:
                'Email support, print notebook page, restore backup.',
            destinationBuilder: (_) => const HelpSupportScreen(),
          ),
        ],
      ),
    );
  }
}

/// Re-usable directory row. Renders an icon, title, subtitle, and
/// trailing chevron so every tile looks identical.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.destinationBuilder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder destinationBuilder;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: destinationBuilder),
        );
      },
    );
  }
}
