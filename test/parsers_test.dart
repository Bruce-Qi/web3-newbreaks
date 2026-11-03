import 'package:flutter_test/flutter_test.dart';
import 'package:web3_news/models/coin.dart';
import 'package:web3_news/services/feed_parser.dart';
import 'package:web3_news/utils/format.dart';

const src = SourceRef('t', '测试源');

void main() {
  group('RSS / Atom', () {
    test('RSS 2.0 with CDATA, content:encoded and +0800 date', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
<channel><title>x</title>
<item>
  <title><![CDATA[比特币突破 10 万美元]]></title>
  <link>https://example.com/a/1</link>
  <description><![CDATA[<p>短摘要</p>]]></description>
  <content:encoded><![CDATA[<p>据行情显示，<b>BTC</b> 突破 10 万美元。</p><p>第二段&amp;更多</p><img src="https://img.example.com/1.png"/>]]></content:encoded>
  <pubDate>Tue, 03 Nov 2026 18:30:00 +0800</pubDate>
</item>
</channel></rss>''';
      final items = parseFeed(xml, src);
      expect(items, hasLength(1));
      final it = items.single;
      expect(it.title, '比特币突破 10 万美元');
      expect(it.link, 'https://example.com/a/1');
      expect(it.content, contains('BTC 突破 10 万美元'));
      expect(it.content, contains('第二段&更多'));
      expect(it.imageUrl, 'https://img.example.com/1.png');
      expect(it.publishedAt, DateTime.utc(2026, 11, 3, 10, 30));
    });

    test('Atom feed', () {
      const xml = '''<feed xmlns="http://www.w3.org/2005/Atom">
<entry><title>以太坊升级</title><link rel="alternate" href="https://e.com/2"/>
<summary>摘要</summary><updated>2026-11-03T02:00:00Z</updated></entry></feed>''';
      final it = parseFeed(xml, src).single;
      expect(it.title, '以太坊升级');
      expect(it.link, 'https://e.com/2');
      expect(it.publishedAt, DateTime.utc(2026, 11, 3, 2));
    });

    test('RSS item without title derives one from content', () {
      const xml =
          '<rss><channel><item><description>美联储宣布降息。市场反应积极</description><link>https://x/1</link></item></channel></rss>';
      expect(parseFeed(xml, src).single.title, '美联储宣布降息');
    });
  });

  test('BlockBeats JSON', () {
    const body =
        '{"status":0,"data":{"page":1,"data":[{"id":123,"title":"律动标题","content":"<p>正文</p>","link":"https://www.theblockbeats.info/flash/123","create_time":"1762160000"}]}}';
    final it = parseBlockBeats(body, src).single;
    expect(it.title, '律动标题');
    expect(it.content, '正文');
    expect(it.publishedAt, DateTime.fromMillisecondsSinceEpoch(1762160000000, isUtc: true));
  });

  test('Jinse JSON with 【title】 content', () {
    const body =
        '{"news":1,"list":[{"date":"2026-11-03","lives":[{"id":99,"content":"【某交易所上线新币】据官方公告，今日上线。","created_at":1762160000}]}]}';
    final it = parseJinse(body, src).single;
    expect(it.title, '某交易所上线新币');
    expect(it.content, '据官方公告，今日上线。');
    expect(it.link, 'https://www.jinse.cn/lives/99.html');
  });

  test('CoinGecko market item', () {
    final c = Coin.fromCoinGecko({
      'id': 'bitcoin',
      'symbol': 'btc',
      'name': 'Bitcoin',
      'current_price': 98765.43,
      'market_cap_rank': 1,
      'price_change_percentage_24h_in_currency': -1.5,
      'sparkline_in_7d': {
        'price': [1, 2, 3],
      },
    });
    expect(c.upperSymbol, 'BTC');
    expect(c.chineseName, '比特币');
    expect(c.sparkline, [1.0, 2.0, 3.0]);
    expect(c.change24h, -1.5);
  });

  group('format', () {
    test('usd', () {
      expect(formatUsd(98765.432), '\$98,765.43');
      expect(formatUsd(0.4567891), '\$0.4568');
      expect(formatUsd(0.00001234567), '\$0.00001235');
      expect(formatUsd(null), '--');
      expect(formatCompactUsd(1.94e12), '\$1.94T');
      expect(formatPercent(2.345), '+2.35%');
    });
    test('dates', () {
      expect(parseFlexibleDate('2026-11-03 18:00:00'), DateTime.utc(2026, 11, 3, 10));
      expect(parseFlexibleDate('Tue, 03 Nov 2026 10:00:00 GMT'), DateTime.utc(2026, 11, 3, 10));
      final now = DateTime(2026, 11, 3, 12, 0);
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5分钟前');
      expect(relativeTime(now.subtract(const Duration(hours: 2)), now: now), '2小时前');
    });
  });
}
