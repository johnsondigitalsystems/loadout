// FILE: lib/widgets/find_by_scope_sheet.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Bottom sheet that lets the user pick their scope (by manufacturer +
// model) and returns the LoadOut archetype reticle ID that maps to
// what that scope ships with.
//
// Triggered from the reticle picker's "Find by my scope" affordance.
// Shown via `showFindByScopeSheet(context)`, which returns the chosen
// reticle ID via `Navigator.pop`. The reticle picker then auto-selects
// that reticle from its own list.
//
// Layout:
//
//   ┌─────────────────────────────────┐
//   │ Find your scope                 │
//   │ ┌─────────────────────────────┐ │
//   │ │ 🔍 Search by brand or model │ │
//   │ └─────────────────────────────┘ │
//   │ ─ Aimpoint                      │
//   │   CompM5                        │
//   │ ─ Arken Optics                  │
//   │   EP5 5-25x56 FFP               │
//   │   SH4 6-24x50 FFP               │
//   │ …                               │
//   └─────────────────────────────────┘
//
// Tapping a model row pops with the recommended reticle ID. Tapping
// outside / closing pops with `null`.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// After the reticle catalog was scrubbed of brand-licensed names (the
// IP scrub), the picker shows ONLY LoadOut-original archetypes +
// public-domain reticles. A user who knows their scope ("I have a
// Vortex Razor Gen III") can no longer find their reticle by name in
// the picker. This sheet is the discoverability bridge: type your
// scope, get the LoadOut archetype that does the same hold-off math.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The catalog is loaded async via `ScopeCatalogService` — a
//     `FutureBuilder` handles the first-call load. Subsequent calls
//     hit the in-memory cache.
//   * Search is on a lowercased haystack (manufacturer + model). It
//     matches substrings, not just prefixes — so "razor gen iii"
//     finds "Vortex Optics — Razor HD Gen III 6-36x56".
//   * Manufacturer headers render only when the manufacturer name
//     differs from the previous row. A single-pass walk over the
//     sorted list inserts headers as it goes.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `lib/widgets/reticle_picker.dart` — the "Find by my scope"
//     tile inside the picker calls `showFindByScopeSheet(context)`
//     and feeds the returned id into the picker's selection state.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Reads the `scope_reticle_options.json` asset on first call (via
//   ScopeCatalogService cache). No DB I/O, no network.

import 'package:flutter/material.dart';

import '../services/scope_catalog_service.dart';

/// Show the find-by-scope picker. Returns the LoadOut reticle ID the
/// user's scope maps to, or `null` if they dismissed without picking.
Future<String?> showFindByScopeSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Inset below the status bar / Dynamic Island. Without this the
    // sheet's title + search field render behind the system UI on
    // tall iOS phones, which is the reason the user couldn't see
    // the filter text area.
    useSafeArea: true,
    builder: (_) => const _FindByScopeSheet(),
  );
}

class _FindByScopeSheet extends StatefulWidget {
  const _FindByScopeSheet();

  @override
  State<_FindByScopeSheet> createState() => _FindByScopeSheetState();
}

class _FindByScopeSheetState extends State<_FindByScopeSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late final Future<List<ScopeCatalogEntry>> _scopesFuture;

  @override
  void initState() {
    super.initState();
    _scopesFuture = ScopeCatalogService.instance.allScopes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SizedBox(
          // Don't let the sheet fill the screen — leave room for the
          // user to dismiss by tapping the scrim.
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find your scope',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'We will recommend the closest LoadOut reticle.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (v) =>
                          setState(() => _query = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search by brand or model',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: 'Clear',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<ScopeCatalogEntry>>(
                  future: _scopesFuture,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final all = snap.data ?? const <ScopeCatalogEntry>[];
                    final filtered = _query.isEmpty
                        ? all
                        : all
                            .where((e) => e.searchHaystack.contains(_query))
                            .toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            all.isEmpty
                                ? 'No scopes in the catalog yet.'
                                : 'No scopes match "$_query".',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }
                    return _ScopeList(entries: filtered);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the scope list with manufacturer-section headers. The
/// entries arrive pre-sorted by (manufacturer, model) from the
/// service, so we walk once and emit a header whenever the
/// manufacturer changes.
class _ScopeList extends StatelessWidget {
  const _ScopeList({required this.entries});

  final List<ScopeCatalogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    String? lastManufacturer;
    for (final entry in entries) {
      if (entry.manufacturer != lastManufacturer) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              entry.manufacturer,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
        lastManufacturer = entry.manufacturer;
      }
      children.add(
        ListTile(
          dense: true,
          title: Text(entry.model),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => Navigator.of(context).pop(entry.recommendedReticleId),
        ),
      );
    }
    return ListView(children: children);
  }
}
