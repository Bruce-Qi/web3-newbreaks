import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/price_service.dart';
import '../utils/format.dart';

/// 列表里的迷你走势线
class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  const Sparkline({super.key, required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return const SizedBox.shrink();
    return CustomPaint(painter: _SparkPainter(_downsample(data, 60), color));
  }
}

List<double> _downsample(List<double> d, int n) {
  if (d.length <= n) return d;
  final step = d.length / n;
  return List.generate(n, (i) => d[(i * step).floor()])..add(d.last);
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparkPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final minV = data.reduce(math.min), maxV = data.reduce(math.max);
    final range = (maxV - minV) == 0 ? 1 : maxV - minV;
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height - (data[i] - minV) / range * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.data != data || old.color != color;
}

/// 详情页可交互的价格走势图：按住/拖动显示十字线和价格
class PriceChart extends StatefulWidget {
  final List<ChartPoint> points;
  final Color color;
  final ChartRange range;
  const PriceChart({super.key, required this.points, required this.color, required this.range});

  @override
  State<PriceChart> createState() => _PriceChartState();
}

class _PriceChartState extends State<PriceChart> {
  int? _hover;

  void _update(Offset local, double width) {
    final n = widget.points.length;
    if (n < 2) return;
    final i = (local.dx / width * (n - 1)).round().clamp(0, n - 1);
    if (i != _hover) setState(() => _hover = i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pts = widget.points;
    if (pts.length < 2) {
      return const Center(child: Text('暂无走势数据'));
    }
    return LayoutBuilder(
      builder: (context, c) {
        final hovered = _hover != null ? pts[_hover!] : null;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _update(d.localPosition, c.maxWidth),
          onPanUpdate: (d) => _update(d.localPosition, c.maxWidth),
          onPanEnd: (_) => setState(() => _hover = null),
          onPanCancel: () => setState(() => _hover = null),
          child: MouseRegion(
            onHover: (e) => _update(e.localPosition, c.maxWidth),
            onExit: (_) => setState(() => _hover = null),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ChartPainter(
                      pts.map((e) => e.price).toList(),
                      widget.color,
                      _hover,
                      theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      theme.textTheme.labelSmall!.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
                if (hovered != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.inverseSurface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${formatUsd(hovered.price)}   ${formatDateTime(hovered.time)}',
                        style: TextStyle(color: theme.colorScheme.onInverseSurface, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final int? hover;
  final Color guide;
  final TextStyle labelStyle;
  _ChartPainter(this.data, this.color, this.hover, this.guide, this.labelStyle);

  @override
  void paint(Canvas canvas, Size size) {
    const top = 28.0, bottom = 18.0;
    final h = size.height - top - bottom;
    final minV = data.reduce(math.min), maxV = data.reduce(math.max);
    final range = (maxV - minV) == 0 ? 1 : maxV - minV;
    Offset at(int i) => Offset(size.width * i / (data.length - 1), top + h - (data[i] - minV) / range * h);

    final line = Path();
    for (var i = 0; i < data.length; i++) {
      final p = at(i);
      i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, top + h)
      ..lineTo(0, top + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, top, size.width, h)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // 最高 / 最低价标注
    void label(String text, Offset pos) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (pos.dx - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, pos.dy));
    }

    final iMax = data.indexOf(maxV), iMin = data.indexOf(minV);
    label('高 ${formatUsd(maxV)}', at(iMax).translate(0, -16));
    label('低 ${formatUsd(minV)}', at(iMin).translate(0, 4));

    if (hover != null) {
      final p = at(hover!);
      final dash = Paint()
        ..color = guide
        ..strokeWidth = 1;
      canvas.drawLine(Offset(p.dx, top), Offset(p.dx, top + h), dash);
      canvas.drawLine(Offset(0, p.dy), Offset(size.width, p.dy), dash);
      canvas.drawCircle(p, 4.5, Paint()..color = color);
      canvas.drawCircle(
        p,
        4.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.data != data || old.hover != hover || old.color != color;
}
