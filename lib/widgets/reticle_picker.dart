// FILE: lib/widgets/reticle_picker.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Reusable reticle picker. Embed this in any form — firearm form, range-
// day setup, ballistics profile editor — and it shows the user a
// compact preview tile with the currently-selected reticle, lets them
// tap to open a search-and-pick modal that lists every reticle in the
// catalog, and reports the selection back via a callback.
//
// Public API:
//
// ```dart
// ReticlePickerField(
//   label: 'Reticle',
//   selected: pickedReticleRow,    // ReticleRow? — nullable for "none"
//   onChanged: (row) {
//     setState(() => pickedReticleRow = row);
//   },
//   restrictToOpticId: 12,         // optional: prefer reticles linked
//                                  // to this optic
// )
// ```
//
// The picker handles its own data fetch — it reads the singleton
// `ReticleRepository` from `Provider`, so the parent only has to wire
// `Provider<ReticleRepository>` once at the root (already done in
// `lib/app.dart`).
//
// Layout of the modal sheet:
//
//   ┌──────────────────────────────────────────────┐
//   │ Pick a reticle                       [None]  │  ← title + clear
//   │ [search box]                                 │
//   │ ── Popular reticles ──                       │
//   │ [chips: Tremor3 · MIL-Dot · MIL-Hash · …]    │  ← brand-agnostic
//   │ ── All reticles ──                           │
//   │ [×] Vortex EBR-7C MRAD       FFP · MIL  ⤢   │  ← row + Preview
//   │     Razor HD Gen II reticles                 │
//   └──────────────────────────────────────────────┘
//
// The list row's leading is a small generic crosshair glyph
// ([ReticleThumbnail]), not a per-reticle preview — the prior
// implementation rendered every row through `ReticleRenderer` at
// 64 px and produced a smear of hash marks too small to evaluate.
// Tapping the trailing fullscreen icon opens
// [showReticleFullScreenPreview] for a high-fidelity render against
// the procedural daytime backdrop.
//
// ============================================================================
// WHY IT EXISTS
// ============================================================================
// Multiple screens (firearm form, range day, future ballistics work)
// need the same picker, so we wrap it once. Picking from the full
// catalog with no filter is the common case; `restrictToOpticId` adds
// a "compatible" filter for the range-day flow where the user has
// already chosen which optic they're shooting through.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Search has to span name + manufacturer + family + derived tags
//     (so a search for "tremor3" or "horus" returns every Tremor3
//     reticle from every brand it's licensed for, not just the rows
//     whose model string contains the literal word). The matching
//     rule lives in `lib/data/reticle_tags.dart::reticleMatchesQuery`
//     so it can be unit-tested and so any new screen that wants to
//     filter the catalog can call the same function.
//   * The "Popular reticles" chip row at the top duplicates entries
//     by tag (one chip can match multiple reticles). When the user
//     taps a chip, the picker filters the list — but it does NOT
//     replace the search box content, so the user can stack a popular
//     filter and a freeform search.
//   * Don't reach back into the parent to render the per-row preview
//     — every reticle row mounting a full ReticleRenderer at 64×64
//     was the dropdown's biggest perf hit AND visual-clutter problem.
//     The generic thumbnail is mounted instead, and any user who wants
//     to see the actual reticle taps the trailing fullscreen icon.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/screens/firearms/firearm_form_screen.dart` — picker on the
//   Optics card, beneath the optics dropdown.
// - `lib/screens/range_day/...` — surfaces by the parallel agent for
//   their reticle / aim-point UI.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None directly. Shows a modal bottom sheet and an optional
// full-screen preview dialog. The persistence of the user's pick is
// the parent's responsibility (this widget only fires
// [onChanged]).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/reticle_library.dart';
import '../data/reticle_tags.dart';
import '../database/database.dart';
import '../repositories/reticle_repository.dart';
import 'find_by_scope_sheet.dart';
import 'reticle_full_screen_view.dart';
import 'reticle_renderer.dart';
import 'reticle_thumbnail.dart';

/// Reusable form field that lets the user pick a reticle. Renders a
/// label, a preview tile with the selected reticle's name and family,
/// and a chevron. Tapping opens a modal-bottom-sheet picker.
class ReticlePickerField extends StatelessWidget {
  const ReticlePickerField({
    super.key,
    required this.selected,
    required this.onChanged,
    this.label = 'Reticle',
    this.allowNone = true,
    this.restrictToOpticId,
  });

  /// Currently selected reticle (drift row), or null for "no reticle".
  final ReticleRow? selected;

  /// Called with the user's selection. `null` means "no reticle" if
  /// `allowNone` is true.
  final ValueChanged<ReticleRow?> onChanged;

  /// Field label text. Defaults to "Reticle".
  final String label;

  /// Whether the picker offers a "None / iron sights" choice. Defaults
  /// to true so a firearm without an optic can keep this field clear.
  final bool allowNone;

  /// Optional optic id to highlight reticles compatible with this
  /// optic. We don't currently filter the list — every reticle is
  /// always pickable — but the row that matches the optic's
  /// `Optics.reticleId` shows a small "default" badge.
  final int? restrictToOpticId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.read<ReticleRepository>();
    final selectedDef = selected != null ? repo.definitionFromRow(selected!) : null;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Row(
          children: [
            // Preview thumbnail (or a placeholder when nothing's
            // picked). This is the FIELD-level preview (visible while
            // the picker is closed) — we keep the high-fidelity
            // ReticleRenderer here because there's only one of these
            // mounted at a time (vs. the dropdown list, where every
            // row would mount one).
            SizedBox(
              width: 56,
              height: 56,
              child: selectedDef != null
                  ? ReticleRenderer(
                      reticle: selectedDef,
                      displayUnit:
                          selectedDef.nativeUnit == ReticleNativeUnit.moa
                              ? 'moa'
                              : 'mil',
                      size: const Size(56, 56),
                      showUnitOverlay: false,
                      color: theme.colorScheme.primary,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.crop_free_outlined,
                        size: 22,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    selected == null
                        ? 'None / iron sights'
                        : '${selected!.manufacturerId} ${selected!.model}',
                    style: theme.textTheme.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (selected?.family != null)
                    Text(
                      selected!.family!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final repo = context.read<ReticleRepository>();
    final result = await showModalBottomSheet<_ReticleSelection>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ReticlePickerSheet(
        repo: repo,
        selectedId: selected?.id,
        allowNone: allowNone,
        restrictToOpticId: restrictToOpticId,
      ),
    );
    if (result == null) return;
    if (result.cleared) {
      onChanged(null);
    } else if (result.row != null) {
      onChanged(result.row);
    }
  }
}

/// Internal modal sheet that drives the picker. We isolate it so the
/// parent rebuild doesn't rebuild the search state.
class _ReticleSelection {
  const _ReticleSelection({this.row, this.cleared = false});
  final ReticleRow? row;
  final bool cleared;
}

class _ReticlePickerSheet extends StatefulWidget {
  const _ReticlePickerSheet({
    required this.repo,
    required this.selectedId,
    required this.allowNone,
    required this.restrictToOpticId,
  });

  final ReticleRepository repo;
  final int? selectedId;
  final bool allowNone;
  final int? restrictToOpticId;

  @override
  State<_ReticlePickerSheet> createState() => _ReticlePickerSheetState();
}

class _ReticlePickerSheetState extends State<_ReticlePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// Currently active "popular reticle" tag (from
  /// [kPopularReticleTags]). Null when no popular chip is engaged. The
  /// chips and the search box stack — when both are set, the list
  /// shows reticles that satisfy BOTH constraints.
  String? _popularTag;

  Future<List<ReticleRow>>? _future;
  Future<int?>? _defaultIdFuture;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.allReticles();
    if (widget.restrictToOpticId != null) {
      _defaultIdFuture =
          widget.repo.byOptic(widget.restrictToOpticId!).then((r) => r?.id);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: media.size.height * 0.85,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pick a reticle',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    if (widget.allowNone)
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .pop(const _ReticleSelection(cleared: true)),
                        child: const Text('None'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Search by name or category (e.g. mil tree, red dot)',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(height: 8),
              // "Find by my scope" affordance — opens a bottom sheet
              // listing every scope in the catalog. The user picks
              // their scope; the sheet returns the LoadOut archetype
              // ID it maps to. We then auto-select that reticle from
              // the picker's loaded list. This is the
              // discoverability bridge for users who knew their
              // branded reticle name (TReMoR3, EBR-7D, etc.) but
              // can no longer find it directly because the catalog
              // ships only LoadOut originals + public-domain
              // patterns post-IP-scrub.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _onFindByScope(context),
                    icon: const Icon(Icons.search_outlined, size: 18),
                    label: const Text('Find by my scope'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
              // Popular-reticles chip row: brand-agnostic shortcuts.
              _popularChipsRow(theme),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<ReticleRow>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load reticles: ${snap.error}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    }
                    final all = snap.data ?? const <ReticleRow>[];
                    final filtered = _applyFilters(all);
                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _emptyMessage(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }
                    return FutureBuilder<int?>(
                      future: _defaultIdFuture ?? Future.value(null),
                      builder: (context, defaultSnap) {
                        final defaultId = defaultSnap.data;
                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: theme.dividerColor),
                          itemBuilder: (context, i) {
                            final row = filtered[i];
                            final selected = row.id == widget.selectedId;
                            final isDefault = defaultId == row.id;
                            return _ReticleListRow(
                              row: row,
                              repo: widget.repo,
                              selected: selected,
                              isDefault: isDefault,
                              onPick: () => Navigator.of(context)
                                  .pop(_ReticleSelection(row: row)),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Open the find-by-scope sheet. If the user picks a scope, resolve
  /// the recommended LoadOut archetype id via the reticle repo's
  /// natural-key lookup and pop the picker with that selection.
  /// Soft-fails on missing recommendation (snackbar) — never throws.
  Future<void> _onFindByScope(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final recommendedId = await showFindByScopeSheet(context);
    if (recommendedId == null) return;
    if (!mounted) return;
    ReticleRow? match;
    try {
      match = await widget.repo.byNaturalKey(recommendedId);
    } catch (_) {
      match = null;
    }
    if (!mounted) return;
    if (match == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not find the recommended reticle '
            '("$recommendedId"). Pick one from the list below.',
          ),
        ),
      );
      return;
    }
    navigator.pop(_ReticleSelection(row: match));
  }

  /// Brand-agnostic "Popular reticles" chip row. Each chip filters the
  /// list to reticles whose tag set contains the chip's tag. Tap an
  /// active chip again to clear it.
  Widget _popularChipsRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Text(
              'Popular reticles',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Use Wrap so chips re-flow on narrow widths instead of
          // overflowing the row (and so we never trigger an
          // infinite-width Row+Expanded layout bug).
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final entry in kPopularReticleTags)
                _popularChip(theme, entry),
            ],
          ),
        ],
      ),
    );
  }

  Widget _popularChip(ThemeData theme, PopularReticleEntry entry) {
    final active = _popularTag == entry.tag;
    return Tooltip(
      message: entry.description,
      child: FilterChip(
        label: Text(entry.label),
        selected: active,
        onSelected: (on) =>
            setState(() => _popularTag = on ? entry.tag : null),
        showCheckmark: false,
        // Use the theme's onSecondary on selected so the brand-tinted
        // chip remains readable in both light and dark themes.
        selectedColor: theme.colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: active
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
        side: active
            ? BorderSide(color: theme.colorScheme.primary, width: 1.2)
            : BorderSide(color: theme.colorScheme.outlineVariant),
        padding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// Apply the search query and active popular-tag filter (if any) to
  /// the full reticle list. The result is the rows that should appear
  /// in the dropdown.
  List<ReticleRow> _applyFilters(List<ReticleRow> all) {
    return all.where((r) {
      // Popular tag filter.
      if (_popularTag != null) {
        final matchPopular = reticleHasPopularTag(
          popularTag: _popularTag!,
          manufacturer: r.manufacturerId,
          model: r.model,
          family: r.family,
        );
        if (!matchPopular) return false;
      }
      // Search filter.
      if (_query.isNotEmpty) {
        final matchSearch = reticleMatchesQuery(
          query: _query,
          manufacturer: r.manufacturerId,
          model: r.model,
          family: r.family,
        );
        if (!matchSearch) return false;
      }
      return true;
    }).toList();
  }

  String _emptyMessage() {
    if (_popularTag != null && _query.isNotEmpty) {
      return 'No reticles match "${_searchController.text}" '
          'in the "$_popularTag" family.';
    }
    if (_popularTag != null) {
      return 'No reticles tagged "$_popularTag".';
    }
    return 'No reticles match "${_searchController.text}".';
  }
}

/// Row in the dropdown list. Pulled into its own widget so the
/// list-row build is self-contained (it owns the trailing "Preview"
/// icon's tap handler and the type-label helper).
class _ReticleListRow extends StatelessWidget {
  const _ReticleListRow({
    required this.row,
    required this.repo,
    required this.selected,
    required this.isDefault,
    required this.onPick,
  });

  final ReticleRow row;
  final ReticleRepository repo;
  final bool selected;
  final bool isDefault;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: ReticleThumbnail(
            size: 28,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        '${row.manufacturerId} ${row.model}',
        style: theme.textTheme.bodyLarge,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (row.family != null) row.family!,
          '${row.nativeUnit.toUpperCase()} • ${_typeLabel(row.type)}',
          if (isDefault) 'default for selected optic',
        ].join(' • '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // Trailing: a "Preview" icon that opens the full-screen preview.
      // The tap target on the icon is independent of the row tap, so a
      // user who clicks the row picks the reticle, but a user who taps
      // the magnifier icon just gets a preview.
      trailing: Wrap(
        spacing: 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (selected)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.check,
                color: theme.colorScheme.primary,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Preview at full size',
            onPressed: () {
              showReticleFullScreenPreview(
                context,
                reticle: repo.definitionFromRow(row),
                reticleLabel: '${row.manufacturerId} ${row.model}',
              );
            },
          ),
        ],
      ),
      onTap: onPick,
    );
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'ffp':
        return 'FFP';
      case 'sfp':
        return 'SFP';
      case 'fixed':
        return 'Fixed';
      default:
        return type.toUpperCase();
    }
  }
}
