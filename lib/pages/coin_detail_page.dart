import 'package:flutter/material.dart';

import '../models/coin.dart';
import '../services/price_service.dart';
import '../services/settings.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class CoinDetailPage extends StatefulWidget {
  final Coin coin;
  final PriceService service;
  const CoinDetailPage({super.key, required this.coin, required this.service});

  @override
  State<CoinDetailPage> createState() => _CoinDetailPageState();
}

class _CoinDetailPageState extends State<CoinDetailPage> {
  ChartRange _range = ChartRange.d7;
  final Map<ChartRange, List<ChartPoint>> _cache = {};
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final range = _range;
    if (_cache.containsKey(range)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pts = await widget.service.fetchChart(
        widget.coin,
        range,
        apiKey: SettingsScope.read(context).coingeckoKey,
      );
      if (mounted) setState(() => _cache[range] = pts);
    } catch (e) {
      if (mounted && _range == range) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final theme = Theme.of(context);
    final c = widget.coin;
    final fav = settings.favorites.contains(c.id);
    final pts = _cache[_range];
    final rangeChange = (pts != null && pts.length > 1 && pts.first.price != 0)
        ? (pts.last.price - pts.first.price) / pts.first.price * 100
        : null;
    final chartColor = settings.changeColor(rangeChange ?? c.change24h);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CoinAvatar(coin: c, size: 26),
            const SizedBox(width: 10),
            Flexible(
              child: Text(c.chineseName != null ? '${c.upperSymbol} · ${c.chineseName}' : c.upperSymbol),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: fav ? '取消自选' : '加入自选',
            icon: Icon(
              fav ? Icons.star_rounded : Icons.star_outline_rounded,
              color: fav ? Colors.amber : null,
            ),
            onPressed: () => settings.toggleFavorite(c.id),
          ),
        ],
      ),
      body: MaxWidth(
        width: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(c.name, style: TextStyle(color: muted)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    formatUsd(c.price),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ChangePill(
                    text: '24h ${formatPercent(c.change24h)}',
                    color: settings.changeColor(c.change24h),
                    filled: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final r in ChartRange.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r.label),
                      selected: r == _range,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _range = r);
                        _load();
                      },
                    ),
                  ),
                const Spacer(),
                if (rangeChange != null)
                  Text(
                    formatPercent(rangeChange),
                    style: TextStyle(color: chartColor, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: pts != null
                  ? PriceChart(points: pts, color: chartColor, range: _range)
                  : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ErrorView(message: '$_error', onRetry: _load),
            ),
            const SizedBox(height: 20),
            Text('数据概览', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _StatsGrid(
              items: [
                ('市值排名', c.rank != null ? '#${c.rank}' : '--'),
                ('市值', formatCompactUsd(c.marketCap)),
                ('24h 成交额', formatCompactUsd(c.volume24h)),
                ('7d 涨跌', formatPercent(c.change7d)),
                ('24h 最高', formatUsd(c.high24h)),
                ('24h 最低', formatUsd(c.low24h)),
                ('流通量', formatAmount(c.circulatingSupply)),
                ('总供应量', formatAmount(c.totalSupply)),
                ('最大供应量', c.maxSupply != null ? formatAmount(c.maxSupply) : '∞ / --'),
                ('历史最高', formatUsd(c.ath)),
                ('距历史最高', formatPercent(c.athChange)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '价格以美元 (USD) 计价，数据来自 ${c.source.label}，仅供参考，不构成投资建议。',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<(String, String)> items;
  const _StatsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 560 ? 3 : 2;
        final w = (c.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (k, v) in items)
              Container(
                width: w,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      k,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
