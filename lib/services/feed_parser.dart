import 'dart:convert';

import 'package:xml/xml.dart';

import '../models/news_item.dart';
import '../utils/format.dart';

/// 来源元信息，传给各个解析器
class SourceRef {
  final String id;
  final String name;
  const SourceRef(this.id, this.name);
}

String _local(XmlElement e) => e.name.local.toLowerCase();

XmlElement? _child(XmlElement e, String localName) {
  for (final c in e.childElements) {
    if (_local(c) == localName) return c;
  }
  return null;
}

String _text(XmlElement e, String localName) => _child(e, localName)?.innerText.trim() ?? '';

/// 通用 RSS 2.0 / Atom 解析
List<NewsItem> parseFeed(String body, SourceRef src) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(body.trimLeft());
  } on XmlException catch (e) {
    throw FormatException('RSS 解析失败: ${e.message}');
  }
  final root = doc.rootElement;
  final out = <NewsItem>[];

  Iterable<XmlElement> items = root.descendantElements.where((e) => _local(e) == 'item');
  final isAtom = items.isEmpty;
  if (isAtom) {
    items = root.descendantElements.where((e) => _local(e) == 'entry');
  }

  for (final e in items) {
    var title = _text(e, 'title');
    String link;
    String rawHtml;
    String? date;
    String? image;

    if (isAtom) {
      XmlElement? linkEl;
      for (final c in e.childElements.where((c) => _local(c) == 'link')) {
        linkEl ??= c;
        if ((c.getAttribute('rel') ?? 'alternate') == 'alternate') {
          linkEl = c;
          break;
        }
      }
      link = linkEl?.getAttribute('href') ?? linkEl?.innerText.trim() ?? '';
      rawHtml = _text(e, 'content').isNotEmpty ? _text(e, 'content') : _text(e, 'summary');
      date = _text(e, 'published').isNotEmpty ? _text(e, 'published') : _text(e, 'updated');
    } else {
      link = _text(e, 'link');
      if (link.isEmpty) link = _text(e, 'guid');
      final encoded = _text(e, 'encoded'); // content:encoded
      final desc = _text(e, 'description');
      rawHtml = encoded.length > desc.length ? encoded : desc;
      date = _text(e, 'pubdate');
      if (date.isEmpty) date = _text(e, 'date'); // dc:date
      image = _child(e, 'enclosure')?.getAttribute('url');
      for (final c in e.childElements) {
        final n = _local(c);
        if ((n == 'content' || n == 'thumbnail') && c.getAttribute('url') != null) {
          image ??= c.getAttribute('url');
        }
      }
    }

    final content = htmlToText(rawHtml);
    title = htmlToText(title);
    if (title.isEmpty) title = _deriveTitle(content);
    if (title.isEmpty) continue;
    image ??= firstImage(rawHtml);

    out.add(
      NewsItem(
        id: '${src.id}:${link.isNotEmpty ? link : title}',
        title: title,
        summary: _summary(content, title),
        content: content,
        link: link.trim(),
        sourceId: src.id,
        sourceName: src.name,
        publishedAt: parseFlexibleDate(date),
        imageUrl: (image != null && image.startsWith('http')) ? image : null,
      ),
    );
  }
  return out;
}

/// 律动 BlockBeats 开放接口
/// https://api.theblockbeats.news/v1/open-api/open-flash?size=50&page=1&type=push&lang=cn
List<NewsItem> parseBlockBeats(String body, SourceRef src) {
  final j = jsonDecode(body);
  dynamic list = j is Map ? j['data'] : null;
  if (list is Map) list = list['data'] ?? list['list'];
  if (list is! List) throw const FormatException('律动接口格式变化');
  return list
      .whereType<Map>()
      .map((m) {
        final content = htmlToText(m['content']?.toString());
        var title = htmlToText(m['title']?.toString());
        if (title.isEmpty) title = _deriveTitle(content);
        final id = m['id']?.toString() ?? title;
        final link = (m['link'] ?? m['url'] ?? '').toString();
        return NewsItem(
          id: '${src.id}:$id',
          title: title,
          summary: _summary(content, title),
          content: content,
          link: link.isNotEmpty ? link : 'https://www.theblockbeats.info/flash/$id',
          sourceId: src.id,
          sourceName: src.name,
          publishedAt: parseFlexibleDate(m['create_time'] ?? m['add_time'] ?? m['created_at']),
          imageUrl: _http(m['pic'] ?? m['image']),
        );
      })
      .where((e) => e.title.isNotEmpty)
      .toList();
}

/// 金色财经快讯接口
/// https://api.jinse.cn/noah/v2/lives?limit=50&reading=false&source=web&flag=down&id=0&category=0
List<NewsItem> parseJinse(String body, SourceRef src) {
  final j = jsonDecode(body);
  final groups = j is Map ? j['list'] : null;
  if (groups is! List) throw const FormatException('金色财经接口格式变化');
  final out = <NewsItem>[];
  for (final g in groups.whereType<Map>()) {
    final lives = g['lives'];
    if (lives is! List) continue;
    for (final m in lives.whereType<Map>()) {
      var raw = htmlToText(m['content']?.toString());
      var title = htmlToText(m['content_prefix']?.toString());
      // 金色快讯正文通常形如 “【标题】正文”
      final bracket = RegExp(r'^【([^】]+)】').firstMatch(raw);
      if (bracket != null) {
        if (title.isEmpty) title = bracket.group(1)!.trim();
        raw = raw.substring(bracket.end).trim();
      }
      if (title.isEmpty) title = _deriveTitle(raw);
      if (title.isEmpty) continue;
      final id = m['id']?.toString() ?? title;
      final link = (m['link'] ?? '').toString();
      out.add(
        NewsItem(
          id: '${src.id}:$id',
          title: title,
          summary: _summary(raw, title),
          content: raw,
          link: link.startsWith('http') ? link : 'https://www.jinse.cn/lives/$id.html',
          sourceId: src.id,
          sourceName: src.name,
          publishedAt: parseFlexibleDate(m['created_at']),
          imageUrl: _firstImageOf(m['images']),
        ),
      );
    }
  }
  return out;
}

String? _http(Object? v) {
  final s = v?.toString() ?? '';
  return s.startsWith('http') ? s : null;
}

String? _firstImageOf(Object? v) {
  if (v is List && v.isNotEmpty) {
    final f = v.first;
    if (f is Map) return _http(f['url'] ?? f['src']);
    return _http(f);
  }
  return null;
}

/// 快讯没有标题时，取正文第一句
String _deriveTitle(String content) {
  if (content.isEmpty) return '';
  final first = content.split(RegExp(r'[。！？\n]')).first.trim();
  final t = first.isEmpty ? content : first;
  return t.length > 60 ? '${t.substring(0, 60)}…' : t;
}

String _summary(String content, String title) {
  var s = content.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.startsWith(title)) s = s.substring(title.length).trim();
  return s.length > 160 ? '${s.substring(0, 160)}…' : s;
}
