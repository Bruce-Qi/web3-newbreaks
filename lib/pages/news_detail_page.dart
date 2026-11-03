import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news_item.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class NewsDetailPage extends StatelessWidget {
  final NewsItem item;
  const NewsDetailPage({super.key, required this.item});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(item.link);
    if (uri == null || !uri.hasScheme) return;
    Future<bool> tryLaunch(LaunchMode mode) async {
      try {
        return await launchUrl(uri, mode: mode);
      } catch (_) {
        return false;
      }
    }

    // 手机端用应用内浏览器打开；macOS 等不支持时回退到系统浏览器
    final ok =
        await tryLaunch(LaunchMode.inAppBrowserView) || await tryLaunch(LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final hasLink = item.link.startsWith('http');
    return Scaffold(
      appBar: AppBar(
        title: Text(item.sourceName),
        actions: [
          if (hasLink)
            IconButton(
              tooltip: '复制链接',
              icon: const Icon(Icons.link),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: item.link));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('链接已复制')));
              },
            ),
        ],
      ),
      body: MaxWidth(
        width: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            SelectableText(
              item.title,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.35),
            ),
            const SizedBox(height: 10),
            Text(
              [item.sourceName, if (item.publishedAt != null) formatDateTime(item.publishedAt!)].join(' · '),
              style: TextStyle(color: muted),
            ),
            if (item.imageUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  item.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SelectableText(
              item.content.isEmpty ? '（此条资讯无正文摘要，请阅读原文）' : item.content,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.75),
            ),
            if (hasLink) ...[
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => _open(context),
                icon: const Icon(Icons.open_in_new),
                label: const Text('阅读原文'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
