/// Result of opening a receipt preview, mirroring the Electron
/// `{ previewStatus, previewError }` contract returned by `openReceiptPreview`.
class PreviewOutcome {
  const PreviewOutcome._(this.status, this.error);

  const PreviewOutcome.opened() : this._('opened', '');
  const PreviewOutcome.failed(String error) : this._('failed', error);

  final String status; // 'opened' | 'failed'
  final String error;

  bool get failed => status == 'failed';
}
