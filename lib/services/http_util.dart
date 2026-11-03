import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class HttpError implements Exception {
  final String message;
  HttpError(this.message);
  @override
  String toString() => message;
}

final http.Client _client = http.Client();

const _ua =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';

/// GET 请求并以 UTF-8 解码（不依赖响应头里的 charset，避免中文乱码）
Future<String> getText(
  String url, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final http.Response res;
  try {
    res = await _client
        .get(
          Uri.parse(url),
          headers: {
            'User-Agent': _ua,
            'Accept': '*/*',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.6',
            ...?headers,
          },
        )
        .timeout(timeout);
  } on TimeoutException {
    throw HttpError('请求超时');
  } catch (e) {
    throw HttpError('网络错误: ${_short(e)}');
  }
  if (res.statusCode == 429) throw HttpError('请求过于频繁 (429)，请稍后再试');
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw HttpError('HTTP ${res.statusCode}');
  }
  return utf8.decode(res.bodyBytes, allowMalformed: true);
}

Future<dynamic> getJson(String url, {Map<String, String>? headers, Duration? timeout}) async {
  final body = await getText(
    url,
    headers: {'Accept': 'application/json', ...?headers},
    timeout: timeout ?? const Duration(seconds: 12),
  );
  try {
    return jsonDecode(body);
  } on FormatException {
    throw HttpError('返回内容不是有效的 JSON');
  }
}

String _short(Object e) {
  final s = e.toString();
  return s.length > 80 ? '${s.substring(0, 80)}…' : s;
}
