import 'package:flutter/material.dart';

import '../services/news_sources.dart';
import '../services/settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _hub;
  late final TextEditingController _cgKey;

  @override
  void initState() {
    super.initState();
    final s = SettingsScope.read(context);
    _hub = TextEditingController(text: s.rsshub);
    _cgKey = TextEditingController(text: s.coingeckoKey);
  }

  @override
  void dispose() {
    _hub.dispose();
    _cgKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final theme = Theme.of(context);
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(t, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: [
              header('资讯来源'),
              for (final src in allSources)
                SwitchListTile(
                  title: Text(src.name),
                  subtitle: Text(src.homepage, style: const TextStyle(fontSize: 12)),
                  value: s.isSourceEnabled(src.id),
                  onChanged: (v) => s.setSourceEnabled(src.id, v),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _hub,
                  decoration: const InputDecoration(
                    labelText: 'RSSHub 地址（备用通道）',
                    helperText: '官方接口失败时通过 RSSHub 抓取；公共实例可能限流，建议填自建实例',
                    helperMaxLines: 2,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: s.setRssHub,
                  onTapOutside: (_) => s.setRssHub(_hub.text),
                ),
              ),
              header('行情'),
              SwitchListTile(
                title: const Text('绿涨红跌'),
                subtitle: Text(s.greenUp ? '当前：绿色上涨，红色下跌' : '当前：红色上涨，绿色下跌'),
                value: s.greenUp,
                onChanged: s.setGreenUp,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _cgKey,
                  decoration: const InputDecoration(
                    labelText: 'CoinGecko Demo API Key（可选）',
                    helperText: '不填也可使用；填写免费 Demo Key 可降低被限流的概率',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: s.setCoingeckoKey,
                  onTapOutside: (_) => s.setCoingeckoKey(_cgKey.text),
                ),
              ),
              header('外观'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
                    ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => s.setThemeMode(v.first),
                ),
              ),
              const SizedBox(height: 24),
              const ListTile(
                title: Text('关于'),
                subtitle: Text('资讯内容版权归各媒体所有，本应用仅做聚合展示。\n行情数据：CoinGecko / Binance，仅供参考，不构成投资建议。'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
