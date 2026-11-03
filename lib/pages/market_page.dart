import 'dart:async';

import 'package:flutter/material.dart';

import '../models/coin.dart';
import '../services/price_service.dart';
import '../services/settings.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'coin_detail_page.dart';
import 'settings_page.dart';

enum SortBy { marketCap, gainers, losers, price, volume }

extension on SortBy {
  String get label => switch (this) {
    SortBy.marketCap => '市值',
    SortBy.gainers => '涨幅榜',
    SortBy.losers => '跌幅榜',
    SortBy.price => '价格',
    SortBy.volume => '成交额',
  };
}

class MarketPage extends StatefulWidget {
  final PriceService service;
  const MarketPage({super.key, required this.service});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  MarketResult? _result;
  Object? _error;
  bool _loading = false;
  bool _favoritesOnly = false;
  SortBy _sort = SortBy.marketCap;
  String _query = '';
  bool _searching = false;
  Timer? _timer;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    // CoinGecko 免费接口有频率限制，60 秒刷新一次比较稳妥
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_loading || !mounted) return;
    setState(() {
      _loading = true;
      if (!silent) _error = null;
    });
    try {
      final r = await widget.service.fetchMarkets(apiKey: SettingsScope.read(context).coingeckoKey);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted && (!silent || _result == null)) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Coin> _visible(AppSettings settings) {
    final q = _query.trim().toLowerCase();
    final list = (_result?.coins ?? const <Coin>[]).where((c) {
      if (_favoritesOnly && !settings.favorites.contains(c.id)) return false;
      if (q.isEmpty) return true;
      return c.symbol.toLowerCase().contains(q) ||
          c.name.toLowerCase().contains(q) ||
          (c.chineseName?.contains(q) ?? false);
    }).toList();
    int cmp(double? a, double? b) => (b ?? double.negativeInfinity).compareTo(a ?? double.negativeInfinity);
    switch (_sort) {
      case SortBy.marketCap:
        list.sort((a, b) => (a.rank ?? 1 << 30).compareTo(b.rank ?? 1 << 30));
      case SortBy.gainers:
        list.sort((a, b) => cmp(a.change24h, b.change24h));
      case SortBy.losers:
        list.sort((a, b) => cmp(b.change24h, a.change24h));
      case SortBy.price:
        list.sort((a, b) => cmp(a.price, b.price));
      case SortBy.volume:
        list.sort((a, b) => cmp(a.volume24h, b.volume24h));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: '搜索币种，如 BTC / 以太坊', border: InputBorder.none),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('行情 · USD'),
        actions: [
          IconButton(
            tooltip: _searching ? '关闭搜索' : '搜索',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _query = '';
                _searchCtrl.clear();
              }
            }),
          ),
          IconButton(tooltip: '刷新', icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.tune),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: MaxWidth(child: _body(settings, theme)),
    );
  }

  Widget _body(AppSettings settings, ThemeData theme) {
    if (_result == null) {
      if (_error != null) return ErrorView(message: '$_error', onRetry: _load);
      return const Center(child: CircularProgressIndicator());
    }
    final r = _result!;
    final coins = _visible(settings);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('全部')),
                  ButtonSegment(value: true, label: Text('自选'), icon: Icon(Icons.star_rounded, size: 16)),
                ],
                selected: {_favoritesOnly},
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: (s) => setState(() => _favoritesOnly = s.first),
              ),
              const Spacer(),
              PopupMenuButton<SortBy>(
                initialValue: _sort,
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => [
                  for (final s in SortBy.values) PopupMenuItem(value: s, child: Text(s.label)),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [const Icon(Icons.sort, size: 18), const SizedBox(width: 4), Text(_sort.label)],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
                ),
              Expanded(
                child: Text(
                  '数据源 ${r.source.label} · 更新于 ${formatClock(r.fetchedAt)}',
                  style: TextStyle(fontSize: 11, color: muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (r.note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(r.note!, style: const TextStyle(fontSize: 11, color: Colors.orange), maxLines: 2),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: DefaultTextStyle(
            style: TextStyle(fontSize: 12, color: muted),
            child: const Row(
              children: [
                Expanded(child: Text('币种 / 市值')),
                SizedBox(width: 120, child: Text('最新价', textAlign: TextAlign.right)),
                SizedBox(width: 12),
                SizedBox(width: 76, child: Text('24h涨跌', textAlign: TextAlign.center)),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: coins.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Center(child: Text(_favoritesOnly ? '还没有自选币种，在详情页点击 ☆ 添加' : '没有找到相关币种')),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: coins.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) => _CoinRow(coin: coins[i], service: widget.service),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CoinRow extends StatelessWidget {
  final Coin coin;
  final PriceService service;
  const _CoinRow({required this.coin, required this.service});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final color = settings.changeColor(coin.change24h);
    final sparkColor = settings.changeColor(
      coin.sparkline.length > 1 ? coin.sparkline.last - coin.sparkline.first : coin.change24h,
    );
    final wide = MediaQuery.sizeOf(context).width > 420;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CoinDetailPage(coin: coin, service: service),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text('${coin.rank ?? ''}', style: TextStyle(fontSize: 12, color: muted)),
            ),
            CoinAvatar(coin: coin, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          coin.upperSymbol,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      if (settings.favorites.contains(coin.id))
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    coin.marketCap != null
                        ? formatCompactUsd(coin.marketCap)
                        : (coin.chineseName ?? coin.name),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            if (wide && coin.sparkline.length > 1)
              SizedBox(
                width: 64,
                height: 26,
                child: Sparkline(data: coin.sparkline, color: sparkColor),
              ),
            SizedBox(
              width: 120,
              child: Text(
                formatUsd(coin.price),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ChangePill(text: formatPercent(coin.change24h), color: color),
          ],
        ),
      ),
    );
  }
}
