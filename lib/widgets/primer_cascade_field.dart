import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database.dart';
import '../repositories/component_repository.dart';

/// Two-stage cascading dropdown for primer selection.
///
/// First dropdown picks a manufacturer (e.g. "Federal"). Second dropdown
/// then loads the products for that manufacturer and shows them with their
/// marketing name plus model number, e.g.
/// `"Premium Gold Medal Small Rifle Match #GM205M"`.
///
/// The widget persists the user's pick into a single [TextEditingController]
/// using the `"<Brand> #<Name>"` format, identical to the legacy
/// [ComponentField] behavior, so existing recipes load and save unchanged.
///
/// A "type your own" fallback is provided for users whose primer isn't in
/// the catalog: pick "Other / Custom…" in the brand dropdown to expose a
/// free-form text field.
class PrimerCascadeField extends StatefulWidget {
  const PrimerCascadeField({
    super.key,
    required this.controller,
    this.onSelected,
  });

  /// Stores the canonical `"<Brand> #<Name>"` label (e.g. `"Federal #210M"`).
  /// Same shape used by the prior single [ComponentField] so the rest of the
  /// app — including [ComponentRepository.primerByLabel] for primer-size
  /// auto-fill — keeps working unchanged.
  final TextEditingController controller;

  /// Fires when the user picks a primer from the dropdown (not on every
  /// keystroke of the custom text field). Receives the canonical label.
  final ValueChanged<String>? onSelected;

  @override
  State<PrimerCascadeField> createState() => _PrimerCascadeFieldState();
}

class _PrimerCascadeFieldState extends State<PrimerCascadeField> {
  static const String _customSentinel = '__custom__';

  Future<List<String>>? _futureBrands;
  String? _selectedBrand;
  String? _selectedPrimerName; // null until product is picked
  Future<List<PrimerRow>>? _futureProducts;
  late TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(text: widget.controller.text);
    _futureBrands = context.read<ComponentRepository>().primerManufacturers();
    // Try to pre-select brand + product from the existing controller value.
    _hydrateFromController(widget.controller.text);
    widget.controller.addListener(_onExternalControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalControllerChange);
    _customController.dispose();
    super.dispose();
  }

  /// Re-hydrate when the parent form resets the controller (e.g. clears for
  /// "New Recipe"). Avoid loops by only setting state when something changed.
  void _onExternalControllerChange() {
    final text = widget.controller.text;
    final parsed = ComponentRepository.splitPrimerStorageLabel(text);
    if (parsed == null) {
      // Either empty or custom value
      if (_selectedBrand != _customSentinel || _customController.text != text) {
        setState(() {
          _selectedBrand = text.isEmpty ? null : _customSentinel;
          _selectedPrimerName = null;
          _customController.text = text;
        });
      }
      return;
    }
    if (_selectedBrand != parsed.manufacturer ||
        _selectedPrimerName != parsed.primerName) {
      setState(() {
        _selectedBrand = parsed.manufacturer;
        _selectedPrimerName = parsed.primerName;
        _futureProducts = context
            .read<ComponentRepository>()
            .primersByManufacturer(parsed.manufacturer);
      });
    }
  }

  void _hydrateFromController(String text) {
    final parsed = ComponentRepository.splitPrimerStorageLabel(text);
    if (parsed != null) {
      _selectedBrand = parsed.manufacturer;
      _selectedPrimerName = parsed.primerName;
      _futureProducts = context
          .read<ComponentRepository>()
          .primersByManufacturer(parsed.manufacturer);
    } else if (text.isNotEmpty) {
      _selectedBrand = _customSentinel;
      _customController.text = text;
    }
  }

  void _onBrandChanged(String? value) {
    if (value == null) return;
    setState(() {
      _selectedBrand = value;
      _selectedPrimerName = null;
      if (value == _customSentinel) {
        _futureProducts = null;
        // Preserve any existing custom text the user typed before
        widget.controller.text = _customController.text;
      } else {
        _futureProducts =
            context.read<ComponentRepository>().primersByManufacturer(value);
        // Clear stored value until a product is picked
        widget.controller.text = '';
      }
    });
  }

  void _onProductChanged(PrimerRow? p) {
    if (p == null || _selectedBrand == null) return;
    final label =
        ComponentRepository.primerStorageLabel(_selectedBrand!, p);
    setState(() {
      _selectedPrimerName = p.name;
      widget.controller.text = label;
    });
    widget.onSelected?.call(label);
  }

  void _onCustomTextChanged(String value) {
    widget.controller.text = value;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _futureBrands,
      builder: (context, snap) {
        final brands = snap.data ?? const <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedBrand,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Primer Brand',
                helperText: 'Pick a manufacturer or choose "Other / Custom"',
              ),
              items: [
                for (final b in brands)
                  DropdownMenuItem<String>(value: b, child: Text(b)),
                const DropdownMenuItem<String>(
                  value: _customSentinel,
                  child: Text('Other / Custom…'),
                ),
              ],
              onChanged: _onBrandChanged,
            ),
            const SizedBox(height: 12),
            if (_selectedBrand == null)
              const _PlaceholderHint(
                text: 'Pick a primer brand to see available products.',
              )
            else if (_selectedBrand == _customSentinel)
              TextFormField(
                controller: _customController,
                onChanged: _onCustomTextChanged,
                decoration: const InputDecoration(
                  labelText: 'Custom Primer',
                  helperText: 'Type the brand and model, e.g. "Murom KVB-7"',
                ),
              )
            else
              FutureBuilder<List<PrimerRow>>(
                future: _futureProducts,
                builder: (context, prodSnap) {
                  if (prodSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    );
                  }
                  final products = prodSnap.data ?? const <PrimerRow>[];
                  PrimerRow? selected;
                  for (final p in products) {
                    if (p.name == _selectedPrimerName) {
                      selected = p;
                      break;
                    }
                  }
                  return DropdownButtonFormField<PrimerRow>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Primer Product',
                    ),
                    items: [
                      for (final p in products)
                        DropdownMenuItem<PrimerRow>(
                          value: p,
                          child: Text(
                            ComponentRepository.primerProductLabel(p),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _onProductChanged,
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _PlaceholderHint extends StatelessWidget {
  const _PlaceholderHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
