import 'dart:math' as math;

/// 千分位分组，例如 1234567 -> 1,234,567
String _group(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// 按美元格式化价格；小额币种自动保留足够的有效位数。
String formatUsd(double? v, {bool withSymbol = true}) {
  if (v == null || v.isNaN) return '--';
  final abs = v.abs();
  int decimals;
  if (abs >= 1) {
    decimals = abs >= 1000 ? 2 : (abs >= 10 ? 2 : 4);
  } else if (abs == 0) {
    decimals = 2;
  } else {
    // 保留 4 位有效数字，例如 0.00001234
    decimals = math.min(12, (-math.log(abs) / math.ln10).floor() + 4);
  }
  final fixed = abs.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = _group(parts[0]);
  final s = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  return '${v < 0 ? '-' : ''}${withSymbol ? '\$' : ''}$s';
}

/// 紧凑格式：$1.23T / $456.7B / $12.3M
String formatCompactUsd(double? v) {
  if (v == null || v.isNaN) return '--';
  final abs = v.abs();
  String s;
  if (abs >= 1e12) {
    s = '${(abs / 1e12).toStringAsFixed(2)}T';
  } else if (abs >= 1e9) {
    s = '${(abs / 1e9).toStringAsFixed(2)}B';
  } else if (abs >= 1e6) {
    s = '${(abs / 1e6).toStringAsFixed(2)}M';
  } else if (abs >= 1e3) {
    s = '${(abs / 1e3).toStringAsFixed(2)}K';
  } else {
    s = abs.toStringAsFixed(2);
  }
  return '${v < 0 ? '-' : ''}\$$s';
}

/// 数量（非美元），如流通量
String formatAmount(double? v) {
  if (v == null || v.isNaN) return '--';
  final abs = v.abs();
  if (abs >= 1e12) return '${(v / 1e12).toStringAsFixed(2)}T';
  if (abs >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
  if (abs >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
  return _group(v.round().toString());
}

String formatPercent(double? v) {
  if (v == null || v.isNaN) return '--';
  return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatClock(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}:${_two(l.second)}';
}

String formatDateTime(DateTime t) {
  final l = t.toLocal();
  return '${l.year}-${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)}';
}

/// 中文相对时间：刚刚 / 5分钟前 / 3小时前 / 昨天 12:30 / 10-21 08:00
String relativeTime(DateTime? t, {DateTime? now}) {
  if (t == null) return '';
  final n = (now ?? DateTime.now()).toLocal();
  final l = t.toLocal();
  final diff = n.difference(l);
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24 && l.day == n.day) return '${diff.inHours}小时前';
  final yesterday = DateTime(n.year, n.month, n.day).subtract(const Duration(days: 1));
  if (!l.isBefore(yesterday)) return '昨天 ${_two(l.hour)}:${_two(l.minute)}';
  if (l.year == n.year) {
    return '${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)}';
  }
  return '${l.year}-${_two(l.month)}-${_two(l.day)}';
}

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

final _rfc822 = RegExp(
  r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([A-Za-z]+|[+-]\d{2}:?\d{2})?',
);
final _plainDate = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?$');

/// 解析 RSS/Atom/接口中常见的各种时间格式。
/// 无时区信息的时间按北京时间 (UTC+8) 处理——中文媒体几乎都如此。
DateTime? parseFlexibleDate(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return _fromEpoch(raw);
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  final asNum = num.tryParse(s);
  if (asNum != null) return _fromEpoch(asNum);

  final plain = _plainDate.firstMatch(s);
  if (plain != null) {
    final utc = DateTime.utc(
      int.parse(plain.group(1)!),
      int.parse(plain.group(2)!),
      int.parse(plain.group(3)!),
      int.parse(plain.group(4)!),
      int.parse(plain.group(5)!),
      int.tryParse(plain.group(6) ?? '') ?? 0,
    );
    return utc.subtract(const Duration(hours: 8));
  }

  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;

  final m = _rfc822.firstMatch(s);
  if (m != null) {
    final month = _months[m.group(2)!.toLowerCase()];
    if (month == null) return null;
    var year = int.parse(m.group(3)!);
    if (year < 100) year += 2000;
    final base = DateTime.utc(
      year,
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.tryParse(m.group(6) ?? '') ?? 0,
    );
    return base.subtract(_zoneOffset(m.group(7)));
  }
  return null;
}

DateTime _fromEpoch(num n) {
  final ms = n > 1e12 ? n.toInt() : (n * 1000).toInt();
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

Duration _zoneOffset(String? zone) {
  if (zone == null) return Duration.zero;
  final z = zone.toUpperCase();
  final m = RegExp(r'^([+-])(\d{2}):?(\d{2})$').firstMatch(z);
  if (m != null) {
    final d = Duration(hours: int.parse(m.group(2)!), minutes: int.parse(m.group(3)!));
    return m.group(1) == '-' ? -d : d;
  }
  switch (z) {
    case 'CST': // 中文站点里的 CST 通常是 China Standard Time
      return const Duration(hours: 8);
    case 'EST':
      return const Duration(hours: -5);
    case 'EDT':
      return const Duration(hours: -4);
    case 'PST':
      return const Duration(hours: -8);
    case 'PDT':
      return const Duration(hours: -7);
    default: // GMT / UTC / Z
      return Duration.zero;
  }
}

/// 将 HTML 片段转成纯文本，保留段落换行。
String htmlToText(String? html) {
  if (html == null || html.isEmpty) return '';
  var s = html;
  s = s.replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '');
  s = s.replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</(p|div|h[1-6]|li|blockquote|tr)>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = decodeEntities(s);
  s = s.replaceAll('\r', '');
  s = s.replaceAll(RegExp(r'[ \t 　]+\n'), '\n');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

const _entities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'ldquo': '“',
  'rdquo': '”',
  'lsquo': '‘',
  'rsquo': '’',
  'hellip': '…',
  'mdash': '—',
  'ndash': '–',
  'middot': '·',
  'times': '×',
  'yen': '¥',
};

String decodeEntities(String s) {
  return s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);'), (m) {
    final e = m.group(1)!;
    if (e.startsWith('#x') || e.startsWith('#X')) {
      final code = int.tryParse(e.substring(2), radix: 16);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    }
    if (e.startsWith('#')) {
      final code = int.tryParse(e.substring(1));
      return code == null ? m.group(0)! : String.fromCharCode(code);
    }
    return _entities[e.toLowerCase()] ?? m.group(0)!;
  });
}

/// 从 HTML 里提取第一张图片地址
String? firstImage(String? html) {
  if (html == null) return null;
  final m = RegExp(r'''<img[^>]+src=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
  final url = m?.group(1);
  if (url == null || !url.startsWith('http')) return null;
  return decodeEntities(url);
}
