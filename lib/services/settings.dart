import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'news_sources.dart';

/// 应用设置，持久化在本地
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences? _prefs;

  static Future<AppSettings> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      prefs = null; // 读取失败时使用默认设置
    }
    return AppSettings._(prefs).._read();
  }

  late Set<String> _enabledSources;
  late String _rsshub;
  late bool _greenUp;
  late String _coingeckoKey;
  late Set<String> _favorites;
  late ThemeMode _themeMode;

  void _read() {
    final p = _prefs;
    _enabledSources = (p?.getStringList('sources') ?? allSources.map((s) => s.id).toList()).toSet();
    _rsshub = p?.getString('rsshub') ?? defaultRssHub;
    _greenUp = p?.getBool('greenUp') ?? true;
    _coingeckoKey = p?.getString('cgKey') ?? '';
    _favorites = (p?.getStringList('favorites') ?? const ['bitcoin', 'ethereum']).toSet();
    _themeMode = ThemeMode
        .values[(p?.getInt('theme') ?? ThemeMode.system.index).clamp(0, ThemeMode.values.length - 1)];
  }

  List<NewsSource> get enabledSources => allSources.where((s) => _enabledSources.contains(s.id)).toList();
  bool isSourceEnabled(String id) => _enabledSources.contains(id);
  String get rsshub => _rsshub;
  bool get greenUp => _greenUp;
  String get coingeckoKey => _coingeckoKey;
  Set<String> get favorites => _favorites;
  ThemeMode get themeMode => _themeMode;

  /// 涨跌颜色（绿涨红跌 / 红涨绿跌）
  Color changeColor(double? change) {
    const green = Color(0xFF16C784);
    const red = Color(0xFFEA3943);
    if (change == null || change == 0) return Colors.grey;
    final up = change > 0;
    return (up == _greenUp) ? green : red;
  }

  void setSourceEnabled(String id, bool enabled) {
    if (enabled) {
      _enabledSources.add(id);
    } else {
      _enabledSources.remove(id);
    }
    _prefs?.setStringList('sources', _enabledSources.toList());
    notifyListeners();
  }

  void setRssHub(String v) {
    _rsshub = v.trim().isEmpty ? defaultRssHub : v.trim();
    _prefs?.setString('rsshub', _rsshub);
    notifyListeners();
  }

  void setGreenUp(bool v) {
    _greenUp = v;
    _prefs?.setBool('greenUp', v);
    notifyListeners();
  }

  void setCoingeckoKey(String v) {
    _coingeckoKey = v.trim();
    _prefs?.setString('cgKey', _coingeckoKey);
    notifyListeners();
  }

  void toggleFavorite(String coinId) {
    if (!_favorites.remove(coinId)) _favorites.add(coinId);
    _prefs?.setStringList('favorites', _favorites.toList());
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    _themeMode = m;
    _prefs?.setInt('theme', m.index);
    notifyListeners();
  }
}

/// 通过 InheritedNotifier 向下提供设置
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({super.key, required AppSettings settings, required super.child})
    : super(notifier: settings);

  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;

  static AppSettings read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
