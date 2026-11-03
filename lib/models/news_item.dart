class NewsItem {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String link;
  final String sourceId;
  final String sourceName;
  final DateTime? publishedAt;
  final String? imageUrl;

  const NewsItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.link,
    required this.sourceId,
    required this.sourceName,
    this.publishedAt,
    this.imageUrl,
  });

  /// 用于跨来源去重：去掉空白和标点后的标题
  String get dedupeKey => title.replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '').toLowerCase();
}

/// 单个来源本次抓取的结果
class SourceStatus {
  final String sourceId;
  final String sourceName;
  final int count;
  final String? error;
  final String? endpoint;

  const SourceStatus({
    required this.sourceId,
    required this.sourceName,
    required this.count,
    this.error,
    this.endpoint,
  });

  bool get ok => error == null;
}

class NewsResult {
  final List<NewsItem> items;
  final List<SourceStatus> statuses;
  final DateTime fetchedAt;

  const NewsResult(this.items, this.statuses, this.fetchedAt);
}
