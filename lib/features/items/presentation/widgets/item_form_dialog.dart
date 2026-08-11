import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/images/item_image_path.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../billing/domain/billing_enums.dart';
import '../../../billing/domain/money.dart';
import '../../../settings/application/settings_controller.dart';
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
  late final TextEditingController _barcode;
  late final TextEditingController _retail;
  late final TextEditingController _wholesale;
  late final TextEditingController _wholesaleMinQty;

  String _category = 'OTHER';
  String _brand = '';
  PricingType _pricingType = PricingType.unit;
  String _selectedImagePath = '';
  String _persistedImageSku = '';
  String _persistedImagePath = '';

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
    _barcode = TextEditingController(text: item?.barcode ?? '');
    _retail = TextEditingController(
      text: item != null ? Money.toRupees(item.retailPricePaise) : '',
    );
    _wholesale = TextEditingController(
      text: item?.wholesalePricePaise != null
          ? Money.toRupees(item!.wholesalePricePaise!)
          : '',
    );
    _wholesaleMinQty = TextEditingController(
      text: item?.wholesaleMinQty != null
          ? _trimNum(item!.wholesaleMinQty!)
          : '',
    );
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
    _barcode.dispose();
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
    barcode: _barcode.text,
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
    if (_persistedImageSku.isNotEmpty && _persistedImageSku != normalized) {
      _persistedImageSku = '';
      _persistedImagePath = '';
    }
    _c.scheduleSkuValidation(normalized, excludeItemId: _editingId);
    setState(() {});
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final path = picked.path?.trim() ?? '';
    if (path.isEmpty) return;
    final lower = path.toLowerCase();
    if (!(lower.endsWith('.jpg') || lower.endsWith('.jpeg'))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only JPG images are allowed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _selectedImagePath = path);

    final sku = ItemFormData.normalizeSku(_sku.text);
    if (sku.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image selected. Set SKU to save it as <SKU>_master.jpg.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final settings = ref.read(settingsControllerProvider).settings;
    final ok = await _c.savePickedImage(
      sku: sku,
      selectedImagePath: path,
      itemImagesRootPath: settings.itemImagesRootPath,
    );
    if (ok) {
      _persistedImageSku = sku;
      _persistedImagePath = path;
    }
  }

  Future<void> _submit() async {
    final settings = ref.read(settingsControllerProvider).settings;
    final sku = ItemFormData.normalizeSku(_sku.text);
    final shouldSkipImageCopy =
        _selectedImagePath.trim().isNotEmpty &&
        _persistedImagePath == _selectedImagePath &&
        _persistedImageSku == sku;
    final ok = await _c.saveItem(
      _formData(),
      editingItemId: _editingId,
      selectedImagePath: shouldSkipImageCopy ? '' : _selectedImagePath,
      itemImagesRootPath: settings.itemImagesRootPath,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemsControllerProvider);
    final settings = ref.watch(settingsControllerProvider).settings;
    final config = ref.watch(appConfigProvider);
    final canSubmit =
        _hasRequiredFields && state.skuValidation.valid && !state.submitting;

    final normalizedSku = ItemFormData.normalizeSku(_sku.text);
    final effectiveSku = normalizedSku.isNotEmpty
        ? normalizedSku
        : ItemFormData.normalizeSku(widget.item?.sku ?? '');
    final image = ItemImagePath.resolve(
      sku: effectiveSku.isEmpty ? 'ITEM' : effectiveSku,
      configuredRootPath: settings.itemImagesRootPath,
      fallbackHost: config.databaseHost,
    );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit Item' : 'Add Item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.x20),
              _imagePanel(image),
              const SizedBox(height: AppSpacing.x16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoCols = constraints.maxWidth >= 760;
                  if (!twoCols) {
                    return Column(
                      children: [
                        _basicSection(state),
                        const SizedBox(height: AppSpacing.x16),
                        _pricingSection(),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _basicSection(state)),
                      const SizedBox(width: AppSpacing.x16),
                      Expanded(child: _pricingSection()),
                    ],
                  );
                },
              ),
              if (state.message.isError) ...[
                const SizedBox(height: AppSpacing.x8),
                Text(
                  state.message.text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.error500),
                ),
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

  Widget _imagePanel(ItemImageLocation image) {
    final selectedName = _selectedImagePath.trim().isEmpty
        ? null
        : _selectedImagePath.split(RegExp(r'[\\\/]')).last;
    return _sectionCard(
      title: 'Item Image',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: AppRadius.input,
              child: _selectedImagePath.trim().isNotEmpty
                  ? Image.file(
                      File(_selectedImagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) => _missingImage(),
                    )
                  : _imageWidget(image),
            ),
          ),
          const SizedBox(height: AppSpacing.x8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(
                  _selectedImagePath.isEmpty ? 'Choose JPG' : 'Change JPG',
                ),
              ),
              const SizedBox(width: AppSpacing.x8),
              Expanded(
                child: Text(
                  selectedName ??
                      'Final filename: ${ItemImagePath.fileNameForSku(ItemFormData.normalizeSku(_sku.text).isEmpty ? 'SKU' : ItemFormData.normalizeSku(_sku.text))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.neutral600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageWidget(ItemImageLocation image) {
    if (image.filePath != null && image.filePath!.trim().isNotEmpty) {
      return Image.file(
        File(image.filePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => _missingImage(),
      );
    }
    if (image.networkUrl != null && image.networkUrl!.trim().isNotEmpty) {
      return Image.network(
        image.networkUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => _missingImage(),
      );
    }
    return _missingImage();
  }

  Widget _missingImage() => Container(
    color: AppColors.neutral100,
    alignment: Alignment.center,
    child: const Text('No image'),
  );

  Widget _basicSection(dynamic state) {
    return _sectionCard(
      title: 'Basic Details',
      child: Column(
        children: [
          _field('Name', _name, onChanged: (_) => setState(() {})),
          _field('Tamil Name (optional)', _nameTa),
          _skuField(state),
          _field('Barcode (optional)', _barcode),
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
        ],
      ),
    );
  }

  Widget _pricingSection() {
    return _sectionCard(
      title: 'Pricing',
      child: Column(
        children: [
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
          _field(
            'Wholesale Price (₹, optional)',
            _wholesale,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _field(
            'Wholesale Min Qty (optional)',
            _wholesaleMinQty,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x16),
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.x12),
          child,
        ],
      ),
    );
  }

  List<String> get _categoryOptions {
    final options = <String>[
      'OTHER',
      ...ref.read(itemsControllerProvider).categories,
    ];
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
      padding: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _skuField(dynamic state) {
    final validation = state.skuValidation;
    final showMsg = validation.message.toString().isNotEmpty;
    final color = validation.valid ? AppColors.success500 : AppColors.error500;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x12),
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
              child: Text(
                validation.message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: color),
              ),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.x12),
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
