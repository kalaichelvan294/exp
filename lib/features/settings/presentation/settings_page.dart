import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/module_scaffold.dart';
import '../../../core/theme/app_tokens.dart';
import '../../billing/domain/billing_enums.dart';
import '../../billing/presentation/widgets/app_card.dart';
import '../application/settings_controller.dart';
import '../application/settings_state.dart';

/// Settings module (Phase 5). Ports settings.js: store profile, print language,
/// UPI, payment options, appearance, inventory control, and item configuration
/// (categories/brands + wholesale auto-apply), each saved independently.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _storeName = TextEditingController();
  final _businessType = TextEditingController();
  final _storeAddress = TextEditingController();
  final _fssai = TextEditingController();
  final _upiId = TextEditingController();
  final _upiDisplayName = TextEditingController();
  final _categoryInput = TextEditingController();
  final _brandInput = TextEditingController();

  String _printLanguage = 'en';
  String _uiSizeVariant = 'md';
  String _themeMode = 'light';
  bool _invEnabled = false;
  bool _wholesaleAutoApply = true;
  final Set<PaymentMode> _paymentModes = {};
  bool _synced = false;

  @override
  void dispose() {
    _storeName.dispose();
    _businessType.dispose();
    _storeAddress.dispose();
    _fssai.dispose();
    _upiId.dispose();
    _upiDisplayName.dispose();
    _categoryInput.dispose();
    _brandInput.dispose();
    super.dispose();
  }

  SettingsController get _c =>
      ref.read(settingsControllerProvider.notifier);

  void _syncFromState(SettingsState state) {
    final s = state.settings;
    _storeName.text = s.storeName;
    _businessType.text = s.businessType;
    _storeAddress.text = s.storeAddress;
    _fssai.text = s.fssaiNumber;
    _upiId.text = s.upiId;
    _upiDisplayName.text = s.upiDisplayName;
    _printLanguage = s.printLanguage;
    _uiSizeVariant = s.uiSizeVariant;
    _themeMode = s.themeMode;
    _invEnabled = state.invControlEnabled;
    _wholesaleAutoApply = s.itemsWholesaleAutoApply;
    _paymentModes
      ..clear()
      ..addAll(s.billingPaymentModes);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsControllerProvider);
    if (state.loaded && !_synced) {
      _synced = true;
      _syncFromState(state);
    }

    return ModuleScaffold(
      title: 'Settings',
      description:
          'Store profile, receipt, payment, inventory, and appearance settings.',
      child: !state.loaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!state.message.isEmpty) _MessageBanner(message: state.message),
                  _storeProfileCard(),
                  const SizedBox(height: AppSpacing.x16),
                  _printCard(),
                  const SizedBox(height: AppSpacing.x16),
                  _upiCard(),
                  const SizedBox(height: AppSpacing.x16),
                  _paymentCard(),
                  const SizedBox(height: AppSpacing.x16),
                  _appearanceCard(),
                  const SizedBox(height: AppSpacing.x16),
                  _inventoryCard(),
                  const SizedBox(height: AppSpacing.x16),
                  _itemConfigCard(state),
                ],
              ),
            ),
    );
  }

  // ── Store profile ─────────────────────────────────────────────────────────
  Widget _storeProfileCard() {
    return _SectionCard(
      title: 'Store Profile',
      onReset: () {
        _c.clearMessage();
        setState(() => _syncFromState(ref.read(settingsControllerProvider)));
      },
      onSave: () => _c.saveStoreProfile(
        storeName: _storeName.text,
        businessType: _businessType.text,
        storeAddress: _storeAddress.text,
        fssaiNumber: _fssai.text,
      ),
      children: [
        _field('Store Name', _storeName),
        _field('Business Type', _businessType),
        _field('Store Address', _storeAddress),
        _field('FSSAI Number', _fssai),
      ],
    );
  }

  // ── Print language ────────────────────────────────────────────────────────
  Widget _printCard() {
    return _SectionCard(
      title: 'Print Language',
      onReset: () {
        _c.clearMessage();
        setState(() => _printLanguage =
            ref.read(settingsControllerProvider).settings.printLanguage);
      },
      onSave: () => _c.savePrintLanguage(_printLanguage),
      children: [
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<String>(
            initialValue: _printLanguage,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Receipt Language'),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ta', child: Text('Tamil (தமிழ்)')),
            ],
            onChanged: (v) => setState(() => _printLanguage = v ?? 'en'),
          ),
        ),
      ],
    );
  }

  // ── UPI ───────────────────────────────────────────────────────────────────
  Widget _upiCard() {
    return _SectionCard(
      title: 'UPI Payment',
      onReset: () {
        _c.clearMessage();
        final s = ref.read(settingsControllerProvider).settings;
        setState(() {
          _upiId.text = s.upiId;
          _upiDisplayName.text = s.upiDisplayName;
        });
      },
      onSave: () => _c.saveUpi(
        upiId: _upiId.text,
        displayName: _upiDisplayName.text,
      ),
      children: [
        _field('UPI ID', _upiId),
        _field('Display Name', _upiDisplayName),
      ],
    );
  }

  // ── Payment options ───────────────────────────────────────────────────────
  Widget _paymentCard() {
    Widget modeCheckbox(PaymentMode mode, String label) {
      return SizedBox(
        width: 160,
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          title: Text(label),
          value: _paymentModes.contains(mode),
          onChanged: (checked) => setState(() {
            if (checked == true) {
              _paymentModes.add(mode);
            } else {
              _paymentModes.remove(mode);
            }
          }),
        ),
      );
    }

    return _SectionCard(
      title: 'Payment Options',
      onReset: () {
        _c.clearMessage();
        setState(() {
          _paymentModes
            ..clear()
            ..addAll(ref
                .read(settingsControllerProvider)
                .settings
                .billingPaymentModes);
        });
      },
      onSave: () => _c.savePaymentModes(_paymentModes.toList()),
      children: [
        modeCheckbox(PaymentMode.cash, 'Cash'),
        modeCheckbox(PaymentMode.gpay, 'GPay'),
        modeCheckbox(PaymentMode.card, 'Card'),
      ],
    );
  }

  // ── Appearance ────────────────────────────────────────────────────────────
  Widget _appearanceCard() {
    return _SectionCard(
      title: 'Appearance',
      onReset: () {
        _c.clearMessage();
        final s = ref.read(settingsControllerProvider).settings;
        setState(() {
          _uiSizeVariant = s.uiSizeVariant;
          _themeMode = s.themeMode;
        });
      },
      onSave: () => _c.saveAppearance(
        uiSizeVariant: _uiSizeVariant,
        themeMode: _themeMode,
      ),
      children: [
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<String>(
            initialValue: _uiSizeVariant,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'UI Size'),
            items: const [
              DropdownMenuItem(value: 'xs', child: Text('Extra Compact')),
              DropdownMenuItem(value: 'sm', child: Text('Compact')),
              DropdownMenuItem(value: 'md', child: Text('Comfortable')),
              DropdownMenuItem(value: 'lg', child: Text('Large')),
              DropdownMenuItem(value: 'xl', child: Text('Extra Large')),
              DropdownMenuItem(value: 'xxl', child: Text('Maximum Large')),
            ],
            onChanged: (v) => setState(() => _uiSizeVariant = v ?? 'md'),
          ),
        ),
        SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Theme', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.x4),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'light',
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode, size: 16)),
                  ButtonSegment(
                      value: 'dark',
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode, size: 16)),
                ],
                selected: {_themeMode},
                onSelectionChanged: (s) =>
                    setState(() => _themeMode = s.first),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Inventory control ─────────────────────────────────────────────────────
  Widget _inventoryCard() {
    return _SectionCard(
      title: 'Inventory Control',
      onReset: () {
        _c.clearMessage();
        setState(() => _invEnabled =
            ref.read(settingsControllerProvider).invControlEnabled);
      },
      onSave: () => _c.saveInventoryControl(_invEnabled),
      children: [
        SizedBox(
          width: 320,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Enable inventory tracking'),
            value: _invEnabled,
            onChanged: (v) => setState(() => _invEnabled = v),
          ),
        ),
      ],
    );
  }

  // ── Item configuration ────────────────────────────────────────────────────
  Widget _itemConfigCard(SettingsState state) {
    return _SectionCard(
      title: 'Item Configuration',
      onReset: () {
        _c.clearMessage();
        _c.resetItemConfig();
        setState(() => _wholesaleAutoApply =
            ref.read(settingsControllerProvider).settings.itemsWholesaleAutoApply);
      },
      onSave: () => _c.saveItemConfig(wholesaleAutoApply: _wholesaleAutoApply),
      childrenAlignment: CrossAxisAlignment.stretch,
      fullWidthChildren: true,
      children: [
        Text('Categories', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.x8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _categoryInput,
                decoration:
                    const InputDecoration(hintText: 'Add category (e.g. GROCERY)'),
                onSubmitted: (v) {
                  _c.addCategory(v);
                  _categoryInput.clear();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.x8),
            FilledButton(
              onPressed: () {
                _c.addCategory(_categoryInput.text);
                _categoryInput.clear();
              },
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x8),
        _ChipWrap(
          lockedFirst: 'OTHER',
          items: state.categories,
          onRemove: _c.removeCategory,
          emptyText: 'No categories configured.',
        ),
        const SizedBox(height: AppSpacing.x20),
        Row(
          children: [
            Expanded(
                child: Text('Brands',
                    style: Theme.of(context).textTheme.titleMedium)),
            OutlinedButton.icon(
              onPressed: _c.propagateBrands,
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('Propagate from catalog'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _brandInput,
                decoration:
                    const InputDecoration(hintText: 'Add brand (e.g. ACME)'),
                onSubmitted: (v) {
                  _c.addBrand(v);
                  _brandInput.clear();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.x8),
            FilledButton(
              onPressed: () {
                _c.addBrand(_brandInput.text);
                _brandInput.clear();
              },
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x8),
        _ChipWrap(
          items: state.brands,
          onRemove: _c.removeBrand,
          emptyText: 'No brands configured.',
        ),
        const SizedBox(height: AppSpacing.x20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Auto-apply wholesale pricing'),
          value: _wholesaleAutoApply,
          onChanged: (v) => setState(() => _wholesaleAutoApply = v),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return SizedBox(
      width: 320,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message});
  final SettingsMessage message;

  @override
  Widget build(BuildContext context) {
    final color = message.isError
        ? AppColors.error500
        : message.isSuccess
            ? AppColors.success500
            : AppColors.neutral500;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x16),
      child: Text(message.text,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    required this.onSave,
    required this.onReset,
    this.childrenAlignment = CrossAxisAlignment.start,
    this.fullWidthChildren = false,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final VoidCallback onReset;
  final CrossAxisAlignment childrenAlignment;
  final bool fullWidthChildren;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.x16),
          if (fullWidthChildren)
            Column(crossAxisAlignment: childrenAlignment, children: children)
          else
            Wrap(
              spacing: AppSpacing.x16,
              runSpacing: AppSpacing.x16,
              children: children,
            ),
          const SizedBox(height: AppSpacing.x16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: onReset, child: const Text('Reset')),
              const SizedBox(width: AppSpacing.x8),
              FilledButton(onPressed: onSave, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({
    required this.items,
    required this.onRemove,
    required this.emptyText,
    this.lockedFirst,
  });

  final List<String> items;
  final ValueChanged<String> onRemove;
  final String emptyText;
  final String? lockedFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];
    if (lockedFirst != null) {
      chips.add(Chip(
        label: Text(lockedFirst!),
        avatar: const Icon(Icons.lock, size: 14),
      ));
    }
    for (final item in items) {
      chips.add(Chip(
        label: Text(item),
        onDeleted: () => onRemove(item),
      ));
    }
    if (chips.isEmpty) {
      return Text(emptyText,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.neutral500));
    }
    return Wrap(
      spacing: AppSpacing.x8,
      runSpacing: AppSpacing.x8,
      children: chips,
    );
  }
}
