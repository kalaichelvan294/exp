import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/images/item_image_path.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../application/billing_state.dart';
import '../../../settings/application/settings_controller.dart';
import '../../application/billing_controller.dart';
import '../../domain/billing_enums.dart';
import '../../domain/money.dart';
import '../../domain/product.dart';

/// Search field with a keyboard-navigable results dropdown.
///
/// Ports `search.js`: ↑/↓ move the highlight, Enter adds the best match,
/// Esc closes the dropdown. The parent supplies the [focusNode] so global
/// shortcuts (Ctrl+S / /) can focus it.
class BillingSearchField extends ConsumerStatefulWidget {
  const BillingSearchField({super.key, required this.focusNode});

  final FocusNode focusNode;

  @override
  ConsumerState<BillingSearchField> createState() => _BillingSearchFieldState();
}

class _BillingSearchFieldState extends ConsumerState<BillingSearchField> {
  final _controller = TextEditingController();
  final _layerLink = LayerLink();
  final _searchFieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  List<Product> _overlayMatches = const [];
  bool _overlayOpen = false;
  int _overlaySelectedIndex = -1;
  String _overlayFallbackHost = '';
  String _overlayImageRootPath = '';
  double _overlayWidth = 0;

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  BillingController get _c => ref.read(billingControllerProvider.notifier);

  void _scheduleOverlaySync() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverlay());
  }

  void _syncOverlay() {
    if (!mounted) return;

    final renderObject = _searchFieldKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      _overlayWidth = renderObject.size.width;
    }

    final shouldShow = _overlayOpen && _overlayMatches.isNotEmpty;
    final overlay = Overlay.of(context, rootOverlay: true);
    if (!shouldShow) {
      _removeOverlay();
      return;
    }

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) {
          return Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(
                  0,
                  AppSizing.controlHeight + AppSpacing.x4,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: _overlayWidth > 0 ? _overlayWidth : null,
                    child: _ResultsGrid(
                      matches: _overlayMatches,
                      selectedIndex: _overlaySelectedIndex,
                      fallbackHost: _overlayFallbackHost,
                      imageRootPath: _overlayImageRootPath,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
      overlay.insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _c.moveSelectionGrid(rowDelta: 1, columnDelta: 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _c.moveSelectionGrid(rowDelta: -1, columnDelta: 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _c.moveSelectionGrid(rowDelta: 0, columnDelta: 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _c.moveSelectionGrid(rowDelta: 0, columnDelta: -1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        _c.setSearchDropdownOpen(false);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _c.addBestMatch().then((_) => _controller.clear());
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingControllerProvider);
    final config = ref.watch(appConfigProvider);
    final settings = ref.watch(settingsControllerProvider).settings;
    // Keep the text field in sync when the controller resets the query.
    if (state.query.isEmpty && _controller.text.isNotEmpty) {
      _controller.clear();
    }
    _overlayMatches = state.matches.take(10).toList();
    _overlayOpen = state.searchDropdownOpen;
    _overlaySelectedIndex = state.selectedMatchIndex;
    _overlayFallbackHost = config.databaseHost;
    _overlayImageRootPath = settings.itemImagesRootPath;
    _scheduleOverlaySync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Focus(
                onKeyEvent: _onKey,
                child: CompositedTransformTarget(
                  key: _searchFieldKey,
                  link: _layerLink,
                  child: TextField(
                    controller: _controller,
                    focusNode: widget.focusNode,
                    autofocus: true,
                    onChanged: _c.onQueryChanged,
                    onTap: () => _c.setSearchDropdownOpen(true),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: AppColors.neutral500,
                      ),
                      hintText: 'Search Item / SKU (/)',
                    ),
                  ),
                ),
              ),
            ),
            Focus(
              onFocusChange: (focused) => _c.onSearchFocusChanged(focused),
              child: const SizedBox(width: 0, height: 0), // Invisible widget for focus tracking
            ),
            const SizedBox(width: AppSpacing.x8),
            _CameraStatusChip(state: state),
          ],
        ),
        const SizedBox(height: AppSpacing.x4),
        _SearchHint(),
      ],
    );
  }
}

class _ResultsGrid extends ConsumerWidget {
  const _ResultsGrid({
    required this.matches,
    required this.selectedIndex,
    required this.fallbackHost,
    required this.imageRootPath,
  });

  final List<Product> matches;
  final int selectedIndex;
  final String fallbackHost;
  final String imageRootPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(billingControllerProvider.notifier);
    const columns = 3;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.x4),
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        color: AppColors.neutral0,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.neutral200),
        boxShadow: AppShadows.card,
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.x12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: AppSpacing.x12,
          crossAxisSpacing: AppSpacing.x12,
          childAspectRatio: 1.22,
        ),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final product = matches[index];
          final active = index == selectedIndex;
          final image = ItemImagePath.resolve(
            sku: product.sku,
            configuredRootPath: imageRootPath,
            fallbackHost: fallbackHost,
          );
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: AppRadius.input,
              onTap: () => c.addProduct(product, 'MANUAL_SEARCH'),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: active ? AppColors.neutral50 : AppColors.neutral0,
                  borderRadius: AppRadius.input,
                  border: Border.all(
                    color: active ? AppColors.primary500 : AppColors.neutral300,
                    width: active ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                              child: image.filePath != null
                                  ? Image.file(
                                      File(image.filePath!),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: AppColors.neutral100,
                                              alignment: Alignment.center,
                                              child: const Text('No image'),
                                            );
                                          },
                                    )
                                  : Image.network(
                                      image.networkUrl ?? '',
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: AppColors.neutral100,
                                              alignment: Alignment.center,
                                              child: const Text('No image'),
                                            );
                                          },
                                    ),
                            ),
                          ),
                          Positioned(
                            top: AppSpacing.x8,
                            left: AppSpacing.x8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.neutral900.withValues(
                                  alpha: 0.78,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.x8,
                                  vertical: AppSpacing.x4,
                                ),
                                child: Text(
                                  product.stockDisplay,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: AppColors.neutral0,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.x6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.nameTa.isNotEmpty
                                      ? product.nameTa
                                      : '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: AppSpacing.x4),
                                Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: AppSpacing.x4),
                                Text(
                                  'Brand: ${product.brandName.isNotEmpty ? product.brandName : '—'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.neutral600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.x8),
                          Text(
                            '${Money.format(product.ratePaise)} / ${product.pricingType == PricingType.weight ? 'kg' : 'qty'}',
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.primary600,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchHint extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billingControllerProvider);
    final theme = Theme.of(context);
    String text;
    if (state.message.text.isNotEmpty) {
      text = state.message.text;
    } else if (state.cameraBusy) {
      text = state.cameraStatus;
    } else if (state.query.isEmpty && state.cameraCaptureMode != CameraCaptureMode.none && !state.cameraTurnedOff) {
      text = 'Camera active. Press "/" again to search or click the badge to open settings.';
    } else if (state.query.isEmpty) {
      text = 'Type item name or SKU. Press Enter to add best match. Press "/" for camera search.';
    } else if (state.searching) {
      text = 'Searching…';
    } else if (state.matches.isEmpty) {
      text = 'No matching item found for this input.';
    } else {
      text = '${state.matches.length} match(es). Use arrows and Enter to add.';
    }
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: state.message.isError
            ? AppColors.error500
            : AppColors.neutral500,
      ),
    );
  }
}

class _CameraStatusChip extends ConsumerWidget {
  const _CameraStatusChip({required this.state});

  final BillingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(billingControllerProvider.notifier);
    
    // Determine color and icon based on state
    Color bg;
    Color fg;
    IconData icon;
    String label;
    
    if (state.cameraError.isNotEmpty) {
      // Red for error
      bg = AppColors.error500.withValues(alpha: 0.16);
      fg = AppColors.error500;
      icon = Icons.videocam_off;
      label = 'Camera error';
    } else if (state.cameraTurnedOff) {
      // Orange for turned off
      bg = AppColors.warning500.withValues(alpha: 0.16);
      fg = AppColors.warning500;
      icon = Icons.videocam_off;
      label = 'Camera off';
    } else if (state.cameraBusy) {
      // Yellow for scanning
      bg = AppColors.warning500.withValues(alpha: 0.16);
      fg = AppColors.warning500;
      icon = Icons.hourglass_top;
      label = 'Scanning...';
    } else if (state.cameraConnected && state.cameraCaptureMode != CameraCaptureMode.none) {
      // Green for live (camera is connected and in use)
      bg = AppColors.success500.withValues(alpha: 0.16);
      fg = AppColors.success500;
      icon = Icons.videocam;
      label = 'Camera live';
    } else {
      // Gray for offline
      bg = AppColors.neutral100;
      fg = AppColors.neutral600;
      icon = Icons.videocam_off;
      label = 'Camera offline';
    }

    return Tooltip(
      message: state.cameraError.isNotEmpty 
          ? state.cameraError 
          : state.cameraStatus,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => unawaited(c.openCameraModal()),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: state.cameraTurnedOff || state.cameraError.isNotEmpty
                  ? fg
                  : (state.cameraConnected && state.cameraCaptureMode != CameraCaptureMode.none 
                      ? AppColors.success500 
                      : AppColors.neutral300),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x12,
              vertical: AppSpacing.x8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: AppSpacing.x6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
