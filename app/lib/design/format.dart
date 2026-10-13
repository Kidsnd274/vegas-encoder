/// Display formatting for figures, matching `VE.fmt` in the design prototype
/// (`docs/product/design/shared/model.js`). Formatting only: every number comes
/// from the core or the services.
abstract final class VeFormat {
  /// Decimal units: "537 MB", "53.7 MB", "2.93 GB".
  static String bytes(num value) {
    if (value <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var b = value.toDouble();
    var i = 0;
    while (b >= 1000 && i < units.length - 1) {
      b /= 1000;
      i++;
    }
    final digits = b >= 100 ? 0 : (b >= 10 ? 1 : 2);
    return '${b.toStringAsFixed(digits)} ${units[i]}';
  }

  /// "320 kb/s", "8 Mb/s", "6.8 Mb/s" from kilobits per second.
  static String rate(num kbps) {
    final k = kbps.round();
    if (k >= 1000) return '${(k / 1000).toStringAsFixed(k % 1000 == 0 ? 0 : 1)} Mb/s';
    return '$k kb/s';
  }

  /// "10:00", "1:02:03" from seconds.
  static String duration(num seconds) {
    final s = seconds.round();
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, x = s % 60;
    final mm = h > 0 ? '$h:${m.toString().padLeft(2, '0')}' : '$m';
    return '$mm:${x.toString().padLeft(2, '0')}';
  }

  /// "29.97 fps", "25 fps" from a rational rate.
  static String fps(int numerator, int denominator) {
    final v = numerator / denominator;
    if ((v - v.round()).abs() < 1e-6) return '${v.round()} fps';
    var text = v.toStringAsFixed(3);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return '$text fps';
  }

  /// "9,607" with thousands separators.
  static String count(int value) {
    final digits = value.abs().toString();
    final out = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "12 Oct 2026", in local time.
  static String date(DateTime value) {
    final d = value.toLocal();
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  /// Parses a typed length: "10:00", "1:02:03", or plain minutes ("12.5").
  /// Returns seconds, or null if the text is not a length (UI_SPEC §2).
  static int? parseLength(String text) {
    final t = text.trim();
    var m = RegExp(r'^(\d+):([0-5]?\d):([0-5]\d)$').firstMatch(t);
    if (m != null) return int.parse(m[1]!) * 3600 + int.parse(m[2]!) * 60 + int.parse(m[3]!);
    m = RegExp(r'^(\d+):([0-5]\d)$').firstMatch(t);
    if (m != null) return int.parse(m[1]!) * 60 + int.parse(m[2]!);
    m = RegExp(r'^(\d+(?:\.\d+)?)$').firstMatch(t);
    if (m != null) return (double.parse(m[1]!) * 60).round();
    return null;
  }
}
