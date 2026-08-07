import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../core/theme/app_tokens.dart';
import '../domain/preview_outcome.dart';
import '../domain/receipt_models.dart';

/// Full-screen receipt preview backed by a Windows WebView (WebView2).
///
/// Ports the Electron receipt preview window: the 2.5-inch receipt HTML is
/// loaded into an embedded WebView; the user can Print (via WebView2's
/// `window.print()`, which shows the native print dialog) or Close. Load
/// success/failure is reported back through [onLoaded] so the caller can
/// surface a preview status consistent with the current app.
class ReceiptPreviewPage extends StatefulWidget {
  const ReceiptPreviewPage({
    super.key,
    required this.document,
    required this.onLoaded,
  });

  final ReceiptDocument document;
  final void Function(PreviewOutcome outcome) onLoaded;

  @override
  State<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends State<ReceiptPreviewPage> {
  final _controller = WebviewController();
  bool _ready = false;
  bool _reported = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  Future<void> _initWebview() async {
    try {
      await _controller.initialize();
      await _controller.loadStringContent(widget.document.html);
      if (!mounted) return;
      setState(() => _ready = true);
      _report(const PreviewOutcome.opened());
    } catch (e) {
      final message = 'Failed to open print preview: $e';
      if (mounted) setState(() => _error = message);
      _report(PreviewOutcome.failed(message));
    }
  }

  void _report(PreviewOutcome outcome) {
    if (_reported) return;
    _reported = true;
    widget.onLoaded(outcome);
  }

  Future<void> _print() async {
    try {
      await _controller.executeScript('window.print();');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error500,
          content: Text('Print failed: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt Preview — ${widget.document.billId}'),
        actions: [
          if (_error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
              child: FilledButton.icon(
                onPressed: _ready ? _print : null,
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.x8),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Close'),
            ),
          ),
        ],
      ),
      body: _error != null
          ? _ErrorView(message: _error!)
          : Center(
              child: Container(
                width: 320,
                margin: const EdgeInsets.all(AppSpacing.x16),
                decoration: BoxDecoration(
                  color: AppColors.neutral0,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: AppColors.neutral200),
                  boxShadow: AppShadows.card,
                ),
                clipBehavior: Clip.antiAlias,
                child: _ready
                    ? Webview(_controller)
                    : const SizedBox(
                        height: 480,
                        child: Center(child: CircularProgressIndicator()),
                      ),
              ),
            ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.print_disabled_outlined,
                size: 40, color: AppColors.error500),
            const SizedBox(height: AppSpacing.x16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
