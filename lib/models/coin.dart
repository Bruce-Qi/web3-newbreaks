enum PriceSource { coingecko, binance }

extension PriceSourceName on PriceSource {
  String get label => switch (this) {
    PriceSource.coingecko => 'CoinGecko',
    PriceSource.binance => 'Binance (USDT≈USD)',
  };
}

class Coin {
  final String id;
  final String symbol;
  final String name;
  final String? image;
  final int? rank;
  final double? price;
  final double? change24h;
  final double? change7d;
  final double? marketCap;
  final double? volume24h;
  final double? high24h;
  final double? low24h;
  final double? circulatingSupply;
  final double? totalSupply;
  final double? maxSupply;
  final double? ath;
  final double? athChange;
  final List<double> sparkline;
  final PriceSource source;

  const Coin({
    required this.id,
    required this.symbol,
    required this.name,
    required this.source,
    this.image,
    this.rank,
    this.price,
    this.change24h,
    this.change7d,
    this.marketCap,
    this.volume24h,
    this.high24h,
    this.low24h,
    this.circulatingSupply,
    this.totalSupply,
    this.maxSupply,
    this.ath,
    this.athChange,
    this.sparkline = const [],
  });

  String get upperSymbol => symbol.toUpperCase();

  /// 主流币的中文名，没有则返回 null
  String? get chineseName => coinChineseNames[upperSymbol];

  /// 币安对应的 USDT 交易对，用于兜底价格和走势图
  String get binancePair => '${upperSymbol}USDT';

  factory Coin.fromCoinGecko(Map<String, dynamic> j) {
    final spark =
        (j['sparkline_in_7d']?['price'] as List?)?.whereType<num>().map((e) => e.toDouble()).toList() ??
        const <double>[];
    return Coin(
      id: j['id'] as String,
      symbol: (j['symbol'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      image: j['image'] as String?,
      rank: (j['market_cap_rank'] as num?)?.toInt(),
      price: _d(j['current_price']),
      change24h: _d(j['price_change_percentage_24h_in_currency']) ?? _d(j['price_change_percentage_24h']),
      change7d: _d(j['price_change_percentage_7d_in_currency']),
      marketCap: _d(j['market_cap']),
      volume24h: _d(j['total_volume']),
      high24h: _d(j['high_24h']),
      low24h: _d(j['low_24h']),
      circulatingSupply: _d(j['circulating_supply']),
      totalSupply: _d(j['total_supply']),
      maxSupply: _d(j['max_supply']),
      ath: _d(j['ath']),
      athChange: _d(j['ath_change_percentage']),
      sparkline: spark,
      source: PriceSource.coingecko,
    );
  }
}

double? _d(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

double? parseDouble(Object? v) => _d(v);

const coinChineseNames = <String, String>{
  'BTC': '比特币',
  'ETH': '以太坊',
  'USDT': '泰达币',
  'BNB': '币安币',
  'SOL': '索拉纳',
  'XRP': '瑞波币',
  'USDC': 'USD Coin',
  'DOGE': '狗狗币',
  'ADA': '艾达币',
  'TRX': '波场',
  'TON': 'Toncoin',
  'AVAX': '雪崩',
  'SHIB': '柴犬币',
  'LINK': 'Chainlink',
  'DOT': '波卡',
  'BCH': '比特币现金',
  'LTC': '莱特币',
  'NEAR': 'NEAR',
  'UNI': 'Uniswap',
  'ETC': '以太经典',
  'XLM': '恒星币',
  'ATOM': 'Cosmos',
  'FIL': 'Filecoin',
  'ARB': 'Arbitrum',
  'OP': 'Optimism',
  'APT': 'Aptos',
  'SUI': 'Sui',
  'PEPE': '佩佩蛙',
  'POL': 'Polygon',
  'HBAR': 'Hedera',
  'ICP': '互联网计算机',
  'AAVE': 'Aave',
  'INJ': 'Injective',
  'XMR': '门罗币',
  'DAI': 'Dai',
  'WBTC': '包装比特币',
  'STETH': 'Lido 质押 ETH',
};
