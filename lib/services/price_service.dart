import 'dart:convert';

import '../models/coin.dart';
import 'http_util.dart';

enum ChartRange { d1, d7, d30, y1 }

extension ChartRangeX on ChartRange {
  String get label => switch (this) {
    ChartRange.d1 => '24H',
    ChartRange.d7 => '7D',
    ChartRange.d30 => '30D',
    ChartRange.y1 => '1Y',
  };
  int get days => switch (this) {
    ChartRange.d1 => 1,
    ChartRange.d7 => 7,
    ChartRange.d30 => 30,
    ChartRange.y1 => 365,
  };

  /// Binance K 线参数
  (String interval, int limit) get kline => switch (this) {
    ChartRange.d1 => ('15m', 96),
    ChartRange.d7 => ('1h', 168),
    ChartRange.d30 => ('4h', 180),
    ChartRange.y1 => ('1d', 365),
  };
}

class ChartPoint {
  final DateTime time;
  final double price;
  const ChartPoint(this.time, this.price);
}

class MarketResult {
  final List<Coin> coins;
  final PriceSource source;
  final DateTime fetchedAt;
  final String? note;
  const MarketResult(this.coins, this.source, this.fetchedAt, {this.note});
}

const _cg = 'https://api.coingecko.com/api/v3';

/// 币安行情数据镜像（只读行情，不需要账号），失败时再尝试主站
const _binanceHosts = ['https://data-api.binance.vision', 'https://api.binance.com'];

/// CoinGecko 不可用时的兜底币种（按市值大致排序）
const _fallbackCoins = <(String symbol, String name)>[
  ('BTC', 'Bitcoin'),
  ('ETH', 'Ethereum'),
  ('BNB', 'BNB'),
  ('SOL', 'Solana'),
  ('XRP', 'XRP'),
  ('USDC', 'USDC'),
  ('DOGE', 'Dogecoin'),
  ('ADA', 'Cardano'),
  ('TRX', 'TRON'),
  ('TON', 'Toncoin'),
  ('AVAX', 'Avalanche'),
  ('SHIB', 'Shiba Inu'),
  ('LINK', 'Chainlink'),
  ('DOT', 'Polkadot'),
  ('BCH', 'Bitcoin Cash'),
  ('LTC', 'Litecoin'),
  ('NEAR', 'NEAR Protocol'),
  ('UNI', 'Uniswap'),
  ('SUI', 'Sui'),
  ('APT', 'Aptos'),
  ('PEPE', 'Pepe'),
  ('ICP', 'Internet Computer'),
  ('ETC', 'Ethereum Classic'),
  ('XLM', 'Stellar'),
  ('HBAR', 'Hedera'),
  ('POL', 'Polygon'),
  ('ATOM', 'Cosmos'),
  ('FIL', 'Filecoin'),
  ('ARB', 'Arbitrum'),
  ('OP', 'Optimism'),
  ('INJ', 'Injective'),
  ('AAVE', 'Aave'),
];

class PriceService {
  Map<String, String> _cgHeaders(String apiKey) =>
      apiKey.trim().isEmpty ? const {} : {'x-cg-demo-api-key': apiKey.trim()};

  /// 市值前 100 的币种，以美元计价。CoinGecko 优先，失败时回退到币安。
  Future<MarketResult> fetchMarkets({String apiKey = ''}) async {
    Object? cgError;
    try {
      final data = await getJson(
        '$_cg/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1'
        '&sparkline=true&price_change_percentage=24h,7d',
        headers: _cgHeaders(apiKey),
      );
      if (data is List && data.isNotEmpty) {
        final coins = data.whereType<Map<String, dynamic>>().map(Coin.fromCoinGecko).toList();
        return MarketResult(coins, PriceSource.coingecko, DateTime.now());
      }
      cgError = 'CoinGecko 返回为空';
    } catch (e) {
      cgError = e;
    }

    try {
      final coins = await _binanceMarkets();
      return MarketResult(
        coins,
        PriceSource.binance,
        DateTime.now(),
        note: 'CoinGecko 暂不可用（$cgError），已切换至币安行情',
      );
    } catch (e) {
      throw HttpError('行情获取失败\nCoinGecko：$cgError\nBinance：$e');
    }
  }

  Future<List<Coin>> _binanceMarkets() async {
    final pairs = _fallbackCoins.map((c) => '${c.$1}USDT').toList();
    final query = Uri.encodeQueryComponent(jsonEncode(pairs));
    Object? lastError;
    for (final host in _binanceHosts) {
      try {
        dynamic data;
        try {
          data = await getJson('$host/api/v3/ticker/24hr?symbols=$query');
        } on HttpError {
          // 若有交易对下架导致批量查询失败，则拉取全量再过滤
          data = await getJson('$host/api/v3/ticker/24hr', timeout: const Duration(seconds: 20));
        }
        if (data is! List) throw HttpError('币安返回格式异常');
        final bySymbol = {for (final t in data.whereType<Map>()) t['symbol']: t};
        final coins = <Coin>[];
        var rank = 1;
        for (final (sym, name) in _fallbackCoins) {
          final t = bySymbol['${sym}USDT'];
          if (t == null) continue;
          coins.add(
            Coin(
              id: sym.toLowerCase(),
              symbol: sym,
              name: name,
              rank: rank++,
              price: parseDouble(t['lastPrice']),
              change24h: parseDouble(t['priceChangePercent']),
              high24h: parseDouble(t['highPrice']),
              low24h: parseDouble(t['lowPrice']),
              volume24h: parseDouble(t['quoteVolume']),
              source: PriceSource.binance,
            ),
          );
        }
        if (coins.isEmpty) throw HttpError('币安无数据');
        return coins;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? HttpError('未知错误');
  }

  /// 价格走势：CoinGecko → 币安 K 线
  Future<List<ChartPoint>> fetchChart(Coin coin, ChartRange range, {String apiKey = ''}) async {
    Object? cgError;
    if (coin.source == PriceSource.coingecko) {
      try {
        final data = await getJson(
          '$_cg/coins/${coin.id}/market_chart?vs_currency=usd&days=${range.days}',
          headers: _cgHeaders(apiKey),
        );
        final prices = data is Map ? data['prices'] : null;
        if (prices is List && prices.isNotEmpty) {
          return prices
              .whereType<List>()
              .where((p) => p.length >= 2 && p[0] is num && p[1] is num)
              .map(
                (p) => ChartPoint(
                  DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt()),
                  (p[1] as num).toDouble(),
                ),
              )
              .toList();
        }
      } catch (e) {
        cgError = e;
      }
    }

    final (interval, limit) = range.kline;
    Object? lastError;
    for (final host in _binanceHosts) {
      try {
        final data = await getJson(
          '$host/api/v3/klines?symbol=${coin.binancePair}&interval=$interval&limit=$limit',
        );
        if (data is List && data.isNotEmpty) {
          return data
              .whereType<List>()
              .map(
                (k) => ChartPoint(
                  DateTime.fromMillisecondsSinceEpoch((k[0] as num).toInt()),
                  parseDouble(k[4]) ?? 0,
                ),
              )
              .toList();
        }
      } catch (e) {
        lastError = e;
      }
    }
    throw HttpError(
      '走势图获取失败${cgError != null ? '（CoinGecko: $cgError）' : ''}'
      '${lastError != null ? '（Binance: $lastError）' : ''}',
    );
  }
}
