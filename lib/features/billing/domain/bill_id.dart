/// Generates the pending bill identifier.
///
/// Ports `ensurePendingBillId` format: `dd-mon-yyyy-HHmmssSSS`
/// (e.g. `04-aug-2026-165703319`).
class BillId {
  BillId._();

  static const _months = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];

  static String generate([DateTime? at]) {
    final now = at ?? DateTime.now();
    String p2(int v) => v.toString().padLeft(2, '0');
    String p3(int v) => v.toString().padLeft(3, '0');
    final day = p2(now.day);
    final month = _months[now.month - 1];
    final year = now.year.toString();
    final time = '${p2(now.hour)}${p2(now.minute)}${p2(now.second)}'
        '${p3(now.millisecond)}';
    return '$day-$month-$year-$time';
  }
}
