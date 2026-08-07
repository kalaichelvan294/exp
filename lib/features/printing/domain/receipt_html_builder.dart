import 'receipt_models.dart';

/// Renders the 2.5-inch thermal receipt HTML for a [ReceiptPayload].
///
/// Direct port of `buildReceiptHtml` (+ `escapeHtml`, `formatMoney`,
/// `formatQty`, `formatDateTime`) from the Electron `receipt-printer.js`. The
/// markup, CSS (`@page{size:2.5in auto}`), column order, and bilingual
/// item-name behavior are preserved so printed output matches the current app.
class ReceiptHtmlBuilder {
  const ReceiptHtmlBuilder._();

  static String escapeHtml(Object? value) {
    return (value?.toString() ?? '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String formatMoney(int paise) {
    final amount = paise / 100;
    return '\u20B9${amount.toStringAsFixed(2)}';
  }

  static String formatQty(num value) {
    final numeric = value.isFinite ? value : 0;
    if ((numeric - numeric.round()).abs() < 0.000001) {
      return numeric.round().toString();
    }
    return numeric.toStringAsFixed(3);
  }

  static String formatDateTime(String value) {
    DateTime? date;
    if (value.trim().isNotEmpty) {
      date = DateTime.tryParse(value);
    }
    final local = (date ?? DateTime.now()).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final y = local.year.toString().padLeft(4, '0');
    return '$y-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static String build(ReceiptPayload bill) {
    final useTamil = bill.useTamil;
    final buffer = StringBuffer();
    if (bill.items.isEmpty) {
      buffer.write(
        '<tr><td class="item-name muted" colspan="4">'
        'No bill items available.</td></tr>',
      );
    } else {
      for (final line in bill.items) {
        final displayName = line.displayName(useTamil: useTamil);
        final skuBlock = line.sku.isNotEmpty
            ? '<div class="muted">SKU: ${escapeHtml(line.sku)}</div>'
            : '';
        buffer.write(
          '<tr>'
          '<td class="item-name">${escapeHtml(displayName)}$skuBlock</td>'
          '<td class="num">${escapeHtml(formatQty(line.qty))}</td>'
          '<td class="num">${escapeHtml(formatMoney(line.ratePaise))}</td>'
          '<td class="num">${escapeHtml(formatMoney(line.lineTotalPaise))}</td>'
          '</tr>',
        );
      }
    }
    final itemRows = buffer.toString();

    final fssaiBlock = bill.fssaiNumber.isNotEmpty
        ? '<div class="center muted">FSSAI: '
            '${escapeHtml(bill.fssaiNumber)}</div>'
        : '';
    final discountBlock = bill.discountPaise > 0
        ? '<div><span>Discount</span><span>-'
            '${escapeHtml(formatMoney(bill.discountPaise))}</span></div>'
        : '';

    return '<!doctype html>'
        '<html><head><meta charset="utf-8" />'
        '<meta name="viewport" content="width=device-width, initial-scale=1" />'
        '<title>Receipt ${escapeHtml(bill.billId)}</title>'
        '<style>'
        '@page{size:2.5in auto;margin:0;}'
        'html,body{margin:0;padding:0;background:#fff;}'
        "body{font-family:'Segoe UI',Arial,sans-serif;color:#111;"
        'font-size:11px;line-height:1.25;width:2.5in;box-sizing:border-box;'
        'padding:10px;}'
        '.center{text-align:center;}'
        '.muted{color:#555;font-size:10px;}'
        'table{width:100%;border-collapse:collapse;margin-top:8px;}'
        'th,td{padding:4px 1px;border-bottom:1px dashed #ccc;'
        'vertical-align:top;}'
        'th{font-size:10px;text-transform:uppercase;letter-spacing:.2px;}'
        '.num{text-align:right;white-space:nowrap;padding-left:8px;'
        'padding-right:2px;}'
        '.item-name{word-break:break-word;white-space:normal;}'
        '.item-name .muted{display:block;margin-top:2px;}'
        '.totals{margin-top:8px;}'
        '.totals div{display:flex;justify-content:space-between;padding:2px 0;}'
        '.grand{font-weight:700;border-top:1px solid #111;margin-top:4px;'
        'padding-top:4px;}'
        '.meta{display:flex;justify-content:space-between;gap:8px;'
        'margin-top:6px;}'
        '.meta div{font-size:10px;}'
        '.cutline{border-top:1px dashed #aaa;margin:10px 0 0;padding-top:6px;}'
        '</style></head><body>'
        '<div class="center"><strong>${escapeHtml(bill.storeName)}</strong>'
        '</div>'
        '<div class="center muted">'
        '${escapeHtml(bill.storeBusinessType)}</div>'
        '<div class="center muted">${escapeHtml(bill.storeAddress)}</div>'
        '$fssaiBlock'
        '<div class="meta">'
        '<div>Bill: <strong>${escapeHtml(bill.billId)}</strong></div>'
        '<div>${escapeHtml(formatDateTime(bill.createdAt))}</div>'
        '</div>'
        '<div class="meta">'
        '<div>Payment: ${escapeHtml(bill.paymentMode)}</div>'
        '<div>Items: ${escapeHtml(bill.itemCount.toString())}</div>'
        '</div>'
        '<table>'
        '<thead><tr><th>Item</th><th class="num">Qty</th>'
        '<th class="num">Rate</th><th class="num">Total</th></tr></thead>'
        '<tbody>$itemRows</tbody>'
        '</table>'
        '<div class="totals">'
        '<div><span>Subtotal</span><span>'
        '${escapeHtml(formatMoney(bill.subtotalPaise))}</span></div>'
        '$discountBlock'
        '<div class="grand"><span>Grand Total</span><span>'
        '${escapeHtml(formatMoney(bill.grandTotalPaise))}</span></div>'
        '</div>'
        '<div class="center muted cutline">Thank you for shopping!</div>'
        '</body></html>';
  }

  /// Builds a [ReceiptDocument] (bill id + rendered HTML) for the print flow.
  static ReceiptDocument document(ReceiptPayload bill) =>
      ReceiptDocument(billId: bill.billId, html: build(bill));
}
