// FILE: lib/screens/settings/app_preferences_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Settings → App preferences submenu. Hosts the four shipping
// preferences that affect day-to-day editing experience:
//   * Beginner Mode toggle
//   * Auto-save toggle
//   * Language picker
//   * Units of Measurement (master + per-category)
//
// Each row is the same widget that previously lived on the flat Settings
// screen — moved here verbatim so muscle-memory taps still find the
// same controls.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// "App preferences" is the natural home for cross-cutting toggles that
// affect every form / screen. The user expects to find Beginner Mode,
// units, and language together — bundling them into one submenu lets us
// keep the top-level Settings page short.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/auto_save_service.dart';
import '../../services/beginner_mode_service.dart';
import '../../services/locale_service.dart';
import '../../services/unit_service.dart';
import '../atmosphere/atmosphere_presets_screen.dart';

class AppPreferencesScreen extends StatelessWidget {
  const AppPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final autoSave = context.watch<AutoSaveService>();
    final beginner = context.watch<BeginnerModeService>();
    final units = context.watch<UnitService>();
    final localeService = context.watch<LocaleService>();
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: const Text('App preferences')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.school_outlined),
            title: const Text('Beginner Mode'),
            subtitle: const Text(
              'Keeps the recipe form simple, shows extra hints, and '
              'starts you in the Quick Add screen. Turn off when you '
              'want every field at your fingertips.',
            ),
            value: beginner.isEnabled,
            onChanged: (v) {
              // ignore: discarded_futures
              beginner.setEnabled(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.bolt_outlined),
            title: const Text('Auto-save forms'),
            subtitle: const Text(
              'Your edits save automatically as you type, so you never have '
              'to scroll to a save button. Turn off if you prefer manual '
              'saves while experimenting.',
            ),
            value: autoSave.isEnabled,
            onChanged: (v) {
              // ignore: discarded_futures
              autoSave.setEnabled(v);
            },
          ),
          // Language picker.
          _LanguageTile(
            localeService: localeService,
            title: l.settingsLanguage,
            subtitle: l.settingsLanguageSubtitle,
            systemDefaultLabel: l.settingsLanguageSystem,
          ),
          // Atmosphere presets (v17). Shortcut to the Manage Presets
          // screen so users who don't go through the inline picker can
          // still find the library.
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Atmosphere presets'),
            subtitle: const Text(
              'Save and reuse named atmosphere conditions (e.g. "Camp '
              'Atterbury summer", "Big Sandy") on Ballistics and Range Day.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AtmospherePresetsScreen(),
              ),
            ),
          ),
          const _SectionHeader('Units of Measurement'),
          _UnitsSection(units: units),
        ],
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

/// Renders the master Imperial / Metric switch + a per-category list,
/// modeled on the Strelok / Ballistics Calculator units page.
///
/// The master switch sets every category at once. The per-category
/// segmented buttons let advanced users mix systems (e.g. metric for
/// range but imperial for bullet weight). Changing the master switch
/// resets all per-category overrides.
class _UnitsSection extends StatelessWidget {
  const _UnitsSection({required this.units});

  final UnitService units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Master switch.
          SegmentedButton<UnitSystem>(
            segments: const [
              ButtonSegment(
                value: UnitSystem.imperial,
                label: Text('Use Imperial'),
              ),
              ButtonSegment(
                value: UnitSystem.metric,
                label: Text('Use Metric'),
              ),
            ],
            selected: {units.system},
            onSelectionChanged: (s) {
              // ignore: discarded_futures
              units.setSystem(s.first);
            },
            showSelectedIcon: false,
          ),
          const SizedBox(height: 8),
          Text(
            'Pick your default. You can fine-tune individual measurements below.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final cat in UnitCategory.values) ...[
            _UnitCategoryRow(units: units, category: cat),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// One row inside the Units section: the category title on top, a
/// horizontally-scrolling segmented button below.
class _UnitCategoryRow extends StatelessWidget {
  const _UnitCategoryRow({required this.units, required this.category});

  final UnitService units;
  final UnitCategory category;

  @override
  Widget build(BuildContext context) {
    final options = kUnitOptions[category] ?? const <String>[];
    final current = units.unitFor(category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          unitCategoryLabel(category),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: [
              for (final u in options)
                ButtonSegment(value: u, label: Text(unitDisplayLabel(u))),
            ],
            selected: {current},
            onSelectionChanged: (s) {
              // ignore: discarded_futures
              units.setOverride(category, s.first);
            },
            showSelectedIcon: false,
          ),
        ),
      ],
    );
  }
}

/// Settings list-tile that opens a bottom-sheet picker for the UI
/// language. The tile's trailing label reflects the current selection
/// (or "System default" when no override is set).
class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.localeService,
    required this.title,
    required this.subtitle,
    required this.systemDefaultLabel,
  });

  final LocaleService localeService;
  final String title;
  final String subtitle;
  final String systemDefaultLabel;

  @override
  Widget build(BuildContext context) {
    final code = localeService.languageCode;
    final currentLabel = code == null
        ? systemDefaultLabel
        : kLanguageDisplayNames[code] ?? code;
    return ListTile(
      leading: const Icon(Icons.language_outlined),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        currentLabel,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      onTap: () => _openPicker(context),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<_LanguagePickerResult>(
      context: context,
      builder: (ctx) => _LanguagePickerSheet(
        currentCode: localeService.languageCode,
        systemDefaultLabel: systemDefaultLabel,
      ),
    );
    if (selected == null) return;
    // ignore: discarded_futures
    localeService.setLanguageCode(selected.code);
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet({
    required this.currentCode,
    required this.systemDefaultLabel,
  });

  final String? currentCode;
  final String systemDefaultLabel;

  @override
  Widget build(BuildContext context) {
    final rows = <_LanguagePickerRowData>[
      _LanguagePickerRowData(code: null, label: systemDefaultLabel),
      for (final code in kSupportedLanguageCodes)
        _LanguagePickerRowData(
          code: code,
          label: kLanguageDisplayNames[code] ?? code,
        ),
    ];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final row in rows)
            ListTile(
              leading: Icon(
                row.code == currentCode
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: row.code == currentCode
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(row.label),
              onTap: () => Navigator.of(context).pop(
                _LanguagePickerResult(row.code),
              ),
            ),
        ],
      ),
    );
  }
}

class _LanguagePickerRowData {
  const _LanguagePickerRowData({required this.code, required this.label});
  final String? code;
  final String label;
}

class _LanguagePickerResult {
  const _LanguagePickerResult(this.code);
  final String? code;
}
