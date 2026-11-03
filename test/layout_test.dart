// 用假数据渲染两个 tab，检查手机和宽屏下没有布局溢出等异常（不发起网络请求）
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3_news/main.dart';
import 'package:web3_news/models/coin.dart';
import 'package:web3_news/models/news_item.dart';
import 'package:web3_news/services/news_service.dart';
import 'package:web3_news/services/news_sources.dart';
import 'package:web3_news/services/price_service.dart';
import 'package:web3_news/services/settings.dart';

class FakeNews extends NewsService {
  @override
  Future<NewsResult> fetchAll(List<NewsSource> sources, {required String rsshub}) async => NewsResult(
    [
      for (var i = 0; i < 6; i++)
        NewsItem(
          id: '$i',
          title: '测试标题 $i ' * 4,
          summary: '摘要内容 ' * 20,
          content: '正文',
          link: 'https://example.com/$i',
          sourceId: sources[i % sources.length].id,
          sourceName: sources[i % sources.length].name,
          publishedAt: DateTime.now().subtract(Duration(minutes: i * 37)),
        ),
    ],
    [SourceStatus(sourceId: 'foresight', sourceName: 'Foresight News', count: 0, error: 'HTTP 403')],
    DateTime.now(),
  );
}

class FakePrices extends PriceService {
  @override
  Future<MarketResult> fetchMarkets({String apiKey = ''}) async => MarketResult(
    [
      for (var i = 0; i < 8; i++)
        Coin(
          id: 'c$i',
          symbol: i == 0 ? 'btc' : 'longsymbol$i',
          name: 'Coin $i',
          rank: i + 1,
          price: i == 0 ? 123456.78 : 0.00001234 * (i + 1),
          change24h: i.isEven ? 3.21 : -12.34,
          marketCap: 1.9e12 / (i + 1),
          sparkline: [1, 3, 2, 5, 4],
          source: PriceSource.coingecko,
        ),
    ],
    PriceSource.coingecko,
    DateTime.now(),
  );
}

Future<void> pumpApp(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = await AppSettings.load();
  await tester.pumpWidget(
    Web3NewsApp(settings: settings, newsService: FakeNews(), priceService: FakePrices()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final size in const [Size(360, 740), Size(1100, 760)]) {
    testWidgets('news + market tabs render at $size', (tester) async {
      await pumpApp(tester, size);
      expect(find.text('Web3 资讯'), findsWidgets);
      expect(find.textContaining('暂时无法访问'), findsOneWidget);
      await tester.tap(find.text('行情').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('\$123,456.78'), findsOneWidget);
      expect(find.text('+3.21%'), findsWidgets);
      // 打开设置页
      await tester.tap(find.byTooltip('设置').last);
      await tester.pumpAndSettle();
      expect(find.text('资讯来源'), findsOneWidget);
    });
  }
}
