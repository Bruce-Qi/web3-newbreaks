import '../models/news_item.dart';
import 'feed_parser.dart';

typedef FeedParser = List<NewsItem> Function(String body, SourceRef src);

class FeedEndpoint {
  final String url;
  final FeedParser parser;
  const FeedEndpoint(this.url, this.parser);
}

/// 一个资讯来源 = 若干个候选地址，按顺序尝试，第一个成功的生效。
/// 官方地址优先，失败时回退到 RSSHub（可在设置中替换为自建实例）。
class NewsSource {
  final String id;
  final String name;
  final String homepage;
  final List<FeedEndpoint> Function(String rsshub) endpoints;

  const NewsSource({required this.id, required this.name, required this.homepage, required this.endpoints});

  SourceRef get ref => SourceRef(id, name);
}

const defaultRssHub = 'https://rsshub.app';

/// 主流中文 Web3 媒体
final List<NewsSource> allSources = [
  NewsSource(
    id: 'blockbeats',
    name: '律动 BlockBeats',
    homepage: 'https://www.theblockbeats.info',
    endpoints: (h) => [
      const FeedEndpoint(
        'https://api.theblockbeats.news/v1/open-api/open-flash?size=50&page=1&type=push&lang=cn',
        parseBlockBeats,
      ),
      FeedEndpoint('$h/theblockbeats/newsflash', parseFeed),
    ],
  ),
  NewsSource(
    id: 'jinse',
    name: '金色财经',
    homepage: 'https://www.jinse.cn',
    endpoints: (h) => [
      const FeedEndpoint(
        'https://api.jinse.cn/noah/v2/lives?limit=50&reading=false&source=web&flag=down&id=0&category=0',
        parseJinse,
      ),
      FeedEndpoint('$h/jinse/lives', parseFeed),
    ],
  ),
  NewsSource(
    id: 'odaily',
    name: 'Odaily 星球日报',
    homepage: 'https://www.odaily.news',
    endpoints: (h) => [
      const FeedEndpoint('https://rss.odaily.news/rss/newsflash', parseFeed),
      FeedEndpoint('$h/odaily/newsflash', parseFeed),
    ],
  ),
  NewsSource(
    id: 'panews',
    name: 'PANews',
    homepage: 'https://www.panewslab.com',
    endpoints: (h) => [
      const FeedEndpoint('https://rss.panewslab.com/zh/tvsq/rss', parseFeed),
      FeedEndpoint('$h/panewslab/newsflash', parseFeed),
    ],
  ),
  NewsSource(
    id: 'chaincatcher',
    name: '链捕手 ChainCatcher',
    homepage: 'https://www.chaincatcher.com',
    endpoints: (h) => [FeedEndpoint('$h/chaincatcher/news', parseFeed)],
  ),
  NewsSource(
    id: 'techflow',
    name: '深潮 TechFlow',
    homepage: 'https://www.techflowpost.com',
    endpoints: (h) => [
      const FeedEndpoint('https://www.techflowpost.com/rss.aspx', parseFeed),
      FeedEndpoint('$h/techflowpost/express', parseFeed),
    ],
  ),
  NewsSource(
    id: 'foresight',
    name: 'Foresight News',
    homepage: 'https://foresightnews.pro',
    endpoints: (h) => [FeedEndpoint('$h/foresightnews/news', parseFeed)],
  ),
];

NewsSource? sourceById(String id) {
  for (final s in allSources) {
    if (s.id == id) return s;
  }
  return null;
}
