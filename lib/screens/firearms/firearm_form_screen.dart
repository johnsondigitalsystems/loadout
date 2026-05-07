import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../../repositories/component_repository.dart';
import '../../repositories/firearm_repository.dart';
import '../../widgets/component_field.dart';

typedef _RefEntry = ({
  FirearmRefRow firearm,
  ManufacturerRow manufacturer,
  List<String> calibers,
});

class FirearmFormScreen extends StatefulWidget {
  const FirearmFormScreen({super.key, this.existing});

  final UserFirearmRow? existing;

  @override
  State<FirearmFormScreen> createState() => _FirearmFormScreenState();
}

class _FirearmFormScreenState extends State<FirearmFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _manufacturer;
  late final TextEditingController _model;
  late final TextEditingController _type;
  late final TextEditingController _action;
  late final TextEditingController _caliber;
  late final TextEditingController _barrelLength;
  late final TextEditingController _twistRate;
  late final TextEditingController _shotsFired;
  late final TextEditingController _notes;

  bool _useCatalog = false;
  bool _busy = false;

  Future<List<_RefEntry>>? _refsFuture;
  _RefEntry? _selectedRef;
  int? _referenceFirearmId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _manufacturer = TextEditingController(text: e?.manufacturer ?? '');
    _model = TextEditingController(text: e?.model ?? '');
    _type = TextEditingController(text: e?.type ?? '');
    _action = TextEditingController(text: e?.action ?? '');
    _caliber = TextEditingController(text: e?.caliber ?? '');
    _barrelLength =
        TextEditingController(text: e?.barrelLengthIn?.toString() ?? '');
    _twistRate = TextEditingController(text: e?.twistRate ?? '');
    _shotsFired = TextEditingController(text: (e?.shotsFired ?? 0).toString());
    _notes = TextEditingController(text: e?.notes ?? '');
    _referenceFirearmId = e?.referenceFirearmId;
    _useCatalog = _referenceFirearmId != null;
    _refsFuture =
        context.read<ComponentRepository>().allReferenceFirearms();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _manufacturer,
      _model,
      _type,
      _action,
      _caliber,
      _barrelLength,
      _twistRate,
      _shotsFired,
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

  int _parseShots() {
    final v = int.tryParse(_shotsFired.text.trim()) ?? 0;
    return v < 0 ? 0 : v;
  }

  void _bumpShots(int delta) {
    final next = (_parseShots() + delta).clamp(0, 1 << 31);
    setState(() => _shotsFired.text = next.toString());
  }

  void _applyReferenceSelection(_RefEntry ref) {
    setState(() {
      _selectedRef = ref;
      _referenceFirearmId = ref.firearm.id;
      _manufacturer.text = ref.manufacturer.name;
      _model.text = ref.firearm.model;
      _type.text = ref.firearm.type;
      _action.text = ref.firearm.action ?? '';
      // If the current caliber isn't part of this reference, reset it so the
      // user must explicitly pick from the chooser.
      if (!ref.calibers.contains(_caliber.text)) {
        _caliber.text =
            ref.calibers.length == 1 ? ref.calibers.first : '';
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final repo = context.read<FirearmRepository>();
    final components = context.read<ComponentRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Persist a typed-in caliber as a custom cartridge so it appears in
    // future dropdowns.
    final caliberText = _caliber.text.trim();
    if (caliberText.isNotEmpty) {
      final known = await components.componentLabels('cartridge');
      if (!known.contains(caliberText)) {
        await components.addCustomComponent('cartridge', caliberText);
      }
    }

    String? nullIfEmpty(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    final entry = UserFirearmsCompanion(
      name: drift.Value(_name.text.trim()),
      manufacturer: drift.Value(nullIfEmpty(_manufacturer)),
      model: drift.Value(nullIfEmpty(_model)),
      type: drift.Value(nullIfEmpty(_type)),
      action: drift.Value(nullIfEmpty(_action)),
      caliber: drift.Value(nullIfEmpty(_caliber)),
      barrelLengthIn: drift.Value(_parseDouble(_barrelLength)),
      twistRate: drift.Value(nullIfEmpty(_twistRate)),
      shotsFired: drift.Value(_parseShots()),
      referenceFirearmId:
          drift.Value(_useCatalog ? _referenceFirearmId : null),
      notes: drift.Value(nullIfEmpty(_notes)),
    );

    if (widget.existing == null) {
      await repo.insert(entry);
      messenger.showSnackBar(const SnackBar(content: Text('Firearm saved.')));
    } else {
      await repo.update(widget.existing!.id, entry);
      messenger
          .showSnackBar(const SnackBar(content: Text('Firearm updated.')));
    }

    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Firearm' : 'New Firearm')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Pick from Catalog')),
                ButtonSegment(value: false, label: Text('Custom')),
              ],
              selected: {_useCatalog},
              onSelectionChanged: (s) {
                setState(() {
                  _useCatalog = s.first;
                  if (!_useCatalog) {
                    _selectedRef = null;
                    _referenceFirearmId = null;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            if (_useCatalog) ..._catalogFields() else ..._customFields(),
            const SizedBox(height: 12),
            ComponentField(
              kind: 'cartridge',
              label: 'Caliber',
              controller: _caliber,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barrelLength,
              decoration: const InputDecoration(
                labelText: 'Barrel Length (in)',
                suffixText: 'in',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _twistRate,
              decoration: const InputDecoration(
                labelText: 'Twist Rate',
                hintText: 'e.g. 1:8',
              ),
            ),
            const SizedBox(height: 16),
            _shotsFiredField(context),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(isEdit ? 'Save Changes' : 'Create Firearm'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<Widget> _catalogFields() {
    return [
      FutureBuilder<List<_RefEntry>>(
        future: _refsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            );
          }
          final refs = snap.data ?? const <_RefEntry>[];
          if (refs.isEmpty) {
            return const Text(
              'No reference firearms in the catalog. Switch to Custom.',
            );
          }
          // Initialise selected ref from existing referenceFirearmId.
          if (_selectedRef == null && _referenceFirearmId != null) {
            for (final r in refs) {
              if (r.firearm.id == _referenceFirearmId) {
                _selectedRef = r;
                break;
              }
            }
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<_RefEntry>(
                initialValue: _selectedRef,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Model from Catalog'),
                items: [
                  for (final r in refs)
                    DropdownMenuItem(
                      value: r,
                      child: Text(
                        '${r.manufacturer.name} ${r.firearm.model}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (r) {
                  if (r != null) _applyReferenceSelection(r);
                },
                validator: (v) => v == null ? 'Pick a model' : null,
              ),
              const SizedBox(height: 12),
              if (_selectedRef != null) ...[
                _readOnlyTile('Manufacturer', _selectedRef!.manufacturer.name),
                _readOnlyTile('Model', _selectedRef!.firearm.model),
                _readOnlyTile('Type', _selectedRef!.firearm.type),
                if ((_selectedRef!.firearm.action ?? '').isNotEmpty)
                  _readOnlyTile('Action', _selectedRef!.firearm.action!),
                const SizedBox(height: 8),
                if (_selectedRef!.calibers.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRef!.calibers
                            .contains(_caliber.text)
                        ? _caliber.text
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Caliber for This Firearm',
                    ),
                    items: [
                      for (final c in _selectedRef!.calibers)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _caliber.text = v);
                      }
                    },
                  ),
              ],
            ],
          );
        },
      ),
    ];
  }

  List<Widget> _customFields() {
    return [
      TextFormField(
        controller: _manufacturer,
        decoration: const InputDecoration(labelText: 'Manufacturer'),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _model,
        decoration: const InputDecoration(labelText: 'Model'),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _type,
        decoration: const InputDecoration(
          labelText: 'Type',
          hintText: 'pistol / rifle / shotgun',
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _action,
        decoration: const InputDecoration(
          labelText: 'Action',
          hintText: 'e.g. bolt-action, semi-auto',
        ),
      ),
    ];
  }

  Widget _readOnlyTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _shotsFiredField(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextFormField(
            controller: _shotsFired,
            decoration: const InputDecoration(labelText: 'Shots Fired'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final n = int.tryParse(v.trim());
              if (n == null || n < 0) return 'Must be a positive integer';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () => _bumpShots(-1),
          icon: const Icon(Icons.remove),
          tooltip: 'Decrement',
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          onPressed: () => _bumpShots(1),
          icon: const Icon(Icons.add),
          tooltip: 'Increment',
        ),
      ],
    );
  }
}
