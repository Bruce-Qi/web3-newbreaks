import '../models/news_item.dart';
import 'http_util.dart';
import 'news_sources.dart';

class NewsService {
  /// 并发抓取所有启用的来源，合并、去重并按时间倒序。
  Future<NewsResult> fetchAll(List<NewsSource> sources, {required String rsshub}) async {
    final hub = rsshub.trim().replaceAll(RegExp(r'/+$'), '');
    final results = await Future.wait(sources.map((s) => _fetchSource(s, hub)));

    final seen = <String>{};
    final items = <NewsItem>[];
    final statuses = <SourceStatus>[];
    for (final r in results) {
      statuses.add(r.status);
      for (final item in r.items) {
        final key = item.dedupeKey;
        if (key.isEmpty || seen.add(key)) items.add(item);
      }
    }
    items.sort((a, b) {
      final ta = a.publishedAt, tb = b.publishedAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return NewsResult(items, statuses, DateTime.now());
  }

  Future<({List<NewsItem> items, SourceStatus status})> _fetchSource(NewsSource source, String hub) async {
    final errors = <String>[];
    for (final ep in source.endpoints(hub)) {
      try {
        final body = await getText(ep.url);
        final items = ep.parser(body, source.ref);
        if (items.isEmpty) {
          errors.add('无内容');
          continue;
        }
        return (
          items: items,
          status: SourceStatus(
            sourceId: source.id,
            sourceName: source.name,
            count: items.length,
            endpoint: ep.url,
          ),
        );
      } catch (e) {
        errors.add(e is FormatException ? e.message : e.toString());
      }
    }
    return (
      items: const <NewsItem>[],
      status: SourceStatus(sourceId: source.id, sourceName: source.name, count: 0, error: errors.join('；')),
    );
  }
}
