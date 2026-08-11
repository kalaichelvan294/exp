import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/module_scaffold.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/section_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../billing/domain/billing_enums.dart';
import '../../../shared/widgets/app_card.dart';
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
  final _itemImagesRootPath = TextEditingController();

  String _printLanguage = 'en';
  String _uiSizeVariant = 'md';
  String _themeMode = 'light';
  int _adminTimeoutSeconds = 300;
  bool _invEnabled = false;
  bool _wholesaleAutoApply = true;
  bool _cleanupTrainingImagesAfterEmbedding = false;
  final Set<PaymentMode> _paymentModes = {};
  _SettingsSection _activeSection = _SettingsSection.storeProfile;
  bool _adminTimeoutDirty = false;
  bool _synced = false;
  bool _downloadingExceptionLog = false;

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
    _itemImagesRootPath.dispose();
    super.dispose();
  }

  SettingsController get _c => ref.read(settingsControllerProvider.notifier);

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
    _cleanupTrainingImagesAfterEmbedding =
        state.cleanupTrainingImagesAfterEmbedding;
    _itemImagesRootPath.text = s.itemImagesRootPath;
    _paymentModes
      ..clear()
      ..addAll(s.billingPaymentModes);
  }

  int _normalizeTimeoutSeconds(int value) {
    if (value < 30) return 30;
    return value;
  }

  Color _toastColor(SettingsMessage message) {
    if (message.isError) return AppColors.error500;
    if (message.isSuccess) return AppColors.success500;
    return AppColors.neutral700;
  }

  void _showToast(SettingsMessage message) {
    if (message.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message.text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _toastColor(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsControllerProvider);
    final authState = ref.watch(authControllerProvider);
    ref.listen<SettingsMessage>(
      settingsControllerProvider.select((s) => s.message),
      (previous, next) {
        if (next.isEmpty) return;
        if (previous != null &&
            previous.text == next.text &&
            previous.type == next.type) {
          return;
        }
        _showToast(next);
      },
    );
    if (state.loaded && !_synced) {
      _synced = true;
      _syncFromState(state);
    }
    if (!_adminTimeoutDirty) {
      _adminTimeoutSeconds = _normalizeTimeoutSeconds(
        authState.timeout.inSeconds,
      );
    }

    return ModuleScaffold(
      child: Stack(
        children: [
          !state.loaded
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 240,
                      child: _SettingsNav(
                        active: _activeSection,
                        onSelected: (section) => setState(() {
                          _activeSection = section;
                        }),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [_activeSectionCard(state)],
                        ),
                      ),
                    ),
                  ],
                ),
          if (state.embeddingRefreshDialogVisible)
            _embeddingRefreshOverlay(state),
        ],
      ),
    );
  }

  Widget _activeSectionCard(SettingsState state) {
    switch (_activeSection) {
      case _SettingsSection.storeProfile:
        return _storeProfileCard();
      case _SettingsSection.printLanguage:
        return _printCard();
      case _SettingsSection.upiPayment:
        return _upiCard();
      case _SettingsSection.paymentOptions:
        return _paymentCard();
      case _SettingsSection.appearance:
        return _appearanceCard();
      case _SettingsSection.adminSession:
        return _adminSessionCard();
      case _SettingsSection.inventoryControl:
        return _inventoryCard();
      case _SettingsSection.itemConfiguration:
        return _itemConfigCard(state);
      case _SettingsSection.helpAndShortcuts:
        return _helpAndShortcutsCard();
    }
  }

  // ── Store profile ─────────────────────────────────────────────────────────
  Widget _storeProfileCard() {
    return SectionCard(
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
        _field(
          'Store Name',
          _storeName,
          onChanged: (_) => _c.previewStoreProfile(
            storeName: _storeName.text,
            businessType: _businessType.text,
            storeAddress: _storeAddress.text,
            fssaiNumber: _fssai.text,
          ),
        ),
        _field(
          'Business Type',
          _businessType,
          onChanged: (_) => _c.previewStoreProfile(
            storeName: _storeName.text,
            businessType: _businessType.text,
            storeAddress: _storeAddress.text,
            fssaiNumber: _fssai.text,
          ),
        ),
        _field(
          'Store Address',
          _storeAddress,
          onChanged: (_) => _c.previewStoreProfile(
            storeName: _storeName.text,
            businessType: _businessType.text,
            storeAddress: _storeAddress.text,
            fssaiNumber: _fssai.text,
          ),
        ),
        _field(
          'FSSAI Number',
          _fssai,
          onChanged: (_) => _c.previewStoreProfile(
            storeName: _storeName.text,
            businessType: _businessType.text,
            storeAddress: _storeAddress.text,
            fssaiNumber: _fssai.text,
          ),
        ),
      ],
    );
  }

  // ── Print language ────────────────────────────────────────────────────────
  Widget _printCard() {
    return SectionCard(
      title: 'Print Language',
      onReset: () {
        _c.clearMessage();
        setState(
          () => _printLanguage = ref
              .read(settingsControllerProvider)
              .settings
              .printLanguage,
        );
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
            onChanged: (v) {
              final next = v ?? 'en';
              setState(() => _printLanguage = next);
              _c.previewPrintLanguage(next);
            },
          ),
        ),
      ],
    );
  }

  // ── UPI ───────────────────────────────────────────────────────────────────
  Widget _upiCard() {
    return SectionCard(
      title: 'UPI Payment',
      onReset: () {
        _c.clearMessage();
        final s = ref.read(settingsControllerProvider).settings;
        setState(() {
          _upiId.text = s.upiId;
          _upiDisplayName.text = s.upiDisplayName;
        });
      },
      onSave: () =>
          _c.saveUpi(upiId: _upiId.text, displayName: _upiDisplayName.text),
      children: [
        _field(
          'UPI ID',
          _upiId,
          onChanged: (_) => _c.previewUpi(
            upiId: _upiId.text,
            displayName: _upiDisplayName.text,
          ),
        ),
        _field(
          'Display Name',
          _upiDisplayName,
          onChanged: (_) => _c.previewUpi(
            upiId: _upiId.text,
            displayName: _upiDisplayName.text,
          ),
        ),
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
            _c.previewPaymentModes(_paymentModes.toList());
          }),
        ),
      );
    }

    return SectionCard(
      title: 'Payment Options',
      onReset: () {
        _c.clearMessage();
        setState(() {
          _paymentModes
            ..clear()
            ..addAll(
              ref.read(settingsControllerProvider).settings.billingPaymentModes,
            );
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
    return SectionCard(
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
            onChanged: (v) {
              final next = v ?? 'md';
              setState(() => _uiSizeVariant = next);
              _c.previewAppearance(themeMode: _themeMode, uiSizeVariant: next);
            },
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
                    icon: Icon(Icons.light_mode, size: 16),
                  ),
                  ButtonSegment(
                    value: 'dark',
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode, size: 16),
                  ),
                ],
                selected: {_themeMode},
                onSelectionChanged: (s) {
                  final next = s.first;
                  setState(() => _themeMode = next);
                  _c.previewAppearance(
                    themeMode: next,
                    uiSizeVariant: _uiSizeVariant,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Admin session ──────────────────────────────────────────────────────────
  Widget _adminSessionCard() {
    final timeoutOptions = <int>[
      30,
      60,
      120,
      180,
      300,
      600,
      900,
      1200,
      1800,
      2700,
      3600,
    ];
    if (!timeoutOptions.contains(_adminTimeoutSeconds)) {
      timeoutOptions.add(_adminTimeoutSeconds);
      timeoutOptions.sort();
    }
    String labelFor(int seconds) {
      if (seconds < 60) return '$seconds seconds';
      final minutes = seconds ~/ 60;
      return '$minutes minute${minutes == 1 ? '' : 's'}';
    }

    return SectionCard(
      title: 'Admin Session',
      onReset: () {
        _c.clearMessage();
        final current = ref.read(authControllerProvider).timeout.inSeconds;
        setState(() {
          _adminTimeoutDirty = false;
          _adminTimeoutSeconds = _normalizeTimeoutSeconds(current);
        });
      },
      onSave: () async {
        try {
          await ref
              .read(authControllerProvider.notifier)
              .setSessionTimeout(Duration(seconds: _adminTimeoutSeconds));
          _c.showSuccess('Admin session timeout saved successfully!');
          if (!mounted) return;
          setState(() => _adminTimeoutDirty = false);
        } catch (e) {
          _c.showError('Failed to save admin session timeout: $e');
        }
      },
      children: [
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<int>(
            key: ValueKey(_adminTimeoutSeconds),
            initialValue: _adminTimeoutSeconds,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Auto-logout timeout'),
            items: timeoutOptions
                .map(
                  (seconds) => DropdownMenuItem<int>(
                    value: seconds,
                    child: Text(labelFor(seconds)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _adminTimeoutDirty = true;
                _adminTimeoutSeconds = value;
              });
            },
          ),
        ),
      ],
    );
  }

  // ── Inventory control ─────────────────────────────────────────────────────
  Widget _inventoryCard() {
    return SectionCard(
      title: 'Inventory Control',
      onReset: () {
        _c.clearMessage();
        setState(
          () => _invEnabled = ref
              .read(settingsControllerProvider)
              .invControlEnabled,
        );
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
            onChanged: (v) => setState(() {
              _invEnabled = v;
              _c.previewInventoryControl(v);
            }),
          ),
        ),
      ],
    );
  }

  // ── Item configuration ────────────────────────────────────────────────────
  Widget _itemConfigCard(SettingsState state) {
    return SectionCard(
      title: 'Item Configuration',
      onReset: () {
        _c.clearMessage();
        _c.resetItemConfig();
        setState(() {
          final settings = ref.read(settingsControllerProvider).settings;
          _wholesaleAutoApply = settings.itemsWholesaleAutoApply;
          _cleanupTrainingImagesAfterEmbedding = false;
          _itemImagesRootPath.text = settings.itemImagesRootPath;
        });
        _c.previewEmbeddingCleanup(false);
      },
      onSave: () => _c.saveItemConfig(
        wholesaleAutoApply: _wholesaleAutoApply,
        itemImagesRootPath: _itemImagesRootPath.text,
      ),
      childrenAlignment: CrossAxisAlignment.stretch,
      fullWidthChildren: true,
      children: [
        SizedBox(
          width: 560,
          child: TextField(
            controller: _itemImagesRootPath,
            decoration: const InputDecoration(
              labelText: 'Item Images Root Path',
              hintText: r'e.g. C:\POS\images or http://localhost:3000/images',
            ),
            onChanged: (_) => _c.previewItemConfig(
              wholesaleAutoApply: _wholesaleAutoApply,
              itemImagesRootPath: _itemImagesRootPath.text,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x6),
        Text(
          'Training images use <SKU>_MASTER plus _1 through _5 in JPG, JPEG, or PNG format.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.neutral500),
        ),
        const SizedBox(height: AppSpacing.x20),
        Text(
          'Image Embeddings',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.x8),
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: const Text(
                  'Delete numbered training images after indexing',
                ),
                subtitle: const Text('Keeps the master image in place.'),
                value: _cleanupTrainingImagesAfterEmbedding,
                onChanged: (v) => setState(() {
                  _cleanupTrainingImagesAfterEmbedding = v ?? false;
                  _c.previewEmbeddingCleanup(
                    _cleanupTrainingImagesAfterEmbedding,
                  );
                }),
              ),
            ),
            const SizedBox(width: AppSpacing.x12),
            FilledButton.icon(
              onPressed: state.embeddingRefreshRunning
                  ? null
                  : _c.refreshImageEmbeddings,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                state.embeddingRefreshRunning
                    ? 'Refreshing...'
                    : 'Refresh embeddings',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x20),
        Text('Categories', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.x8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _categoryInput,
                decoration: const InputDecoration(
                  hintText: 'Add category (e.g. GROCERY)',
                ),
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
              child: Text(
                'Brands',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
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
                decoration: const InputDecoration(
                  hintText: 'Add brand (e.g. ACME)',
                ),
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
          onChanged: (v) => setState(() {
            _wholesaleAutoApply = v;
            _c.previewItemConfig(
              wholesaleAutoApply: v,
              itemImagesRootPath: _itemImagesRootPath.text,
            );
          }),
        ),
      ],
    );
  }

  Widget _embeddingRefreshOverlay(SettingsState state) {
    final total = state.embeddingTotalProducts;
    final processed = state.embeddingProcessedProducts;
    final progress = total > 0 ? (processed / total).clamp(0.0, 1.0) : null;
    final isRunning = state.embeddingRefreshRunning;
    final stage = state.embeddingCurrentStage;
    final sku = state.embeddingCurrentSku;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black45,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Embedding Refresh',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.x12),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: AppSpacing.x12),
                  Text(
                    'Processed $processed of $total products',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (stage.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x4),
                    Text('Stage: $stage'),
                  ],
                  if (sku.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x4),
                    Text('SKU: $sku'),
                  ],
                  const SizedBox(height: AppSpacing.x8),
                  Text(
                    'Indexed products: ${state.embeddingProductsIndexed} | '
                    'Images: ${state.embeddingImagesIndexed} | '
                    'Skipped: ${state.embeddingProductsSkipped} | '
                    'Barcode updates: ${state.embeddingBarcodeUpdates}',
                  ),
                  if (state.embeddingResult.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x12),
                    Text(state.embeddingResult),
                  ],
                  const SizedBox(height: AppSpacing.x16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _c.closeEmbeddingRefreshDialog,
                      child: Text(isRunning ? 'Cancel and Close' : 'Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      width: 320,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }

  Widget _helpAndShortcutsCard() {
    return SectionCard(
      title: 'Help & Shortcuts',
      onSave: () {},
      onReset: () {},
      fullWidthChildren: true,
      showActions: false,
      childrenAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Settings Page Help',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.x12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _downloadingExceptionLog
                ? null
                : () async {
                    setState(() => _downloadingExceptionLog = true);
                    try {
                      await _c.downloadExceptionLogFile();
                    } finally {
                      if (mounted) {
                        setState(() => _downloadingExceptionLog = false);
                      }
                    }
                  },
            icon: const Icon(Icons.download, size: 16),
            label: Text(
              _downloadingExceptionLog
                  ? 'Downloading...'
                  : 'Download exception log',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x8),
        Text(
          'Use the left-side navigation to move between sections. '
          'Each section saves independently. Reset restores the section '
          'to the last saved values.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.x12),
        const Text(
          'Store Profile: Store Name, Business Type, Store Address, and FSSAI Number.',
        ),
        const Text(
          'Print Language: Choose receipt language (English or Tamil).',
        ),
        const Text('UPI Payment: Configure UPI ID and display name.'),
        const Text(
          'Payment Options: Enable Cash, GPay, and/or Card (at least one mode).',
        ),
        const Text('Appearance: Set UI size and Light/Dark theme.'),
        const Text('Admin Session: Configure admin auto-logout timeout.'),
        const Text('Inventory Control: Toggle inventory tracking.'),
        const Text(
          'Item Configuration: Manage image root path, categories, brands, '
          'brand propagation, wholesale auto-apply, and image embeddings.',
        ),
        const SizedBox(height: AppSpacing.x20),
        Text(
          'Keyboard Shortcuts',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.x8),
        _shortcutTable(),
      ],
    );
  }

  Widget _shortcutTable() {
    const shortcuts = <_ShortcutItem>[
      _ShortcutItem('F2', 'Global', 'Go to Sales Desk'),
      _ShortcutItem('F3', 'Global', 'Go to Items'),
      _ShortcutItem('F10', 'Global', 'Go to Settings'),
      _ShortcutItem('/', 'Global', 'Focus Sales Desk search'),
      _ShortcutItem('Esc', 'Global', 'Cancel / close current context'),
      _ShortcutItem('Ctrl+S', 'Sales Desk', 'Focus search'),
      _ShortcutItem('Ctrl+N', 'Sales Desk', 'Start new bill'),
      _ShortcutItem('Ctrl+H', 'Sales Desk', 'Hold current bill'),
      _ShortcutItem('Ctrl+P', 'Sales Desk', 'Print / save bill'),
      _ShortcutItem('F4', 'Sales Desk', 'Open preview or Save & Print'),
      _ShortcutItem('Delete', 'Sales Desk', 'Remove selected cart row'),
      _ShortcutItem(
        'Arrow Up/Down/Left/Right',
        'Sales Desk Search',
        'Move selection in search grid',
      ),
      _ShortcutItem('Enter', 'Sales Desk Search', 'Add selected item'),
      _ShortcutItem(
        'Enter',
        'Cart Qty/Weight',
        'Confirm qty and return focus to search',
      ),
      _ShortcutItem('Esc', 'Sales Desk Search', 'Close search dropdown'),
      _ShortcutItem('Ctrl+B', 'Bills', 'Return to Sales Desk'),
    ];

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(5),
      },
      border: TableBorder.all(color: AppColors.neutral200),
      children: [
        const TableRow(
          decoration: BoxDecoration(color: AppColors.neutral100),
          children: [
            Padding(
              padding: EdgeInsets.all(AppSpacing.x8),
              child: Text(
                'Shortcut',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppSpacing.x8),
              child: Text(
                'Scope',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppSpacing.x8),
              child: Text(
                'Action',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        for (final item in shortcuts)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x8),
                child: Text(item.shortcut),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x8),
                child: Text(item.scope),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x8),
                child: Text(item.action),
              ),
            ],
          ),
      ],
    );
  }
}

enum _SettingsSection {
  storeProfile,
  printLanguage,
  upiPayment,
  paymentOptions,
  appearance,
  adminSession,
  inventoryControl,
  itemConfiguration,
  helpAndShortcuts,
}

class _SettingsNav extends StatelessWidget {
  const _SettingsNav({required this.active, required this.onSelected});

  final _SettingsSection active;
  final ValueChanged<_SettingsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.x12),
          for (final item in _navItems) ...[
            _SettingsNavItem(
              label: item.label,
              selected: active == item.section,
              onTap: () => onSelected(item.section),
            ),
            const SizedBox(height: AppSpacing.x8),
          ],
        ],
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData(this.section, this.label);
  final _SettingsSection section;
  final String label;
}

const List<_NavItemData> _navItems = [
  _NavItemData(_SettingsSection.storeProfile, 'Store Profile'),
  _NavItemData(_SettingsSection.printLanguage, 'Print Language'),
  _NavItemData(_SettingsSection.upiPayment, 'UPI Payment'),
  _NavItemData(_SettingsSection.paymentOptions, 'Payment Options'),
  _NavItemData(_SettingsSection.appearance, 'Appearance'),
  _NavItemData(_SettingsSection.adminSession, 'Admin Session'),
  _NavItemData(_SettingsSection.inventoryControl, 'Inventory Control'),
  _NavItemData(_SettingsSection.itemConfiguration, 'Item Configuration'),
  _NavItemData(_SettingsSection.helpAndShortcuts, 'Help & Shortcuts'),
];

class _SettingsNavItem extends StatelessWidget {
  const _SettingsNavItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary500 : AppColors.neutral0;
    final fg = selected ? AppColors.neutral0 : AppColors.neutral700;
    final border = selected ? AppColors.primary500 : AppColors.neutral200;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x12,
            vertical: AppSpacing.x8,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutItem {
  const _ShortcutItem(this.shortcut, this.scope, this.action);
  final String shortcut;
  final String scope;
  final String action;
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
      chips.add(
        Chip(
          label: Text(lockedFirst!),
          avatar: const Icon(Icons.lock, size: 14),
        ),
      );
    }
    for (final item in items) {
      chips.add(Chip(label: Text(item), onDeleted: () => onRemove(item)));
    }
    if (chips.isEmpty) {
      return Text(
        emptyText,
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.neutral500),
      );
    }
    return Wrap(
      spacing: AppSpacing.x8,
      runSpacing: AppSpacing.x8,
      children: chips,
    );
  }
}
