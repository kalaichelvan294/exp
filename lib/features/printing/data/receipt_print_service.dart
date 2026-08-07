import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../domain/preview_outcome.dart';
import '../domain/receipt_models.dart';
import '../presentation/receipt_preview_page.dart';

/// Opens the receipt preview + print surface. Abstracted so the WebView-backed
/// implementation (Windows-only, not exercised in widget tests) can be
/// overridden with a fake via [receiptPrintServiceProvider].
abstract class ReceiptPrintService {
  Future<PreviewOutcome> openPreview(ReceiptDocument document);
}

/// Default implementation: pushes a full-screen [ReceiptPreviewPage] onto the
/// root navigator, which renders the receipt HTML in an embedded WebView and
/// exposes a Print action (WebView2 `window.print()`). Resolves once the
/// document has loaded (or failed to load), mirroring the Electron preview
/// window's `did-finish-load` / `did-fail-load` handling.
class WebviewReceiptPrintService implements ReceiptPrintService {
  const WebviewReceiptPrintService();

  @override
  Future<PreviewOutcome> openPreview(ReceiptDocument document) async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      return const PreviewOutcome.failed(
          'Print preview is unavailable (no active window).');
    }
    final completer = Completer<PreviewOutcome>();
    unawaited(
      navigator.push<void>(
        PageRouteBuilder<void>(
          opaque: true,
          fullscreenDialog: true,
          pageBuilder: (_, _, _) => ReceiptPreviewPage(
            document: document,
            onLoaded: (outcome) {
              if (!completer.isCompleted) completer.complete(outcome);
            },
          ),
        ),
      ),
    );
    return completer.future;
  }
}

final receiptPrintServiceProvider = Provider<ReceiptPrintService>(
  (ref) => const WebviewReceiptPrintService(),
);
