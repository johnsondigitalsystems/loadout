// FILE: lib/screens/recipes/quick_add_recipe_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// One-screen, no-scrolling, no-sections recipe form aimed at the
// pen-and-paper reloader cohort. Captures only the five fields a
// reloader writes in their notebook line:
//
//   1. Recipe name
//   2. Caliber
//   3. Powder + charge (gr)
//   4. Bullet + weight (gr)
//   5. COAL or CBTO (one of)
//   6. Optional notes
//
// Plus a "Start from a template" picker at the top that pre-fills all
// five fields with a published-data starting load (see
// `lib/data/recipe_templates.dart`).
//
// On save the form writes a `UserLoadsCompanion` to `RecipeRepository`
// the same way the long-form recipe screen does, then pops back to the
// recipes list. There is also a "Switch to detailed" link at the bottom
// that pushes `RecipeFormScreen(existing: row)` so the user can keep
// editing the same recipe in the full form.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The product survey shows 66% of reloaders use pen and paper. The
// long-form `RecipeFormScreen` (60+ fields, expandable sections, lot
// pickers, custom-fields support, autosave bookkeeping) is overwhelming
// for that audience. Quick Add is the parallel entry point that mirrors
// their existing notebook line — five fields, one tap to save.
//
// Templates exist for the same reason: a beginner who has never picked
// a charge weight needs a known-good starting point. The disclaimer
// banner ("ALWAYS verify against your current reloading manual") is
// non-negotiable — published starting loads are reference points, not
// recommendations, and the UI has to make that loud.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Both `RecipeFormScreen` and Quick Add write to the same
//    underlying `UserLoads` table.** Saving here and then opening the
//    recipe in the long form has to feel seamless — same ID, same
//    fields, same edit history. We achieve that by re-using
//    `RecipeRepository.insert` and pushing `RecipeFormScreen(existing: row)`
//    after save when the user picks "Switch to detailed".
//
// 2. **Custom components must still be persisted on save.** When the
//    user types a powder name that isn't in the catalog, Quick Add
//    writes it to `CustomComponents` so it appears in future dropdowns,
//    matching the long-form behaviour. Forgetting that would be a
//    silent regression (next time the user types the same powder, the
//    autocomplete wouldn't suggest it).
//
// 3. **Template application is one-shot.** Picking a template fills
//    the controllers; the user can then edit any field. Switching
//    templates after editing overwrites — that's by design. The
//    template id is held in state purely for the dropdown's selected
//    indicator; we never read it back at save time.
//
// 4. **Either-COAL-or-CBTO pattern.** Notebooks usually carry one or
//    the other, not both. Quick Add presents a segmented switch that
//    swaps the field's label and target controller. The other field
//    gets cleared so save doesn't accidentally write a stale value
//    from before the swap.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/recipes/recipes_list_screen.dart — the FAB opens a
//   small two-option menu ("Quick Add" / "Detailed Recipe") that
//   pushes either this screen or the long form.

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../../models/recipe_template.dart';
import '../../repositories/component_repository.dart';
import '../../repositories/recipe_repository.dart';
import '../../services/beginner_mode_service.dart';
import '../../widgets/component_field.dart';
import '../../widgets/import_options_section.dart';
import '../glossary/glossary_screen.dart';
import 'recipe_form_screen.dart';

class QuickAddRecipeScreen extends StatefulWidget {
  const QuickAddRecipeScreen({super.key});

  @override
  State<QuickAddRecipeScreen> createState() => _QuickAddRecipeScreenState();
}

/// Which dimension column the Quick Add COAL/CBTO row writes into.
///
/// Mirrors the same-named enum in `photo_import_review_screen.dart`
/// deliberately — both screens capture either-but-not-both for one
/// dimension. Phase Two item #7 (unified field taxonomy) collapses
/// the two enums into one canonical `RecipeFieldId`-style type; do
/// NOT unify them in this group.
enum _DimensionAxis { coal, cbto }

class _QuickAddRecipeScreenState extends State<QuickAddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _caliber = TextEditingController();
  final _powder = TextEditingController();
  final _powderCharge = TextEditingController();
  final _bullet = TextEditingController();
  final _bulletWeight = TextEditingController();

  /// Single text field that backs whichever of COAL / CBTO the user
  /// has selected on the axis toggle. `_buildCompanion` routes the
  /// parsed value into the right drift column at save time so we
  /// never persist a stale value from the OTHER axis after a swap.
  final _dimension = TextEditingController();

  final _notes = TextEditingController();

  /// Which drift column the [_dimension] field writes into.
  /// Defaults to COAL — that's what reloading manuals quote and what
  /// most pen-and-paper reloaders carry on their notebook line.
  _DimensionAxis _axis = _DimensionAxis.coal;

  /// Currently-selected template id (if any). Used only as the
  /// dropdown's indicator value.
  String? _selectedTemplateId;

  /// Pre-fill from useCase on the chosen template, if any. Persisted on
  /// save so the resulting recipe carries it forward.
  String? _useCase;

  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _caliber.dispose();
    _powder.dispose();
    _powderCharge.dispose();
    _bullet.dispose();
    _bulletWeight.dispose();
    _dimension.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _applyTemplate(RecipeTemplate t) {
    setState(() {
      _selectedTemplateId = t.id;
      _name.text = t.name;
      // Every pre-fill field is nullable post-Phase-Two-Group-1.
      // The five shipping templates all populate caliber + powder +
      // charge + bullet + weight, but the seed JSON could ship a
      // partial template tomorrow — fall back to empty rather than
      // crashing on null.
      _caliber.text = t.caliber ?? '';
      _powder.text = t.powder ?? '';
      _powderCharge.text = t.powderChargeGr?.toString() ?? '';
      _bullet.text = t.bullet ?? '';
      _bulletWeight.text = t.bulletWeightGr?.toString() ?? '';
      _useCase = t.useCase;
      // COAL / CBTO pre-fill. Templates are reference loads drawn from
      // published manuals; manuals quote COAL (overall length) much
      // more often than CBTO (base-to-ogive — comparator-dependent).
      // Prefer COAL when the template ships both; fall back to CBTO
      // when only CBTO is set; clear the field when neither is set so
      // a previously-applied template's dimension doesn't linger.
      if (t.coalIn != null) {
        _axis = _DimensionAxis.coal;
        _dimension.text = t.coalIn!.toString();
      } else if (t.cbtoIn != null) {
        _axis = _DimensionAxis.cbto;
        _dimension.text = t.cbtoIn!.toString();
      } else {
        _dimension.text = '';
      }
      // Append the template's note to anything the user already wrote.
      // Don't blow away their text — they may have typed something first
      // and only then noticed the template picker.
      final existing = _notes.text.trim();
      final fromTemplate = t.notes ?? '';
      if (existing.isEmpty) {
        _notes.text = fromTemplate;
      } else if (fromTemplate.isNotEmpty &&
          !existing.contains(fromTemplate)) {
        _notes.text = '$existing\n\n$fromTemplate';
      }
    });
  }

  /// Build the `UserLoadsCompanion` representing the current form state.
  /// Shared between `_save` (insert + pop) and "Switch to Regular"
  /// (insert + push detailed form when the form has a name; push the
  /// regular form pre-populated with the partial draft otherwise).
  ///
  /// If the user left the Recipe Name empty, generate one from the
  /// load-defining fields + a date/time stamp so the saved row is
  /// findable in the list view. Mirror the regular form's
  /// `_generateRecipeName` shape so the two flows produce
  /// look-alike names.
  UserLoadsCompanion _buildCompanion() {
    final typed = _name.text.trim();
    final name = typed.isEmpty ? _generateName() : typed;
    // COAL / CBTO routing. The single [_dimension] controller backs
    // whichever axis is selected. We parse once, then write the value
    // into the matching drift column AND null the other column so the
    // save doesn't carry a stale value from before an axis swap.
    final dimensionValue = double.tryParse(_dimension.text.trim());
    final coalToWrite =
        _axis == _DimensionAxis.coal ? dimensionValue : null;
    final cbtoToWrite =
        _axis == _DimensionAxis.cbto ? dimensionValue : null;
    return UserLoadsCompanion(
      name: drift.Value(name),
      caliber: drift.Value(_emptyToNull(_caliber.text)),
      powder: drift.Value(_emptyToNull(_powder.text)),
      powderChargeGr: drift.Value(double.tryParse(_powderCharge.text.trim())),
      bullet: drift.Value(_emptyToNull(_bullet.text)),
      bulletWeightGr: drift.Value(double.tryParse(_bulletWeight.text.trim())),
      coalIn: drift.Value(coalToWrite),
      cbtoIn: drift.Value(cbtoToWrite),
      useCase: drift.Value(_useCase),
      notes: drift.Value(_emptyToNull(_notes.text)),
    );
  }

  /// Fallback recipe name generator. See the regular form's
  /// `_generateRecipeName` for the canonical version; this one
  /// trims to the fields the Quick form actually has.
  String _generateName() {
    final parts = <String>[];
    final caliber = _caliber.text.trim();
    if (caliber.isNotEmpty) parts.add(caliber);
    final weight = _bulletWeight.text.trim();
    if (weight.isNotEmpty) {
      parts.add(weight.toLowerCase().endsWith('gr') ? weight : '${weight}gr');
    }
    final powder = _powder.text.trim();
    if (powder.isNotEmpty) {
      parts.add(powder.length > 12 ? '${powder.substring(0, 12)}…' : powder);
    }
    final body = parts.isEmpty ? 'Recipe' : parts.join(' ');
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = now.hour == 0
        ? 12
        : (now.hour > 12 ? now.hour - 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final minute = now.minute.toString().padLeft(2, '0');
    return '$body — ${months[now.month - 1]} ${now.day} '
        '$hour12:$minute $ampm';
  }

  String? _emptyToNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  Future<int?> _persist({required bool showSnack}) async {
    if (!_formKey.currentState!.validate()) return null;
    final repo = context.read<RecipeRepository>();
    final components = context.read<ComponentRepository>();
    setState(() => _busy = true);

    // Persist any typed-in component values to CustomComponents so they
    // appear in future dropdowns. Mirrors the long-form behaviour.
    Future<void> ensureCustom(String kind, String value) async {
      final v = value.trim();
      if (v.isEmpty) return;
      final known = await components.componentLabels(kind);
      if (!known.contains(v)) {
        await components.addCustomComponent(kind, v);
      }
    }

    try {
      await Future.wait([
        ensureCustom('cartridge', _caliber.text),
        ensureCustom('powder', _powder.text),
        ensureCustom('bullet', _bullet.text),
      ]);
      final id = await repo.insert(_buildCompanion());
      if (mounted && showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe saved.')),
        );
      }
      return id;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final id = await _persist(showSnack: true);
    if (id == null || !mounted) return;
    Navigator.of(context).pop();
  }

  /// "Switch to Regular" — open the full recipe form. The user does
  /// not need to fill in a Recipe Name first: if the name is empty,
  /// we just hand the partial draft to the regular form so they can
  /// keep editing what's typed, with an empty name field to fill in.
  /// If a name IS filled we persist first (so the row exists in the
  /// list and autosave from the long form is in `update` mode) and
  /// route to the saved row.
  Future<void> _switchToDetailed() async {
    final navigator = Navigator.of(context);
    final hasName = _name.text.trim().isNotEmpty;
    if (!hasName) {
      // No name yet — push the regular form with the partial draft as
      // the seed. The regular form will open with these values
      // populated and an empty Recipe Name field for the user to
      // fill in there.
      final draft = _buildCompanion();
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecipeFormScreen(initialDraft: draft),
        ),
      );
      return;
    }
    final id = await _persist(showSnack: false);
    if (id == null || !mounted) return;
    final repo = context.read<RecipeRepository>();
    final row = await repo.getById(id);
    if (row == null || !mounted) return;
    // Replace this Quick Add screen with the long form pre-populated
    // with the just-saved row, so back-button returns the user to the
    // recipes list — not back into Quick Add.
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => RecipeFormScreen(existing: row),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Glossary shortcut surfaces in the AppBar when Beginner Mode is on
    // so a new reloader can look up "COAL" or "CBTO" mid-entry without
    // hunting through the drawer.
    final beginnerOn = context.watch<BeginnerModeService>().isEnabled;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Add Recipe'),
        actions: [
          if (beginnerOn)
            IconButton(
              tooltip: 'Glossary',
              icon: const Icon(Icons.menu_book_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GlossaryScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _DisclaimerBanner(),
              const SizedBox(height: 12),
              _TemplatePickerCard(
                selectedId: _selectedTemplateId,
                onPick: _applyTemplate,
              ),
              const SizedBox(height: 12),
              // Collapsed-by-default imports section. Shared with the
              // regular form so users see the same set on both. We pop
              // back to the recipes list after a successful file
              // import — the user explicitly bulk-imported, so showing
              // them their list is the right next step.
              ImportOptionsSection(
                onImported: (_) {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 16),
              // Recipe Name is optional — when the user taps Save
              // with this empty, `_save` (further down) generates a
              // name from caliber + bullet weight + powder +
              // date/time. Hint copy makes the optional-ness clear.
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Recipe Name',
                  helperText:
                      'Optional — we name it for you if blank',
                ),
              ),
              const SizedBox(height: 12),
              ComponentField(
                kind: 'cartridge',
                label: 'Caliber',
                controller: _caliber,
              ),
              const SizedBox(height: 12),
              ComponentField(
                kind: 'powder',
                label: 'Powder',
                controller: _powder,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _powderCharge,
                decoration: const InputDecoration(
                  labelText: 'Powder Charge (gr)',
                  suffixText: 'gr',
                  helperText: 'How many grains of powder',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              ComponentField(
                kind: 'bullet',
                label: 'Bullet',
                controller: _bullet,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bulletWeight,
                decoration: const InputDecoration(
                  labelText: 'Bullet Weight (gr)',
                  suffixText: 'gr',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              // COAL / CBTO axis toggle + dimension field. See the
              // `_DimensionAxis` enum docstring for the routing rule.
              // The user picks which column to write into; the single
              // field's label and suffix swap to match.
              SegmentedButton<_DimensionAxis>(
                segments: const <ButtonSegment<_DimensionAxis>>[
                  ButtonSegment<_DimensionAxis>(
                    value: _DimensionAxis.coal,
                    label: Text('COAL'),
                  ),
                  ButtonSegment<_DimensionAxis>(
                    value: _DimensionAxis.cbto,
                    label: Text('CBTO'),
                  ),
                ],
                selected: <_DimensionAxis>{_axis},
                onSelectionChanged: (selection) {
                  setState(() => _axis = selection.first);
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dimension,
                decoration: InputDecoration(
                  labelText: _axis == _DimensionAxis.coal
                      ? 'COAL (in)'
                      : 'CBTO (in)',
                  suffixText: 'in',
                  helperText: _axis == _DimensionAxis.coal
                      ? 'Cartridge overall length'
                      : 'Cartridge base-to-ogive',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  helperText: 'Anything else you want to remember',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Save Recipe'),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: _busy ? null : _switchToDetailed,
                  icon: const Icon(Icons.tune),
                  label: const Text('Switch to Regular'),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Adds COAL, CBTO, primer, brass, pressure indicators, '
                  'and more — your typed values come along.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Always-visible "verify your manual" banner. Reloading manuals are the
/// source of truth — Quick Add is a notebook, not a load advisor.
class _DisclaimerBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              RecipeTemplate.disclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "start from a template" affordance. Renders an `ExpansionTile`
/// so the picker doesn't take vertical space until the user opens it.
class _TemplatePickerCard extends StatefulWidget {
  const _TemplatePickerCard({
    required this.selectedId,
    required this.onPick,
  });

  final String? selectedId;
  final ValueChanged<RecipeTemplate> onPick;

  @override
  State<_TemplatePickerCard> createState() => _TemplatePickerCardState();
}

class _TemplatePickerCardState extends State<_TemplatePickerCard> {
  /// Phase Two Group 1 (v41): templates now live in the seeded
  /// `RecipeTemplates` drift table, not a static const Dart list.
  /// We load once in `initState` and cache the Future so each
  /// rebuild reuses the same snapshot — `RecipeRepository.allTemplates()`
  /// hits SQLite, and we don't want a re-read per parent rebuild.
  late final Future<List<RecipeTemplate>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _templatesFuture = context.read<RecipeRepository>().allTemplates();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: widget.selectedId == null,
        leading: Icon(
          Icons.bolt_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          'Start from a template',
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          widget.selectedId == null
              ? 'Optional — pre-fill with a published starting load'
              : 'Template applied — edit any field below',
          style: theme.textTheme.bodySmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          FutureBuilder<List<RecipeTemplate>>(
            future: _templatesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                // Tight loader — the seed query returns in
                // milliseconds against the local SQLite catalog;
                // we never expect the user to see the spinner.
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final templates = snapshot.data ?? const <RecipeTemplate>[];
              if (templates.isEmpty) {
                // Defensive: the seed loader populates the table on
                // first launch. Surface an empty-state row rather
                // than rendering a blank ExpansionTile body.
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No templates available yet.',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }
              return Column(
                children: [
                  for (final t in templates)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        t.id == widget.selectedId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: t.id == widget.selectedId
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(t.name),
                      subtitle: Text(
                        _templateSubtitle(t),
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () => widget.onPick(t),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Build the subtitle line shown under each template name. Every
  /// field on `RecipeTemplate` is nullable post-Phase-Two-Group-1,
  /// so we compose only the parts we have a value for. The shipping
  /// templates all populate `powderChargeGr`, `powder`, and
  /// `bulletWeightGr`; the empty-subtitle fallback exists for
  /// future templates that might ship partial data.
  String _templateSubtitle(RecipeTemplate t) {
    final parts = <String>[];
    if (t.powderChargeGr != null && t.powder != null) {
      // Last token of "Hodgdon H4350" is the powder short-name
      // ("H4350"). Defensive split handles single-word inputs too.
      final powderShort = t.powder!.split(' ').last;
      parts.add('${t.powderChargeGr} gr $powderShort');
    } else if (t.powderChargeGr != null) {
      parts.add('${t.powderChargeGr} gr');
    } else if (t.powder != null) {
      parts.add(t.powder!.split(' ').last);
    }
    if (t.bulletWeightGr != null) {
      parts.add('${t.bulletWeightGr!.toStringAsFixed(0)}gr bullet');
    }
    return parts.join(' · ');
  }
}

