import 'package:flutter/material.dart';

import 'pages/market_page.dart';
import 'pages/news_page.dart';
import 'services/news_service.dart';
import 'services/price_service.dart';
import 'services/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(Web3NewsApp(settings: settings, newsService: NewsService(), priceService: PriceService()));
}

class Web3NewsApp extends StatelessWidget {
  final AppSettings settings;
  final NewsService newsService;
  final PriceService priceService;

  const Web3NewsApp({
    super.key,
    required this.settings,
    required this.newsService,
    required this.priceService,
  });

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3861FB), brightness: b);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: b == Brightness.dark ? const Color(0xFF0D1117) : const Color(0xFFF5F7FA),
      cardTheme: CardThemeData(
        elevation: 0,
        color: b == Brightness.dark ? const Color(0xFF161B22) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: b == Brightness.dark ? const Color(0xFF0D1117) : const Color(0xFFF5F7FA),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: 'Web3 资讯',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          locale: const Locale('zh', 'CN'),
          home: HomeShell(newsService: newsService, priceService: priceService),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  final NewsService newsService;
  final PriceService priceService;
  const HomeShell({super.key, required this.newsService, required this.priceService});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [NewsPage(service: widget.newsService), MarketPage(service: widget.priceService)];
    final body = IndexedStack(index: _index, children: pages);
    final wide = MediaQuery.sizeOf(context).width >= 760;

    if (wide) {
      // macOS / 平板：侧边导航
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.hub_rounded, size: 32, color: Color(0xFF3861FB)),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.article_outlined),
                  selectedIcon: Icon(Icons.article),
                  label: Text('资讯'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.show_chart_outlined),
                  selectedIcon: Icon(Icons.show_chart),
                  label: Text('行情'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: '资讯',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: '行情',
          ),
        ],
      ),
    );
  }
}
