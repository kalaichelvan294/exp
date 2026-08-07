import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../billing/domain/billing_enums.dart';
import '../../../billing/domain/money.dart';
import '../../application/items_controller.dart';
import '../../domain/item.dart';
import '../../domain/item_form.dart';

/// Add/Edit item modal. Ports the Electron item modal: required-field gating,
/// live (debounced) SKU validation, wholesale price/min-qty pairing, and the
/// WEIGHT rate hint.
class ItemFormDialog extends ConsumerStatefulWidget {
  const ItemFormDialog({super.key, this.item});

  /// When non-null, the dialog edits an existing item.
  final Item? item;

  @override
  ConsumerState<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends ConsumerState<ItemFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _nameTa;
  late final TextEditingController _sku;
  late final TextEditingController _retail;
  late final TextEditingController _wholesale;
  late final TextEditingController _wholesaleMinQty;

  String _category = 'OTHER';
  String _brand = '';
  PricingType _pricingType = PricingType.unit;

  ItemsController get _c => ref.read(itemsControllerProvider.notifier);

  bool get _isEditing => widget.item != null;
  String get _editingId => widget.item?.id ?? '';

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _nameTa = TextEditingController(text: item?.nameTa ?? '');
    _sku = TextEditingController(text: item?.sku ?? '');
    _retail = TextEditingController(
        text: item != null ? Money.toRupees(item.retailPricePaise) : '');
    _wholesale = TextEditingController(
        text: item?.wholesalePricePaise != null
            ? Money.toRupees(item!.wholesalePricePaise!)
            : '');
    _wholesaleMinQty = TextEditingController(
        text: item?.wholesaleMinQty != null
            ? _trimNum(item!.wholesaleMinQty!)
            : '');
    _category = item?.category ?? 'OTHER';
    _brand = item?.brandName ?? '';
    _pricingType = item?.pricingType ?? PricingType.unit;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.resetSkuValidation();
      if (_isEditing) {
        _c.scheduleSkuValidation(_sku.text, excludeItemId: _editingId);
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _nameTa.dispose();
    _sku.dispose();
    _retail.dispose();
    _wholesale.dispose();
    _wholesaleMinQty.dispose();
    super.dispose();
  }

  String _trimNum(num value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  ItemFormData _formData() => ItemFormData(
        name: _name.text,
        nameTa: _nameTa.text,
        category: _category,
        brandName: _brand,
        sku: _sku.text,
        pricingType: _pricingType,
        retailPriceInput: _retail.text,
        wholesalePriceInput: _wholesale.text,
        wholesaleMinQtyInput: _wholesaleMinQty.text,
      );

  bool get _hasRequiredFields {
    final retail = Money.parseInrToPaise(_retail.text);
    return _name.text.trim().isNotEmpty &&
        _category.trim().isNotEmpty &&
        ItemFormData.normalizeSku(_sku.text).isNotEmpty &&
        retail > 0;
  }

  void _onSkuChanged(String value) {
    final normalized = ItemFormData.normalizeSku(value);
    if (normalized != value) {
      _sku.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    _c.scheduleSkuValidation(normalized, excludeItemId: _editingId);
    setState(() {});
  }

  Future<void> _submit() async {
    final ok = await _c.saveItem(_formData(), editingItemId: _editingId);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemsControllerProvider);
    final theme = Theme.of(context);
    final canSubmit =
        _hasRequiredFields && state.skuValidation.valid && !state.submitting;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEditing ? 'Edit Item' : 'Add Item',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.x20),
              _field('Name', _name, onChanged: (_) => setState(() {})),
              _field('Tamil Name (optional)', _nameTa),
              _dropdown<String>(
                label: 'Category',
                value: _categoryOptions.contains(_category)
                    ? _category
                    : _categoryOptions.first,
                options: _categoryOptions,
                labelFor: (c) => c,
                onChanged: (v) => setState(() => _category = v ?? 'OTHER'),
              ),
              _dropdown<String>(
                label: 'Brand',
                value: _brandOptions.contains(_brand) ? _brand : '',
                options: _brandOptions,
                labelFor: (b) => b.isEmpty ? '— None —' : b,
                onChanged: (v) => setState(() => _brand = v ?? ''),
              ),
              _skuField(state, theme),
              _dropdown<PricingType>(
                label: 'Pricing Type',
                value: _pricingType,
                options: PricingType.values,
                labelFor: (p) => p.wire,
                onChanged: (v) =>
                    setState(() => _pricingType = v ?? PricingType.unit),
              ),
              _field(
                _pricingType == PricingType.weight
                    ? 'Retail Rate (₹ per kg)'
                    : 'Retail Rate (₹)',
                _retail,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              _field('Wholesale Price (₹, optional)', _wholesale,
                  keyboard:
                      const TextInputType.numberWithOptions(decimal: true)),
              _field('Wholesale Min Qty (optional)', _wholesaleMinQty,
                  keyboard:
                      const TextInputType.numberWithOptions(decimal: true)),
              if (state.message.isError) ...[
                const SizedBox(height: AppSpacing.x8),
                Text(state.message.text,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.error500)),
              ],
              const SizedBox(height: AppSpacing.x24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.x8),
                  FilledButton(
                    onPressed: canSubmit ? _submit : null,
                    child: Text(_isEditing ? 'Update Item' : 'Add Item'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> get _categoryOptions {
    final options = <String>['OTHER', ...ref.read(itemsControllerProvider).categories];
    if (_category.trim().isNotEmpty && !options.contains(_category)) {
      options.add(_category);
    }
    return options;
  }

  List<String> get _brandOptions {
    final options = <String>['', ...ref.read(itemsControllerProvider).brands];
    if (_brand.trim().isNotEmpty && !options.contains(_brand)) {
      options.add(_brand);
    }
    return options;
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x16),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _skuField(dynamic state, ThemeData theme) {
    final validation = state.skuValidation;
    final showMsg = validation.message.toString().isNotEmpty;
    final color = validation.valid ? AppColors.success500 : AppColors.error500;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _sku,
            textCapitalization: TextCapitalization.characters,
            onChanged: _onSkuChanged,
            decoration: const InputDecoration(labelText: 'SKU'),
          ),
          if (showMsg)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x4),
              child: Text(validation.message,
                  style: theme.textTheme.bodySmall?.copyWith(color: color)),
            ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> options,
    required String Function(T) labelFor,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x16),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: options
            .map((o) => DropdownMenuItem<T>(value: o, child: Text(labelFor(o))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
