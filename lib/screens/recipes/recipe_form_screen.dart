import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../../repositories/component_repository.dart';
import '../../repositories/recipe_repository.dart';
import '../../widgets/component_field.dart';
import '../../widgets/primer_cascade_field.dart';

/// Trailing-`<num>gr` matcher used to extract the bullet weight out of a
/// catalog label like `"Berger Long Range Hybrid Target 109gr"`.
final RegExp _bulletWeightSuffix = RegExp(r'(\d+(?:\.\d+)?)\s*gr$');

/// Allowed values for the Primer Size dropdown.
const List<String> _primerSizeOptions = <String>[
  'Small Pistol',
  'Large Pistol',
  'Small Rifle',
  'Large Rifle',
  'Berdan',
];

/// Allowed values for the Primer Pocket Size dropdown.
const List<String> _primerPocketOptions = <String>[
  'SRP',
  'LRP',
  'SP',
  'LP',
  'Other',
];

/// Maps the seed-data primer-size keys (e.g. `"large-rifle"`) onto the
/// human-readable primer-size labels used in the dropdown.
String? _primerSizeLabelForSeedKey(String? seedKey) {
  switch (seedKey) {
    case 'small-pistol':
      return 'Small Pistol';
    case 'large-pistol':
      return 'Large Pistol';
    case 'small-rifle':
      return 'Small Rifle';
    case 'large-rifle':
      return 'Large Rifle';
    case 'berdan':
      return 'Berdan';
    default:
      return null;
  }
}

class RecipeFormScreen extends StatefulWidget {
  const RecipeFormScreen({super.key, this.existing});

  final UserLoadRow? existing;

  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _caliber;
  late final TextEditingController _powder;
  late final TextEditingController _powderCharge;
  late final TextEditingController _bullet;
  late final TextEditingController _bulletWeight;
  late final TextEditingController _primer;
  late final TextEditingController _brass;
  late final TextEditingController _coal;
  late final TextEditingController _cbto;
  late final TextEditingController _seatingDepth;
  late final TextEditingController _primerDepth;
  late final TextEditingController _shoulderBump;
  late final TextEditingController _mandrelSize;
  late final TextEditingController _notes;

  /// Picked from the dropdown; `null` means user hasn't selected one yet.
  String? _primerSize;
  String? _primerPocketSize;

  bool _showAdvanced = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _caliber = TextEditingController(text: e?.caliber ?? '');
    _powder = TextEditingController(text: e?.powder ?? '');
    _powderCharge = TextEditingController(
      text: e?.powderChargeGr?.toString() ?? '',
    );
    _bullet = TextEditingController(text: e?.bullet ?? '');
    _bulletWeight = TextEditingController(
      text: e?.bulletWeightGr?.toString() ?? '',
    );
    _primer = TextEditingController(text: e?.primer ?? '');
    _brass = TextEditingController(text: e?.brass ?? '');
    _coal = TextEditingController(text: e?.coalIn?.toString() ?? '');
    _cbto = TextEditingController(text: e?.cbtoIn?.toString() ?? '');
    _seatingDepth = TextEditingController(
      text: e?.seatingDepthIn?.toString() ?? '',
    );
    _primerDepth = TextEditingController(
      text: e?.primerDepthCps?.toString() ?? '',
    );
    _shoulderBump = TextEditingController(
      text: e?.shoulderBumpIn?.toString() ?? '',
    );
    _mandrelSize = TextEditingController(
      text: e?.mandrelSizeIn?.toString() ?? '',
    );
    _notes = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _caliber,
      _powder,
      _powderCharge,
      _bullet,
      _bulletWeight,
      _primer,
      _brass,
      _coal,
      _cbto,
      _seatingDepth,
      _primerDepth,
      _shoulderBump,
      _mandrelSize,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parseDouble(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  /// When the user picks a bullet from the catalog, parse the trailing
  /// `<num>gr` and shove it into the Bullet Weight field. Catalog labels
  /// always end with `<num>gr`; typed-in custom values are left alone.
  void _onBulletSelected(String label) {
    final match = _bulletWeightSuffix.firstMatch(label);
    if (match == null) return;
    final weight = match.group(1);
    if (weight == null) return;
    setState(() => _bulletWeight.text = weight);
  }

  /// When the user picks a primer like `"Federal #210M"`, look it up in
  /// the catalog and pre-fill Primer Size from its `Primers.size` field.
  Future<void> _onPrimerSelected(String label) async {
    final repo = context.read<ComponentRepository>();
    final row = await repo.primerByLabel(label);
    if (!mounted || row == null) return;
    final mapped = _primerSizeLabelForSeedKey(row.size);
    if (mapped != null) {
      setState(() => _primerSize = mapped);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final repo = context.read<RecipeRepository>();
    final components = context.read<ComponentRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Persist typed-in component values as custom for future dropdowns.
    Future<void> ensureCustom(String kind, TextEditingController c) async {
      final v = c.text.trim();
      if (v.isEmpty) return;
      final known = await components.componentLabels(kind);
      if (!known.contains(v)) {
        await components.addCustomComponent(kind, v);
      }
    }

    await Future.wait([
      ensureCustom('cartridge', _caliber),
      ensureCustom('powder', _powder),
      ensureCustom('bullet', _bullet),
      ensureCustom('primer', _primer),
      ensureCustom('brass', _brass),
    ]);

    final entry = UserLoadsCompanion(
      name: drift.Value(_name.text.trim()),
      caliber: drift.Value(_caliber.text.trim().isEmpty
          ? null
          : _caliber.text.trim()),
      powder: drift.Value(_powder.text.trim().isEmpty
          ? null
          : _powder.text.trim()),
      powderChargeGr: drift.Value(_parseDouble(_powderCharge)),
      bullet: drift.Value(_bullet.text.trim().isEmpty
          ? null
          : _bullet.text.trim()),
      bulletWeightGr: drift.Value(_parseDouble(_bulletWeight)),
      primer: drift.Value(_primer.text.trim().isEmpty
          ? null
          : _primer.text.trim()),
      brass: drift.Value(_brass.text.trim().isEmpty
          ? null
          : _brass.text.trim()),
      coalIn: drift.Value(_parseDouble(_coal)),
      cbtoIn: drift.Value(_parseDouble(_cbto)),
      seatingDepthIn: drift.Value(_parseDouble(_seatingDepth)),
      primerDepthCps: drift.Value(_parseDouble(_primerDepth)),
      shoulderBumpIn: drift.Value(_parseDouble(_shoulderBump)),
      mandrelSizeIn: drift.Value(_parseDouble(_mandrelSize)),
      notes: drift.Value(_notes.text.trim().isEmpty
          ? null
          : _notes.text.trim()),
    );

    if (widget.existing == null) {
      await repo.insert(entry);
      messenger.showSnackBar(const SnackBar(content: Text('Recipe saved.')));
    } else {
      await repo.update(widget.existing!.id, entry);
      messenger.showSnackBar(const SnackBar(content: Text('Recipe updated.')));
    }

    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Recipe' : 'New Recipe'),
        actions: [
          Row(
            children: [
              const Text('Advanced'),
              Switch(
                value: _showAdvanced,
                onChanged: (v) => setState(() => _showAdvanced = v),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Recipe Name *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Caliber — no inline advanced fields.
            ComponentField(
              kind: 'cartridge',
              label: 'Caliber',
              controller: _caliber,
            ),
            const SizedBox(height: 12),

            // Powder — no inline advanced fields.
            ComponentField(
              kind: 'powder',
              label: 'Powder',
              controller: _powder,
            ),
            const SizedBox(height: 12),

            // Powder Charge — no inline advanced fields.
            TextFormField(
              controller: _powderCharge,
              decoration: const InputDecoration(
                labelText: 'Powder Charge (gr)',
                suffixText: 'gr',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),

            // Bullet — advanced reveals Seating Depth.
            ComponentField(
              kind: 'bullet',
              label: 'Bullet',
              controller: _bullet,
              onSelected: _onBulletSelected,
            ),
            if (_showAdvanced) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _seatingDepth,
                decoration: const InputDecoration(
                  labelText: 'Seating Depth (in)',
                  suffixText: 'in',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            const SizedBox(height: 12),

            // Bullet Weight — no inline advanced fields.
            TextFormField(
              controller: _bulletWeight,
              decoration: const InputDecoration(
                labelText: 'Bullet Weight (gr)',
                suffixText: 'gr',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),

            // Primer — cascading brand → product picker. Stores the canonical
            // `"<Brand> #<Name>"` label in [_primer]; advanced reveals the
            // auto-filled Primer Size and the Primer Depth field.
            PrimerCascadeField(
              controller: _primer,
              onSelected: (label) {
                // ignore: discarded_futures
                _onPrimerSelected(label);
              },
            ),
            if (_showAdvanced) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _primerSize,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Primer Size'),
                items: [
                  for (final s in _primerSizeOptions)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _primerSize = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _primerDepth,
                decoration: const InputDecoration(
                  labelText: 'Primer Depth (in)',
                  suffixText: 'in',
                  helperText: 'CPS, in 0.001" units',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            const SizedBox(height: 12),

            // Brass — advanced reveals Primer Pocket, Shoulder Bump, Mandrel.
            ComponentField(
              kind: 'brass',
              label: 'Brass',
              controller: _brass,
            ),
            if (_showAdvanced) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _primerPocketSize,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Primer Pocket Size'),
                items: [
                  for (final s in _primerPocketOptions)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _primerPocketSize = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _shoulderBump,
                decoration: const InputDecoration(
                  labelText: 'Shoulder Bump (in)',
                  suffixText: 'in',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mandrelSize,
                decoration: const InputDecoration(
                  labelText: 'Mandrel Size (in)',
                  suffixText: 'in',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            const SizedBox(height: 12),

            // COAL — advanced reveals CBTO.
            TextFormField(
              controller: _coal,
              decoration: const InputDecoration(
                labelText: 'COAL (in)',
                suffixText: 'in',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (_showAdvanced) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _cbto,
                decoration: const InputDecoration(
                  labelText: 'CBTO (in)',
                  suffixText: 'in',
                  helperText: 'Cartridge base to ogive',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            const SizedBox(height: 12),

            // Notes — no inline advanced fields.
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(isEdit ? 'Save Changes' : 'Create Recipe'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
