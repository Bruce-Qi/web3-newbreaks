import 'dart:async';

import 'package:flutter/material.dart';

import '../models/news_item.dart';
import '../services/news_service.dart';
import '../services/settings.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'news_detail_page.dart';
import 'settings_page.dart';

class NewsPage extends StatefulWidget {
  final NewsService service;
  const NewsPage({super.key, required this.service});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  NewsResult? _result;
  Object? _error;
  bool _loading = false;
  String _filter = 'all';
  String _query = '';
  bool _searching = false;
  String _configKey = '';
  Timer? _ticker;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 每 3 分钟自动刷新一次，同时让“x分钟前”保持更新
    _ticker = Timer.periodic(const Duration(minutes: 3), (_) => _load(silent: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = SettingsScope.of(context);
    final key = '${s.enabledSources.map((e) => e.id).join(',')}|${s.rsshub}';
    if (key != _configKey) {
      _configKey = key;
      if (!s.isSourceEnabled(_filter)) _filter = 'all';
      _load();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_loading) return;
    final s = SettingsScope.read(context);
    setState(() {
      _loading = true;
      if (!silent) _error = null;
    });
    try {
      final r = await widget.service.fetchAll(s.enabledSources, rsshub: s.rsshub);
      if (!mounted) return;
      setState(() {
        _result = r;
        _error = r.items.isEmpty && r.statuses.isNotEmpty ? '所有资讯来源都暂时无法访问' : null;
      });
    } catch (e) {
      if (mounted && !silent) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<NewsItem> get _visible {
    final items = _result?.items ?? const <NewsItem>[];
    final q = _query.trim().toLowerCase();
    return items.where((e) {
      if (_filter != 'all' && e.sourceId != _filter) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) || e.content.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final sources = settings.enabledSources;
    final failed = _result?.statuses.where((s) => !s.ok).toList() ?? const [];
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: '搜索资讯标题或内容', border: InputBorder.none),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Web3 资讯'),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip('all', '全部'),
                for (final s in sources) _chip(s.id, s.name, failed: failed.any((f) => f.sourceId == s.id)),
              ],
            ),
          ),
        ),
      ),
      body: MaxWidth(child: _body(visible, failed)),
    );
  }

  Widget _chip(String id, String label, {bool failed = false}) {
    final selected = _filter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        avatar: failed ? const Icon(Icons.error_outline, size: 16, color: Colors.orange) : null,
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = id),
      ),
    );
  }

  Widget _body(List<NewsItem> visible, List<SourceStatus> failed) {
    if (_result == null) {
      if (_error != null) return ErrorView(message: '加载失败：$_error', onRetry: _load);
      return const Center(child: CircularProgressIndicator());
    }
    if (SettingsScope.read(context).enabledSources.isEmpty) {
      return const Center(child: Text('请在设置中至少开启一个资讯来源'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: visible.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _header(visible.length, failed);
          return _NewsCard(item: visible[i - 1]);
        },
      ),
    );
  }

  Widget _header(int count, List<SourceStatus> failed) {
    final theme = Theme.of(context);
    final r = _result!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              Text('共 $count 条 · 更新于 ${formatClock(r.fetchedAt)}', style: theme.textTheme.bodySmall),
            ],
          ),
          if (failed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: () => _showFailures(failed),
                child: Text(
                  '${failed.map((e) => e.sourceName).join('、')} 暂时无法访问（点击查看详情）',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
                ),
              ),
            ),
          if (count == 0)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: Text('没有符合条件的资讯')),
            ),
        ],
      ),
    );
  }

  void _showFailures(List<SourceStatus> failed) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('以下来源本次抓取失败。若长期失败，可在设置中把 RSSHub 地址换成可访问的实例（如自建）。'),
          const SizedBox(height: 12),
          for (final f in failed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.error_outline, color: Colors.orange),
              title: Text(f.sourceName),
              subtitle: Text(f.error ?? ''),
            ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewsDetailPage(item: item))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.sourceName,
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onPrimaryContainer),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(relativeTime(item.publishedAt), style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
                    ),
                    if (item.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(color: muted, height: 1.45),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.imageUrl != null) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.imageUrl!,
                    width: 96,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
