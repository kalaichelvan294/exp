import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../application/billing_controller.dart';
import '../../domain/money.dart';

/// Search field with a keyboard-navigable results dropdown.
///
/// Ports `search.js`: ↑/↓ move the highlight, Enter adds the best match,
/// Esc closes the dropdown. The parent supplies the [focusNode] so global
/// shortcuts (Alt+S / Ctrl+/) can focus it.
class BillingSearchField extends ConsumerStatefulWidget {
  const BillingSearchField({super.key, required this.focusNode});

  final FocusNode focusNode;

  @override
  ConsumerState<BillingSearchField> createState() => _BillingSearchFieldState();
}

class _BillingSearchFieldState extends ConsumerState<BillingSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  BillingController get _c => ref.read(billingControllerProvider.notifier);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _c.moveSelection(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _c.moveSelection(-1);
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
    // Keep the text field in sync when the controller resets the query.
    if (state.query.isEmpty && _controller.text.isNotEmpty) {
      _controller.clear();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          onKeyEvent: _onKey,
          child: TextField(
            controller: _controller,
            focusNode: widget.focusNode,
            autofocus: true,
            onChanged: _c.onQueryChanged,
            onTap: () => _c.setSearchDropdownOpen(true),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 18, color: AppColors.neutral500),
              hintText: 'Search Item / SKU (Alt+S)',
            ),
          ),
        ),
        if (state.searchDropdownOpen && state.matches.isNotEmpty)
          _ResultsList(),
        const SizedBox(height: AppSpacing.x4),
        _SearchHint(),
      ],
    );
  }
}

class _ResultsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billingControllerProvider);
    final c = ref.read(billingControllerProvider.notifier);
    final matches = state.matches.take(8).toList();

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.x4),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: AppColors.neutral0,
        borderRadius: AppRadius.input,
        border: Border.all(color: AppColors.neutral200),
        boxShadow: AppShadows.card,
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final product = matches[index];
          final active = index == state.selectedMatchIndex;
          return Material(
            color: active ? AppColors.neutral100 : Colors.transparent,
            child: InkWell(
              onTap: () => c.addProduct(product, 'MANUAL_SEARCH'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x16,
                  vertical: AppSpacing.x8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${product.displayName} - ${Money.format(product.ratePaise)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (product.brandName.isNotEmpty)
                      Text(
                        'Brand: ${product.brandName}',
                        style: Theme.of(context).textTheme.bodySmall,
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
    } else if (state.query.isEmpty) {
      text = 'Type item name or SKU. Press Enter to add best match.';
    } else if (state.searching) {
      text = 'Searching…';
    } else if (state.matches.isEmpty) {
      text = 'No matching item found for this input.';
    } else {
      text = '${state.matches.length} match(es). Use ↑/↓ and Enter to add.';
    }
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: state.message.isError ? AppColors.error500 : AppColors.neutral500,
      ),
    );
  }
}
