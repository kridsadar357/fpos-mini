import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class SankeyNode {
  final String id;
  final String label;
  final int column;
  final double value;
  final Color color;

  const SankeyNode({
    required this.id,
    required this.label,
    required this.column,
    required this.value,
    required this.color,
  });
}

class SankeyLink {
  final String sourceId;
  final String targetId;
  final double value;
  final Color color;

  const SankeyLink({
    required this.sourceId,
    required this.targetId,
    required this.value,
    required this.color,
  });
}

class SankeyFlowChart extends StatelessWidget {
  final List<SankeyNode> nodes;
  final List<SankeyLink> links;

  const SankeyFlowChart({
    super.key,
    required this.nodes,
    required this.links,
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty || links.isEmpty) {
      return const Center(
        child: Text(
          'ไม่มีข้อมูลสำหรับ Sankey',
          style: TextStyle(color: AppColors.greyMedium),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _SankeyPainter(nodes: nodes, links: links),
        );
      },
    );
  }
}

class _SankeyPainter extends CustomPainter {
  static const _nodeBarW = 16.0;
  static const _padH = 8.0;
  static const _padV = 10.0;
  static const _nodeGap = 5.0;
  static const _headerH = 14.0;
  static const _minNodeH = 10.0;
  static const _minLinkH = 3.0;

  final List<SankeyNode> nodes;
  final List<SankeyLink> links;

  _SankeyPainter({required this.nodes, required this.links});

  @override
  void paint(Canvas canvas, Size size) {
    final columns = <int, List<SankeyNode>>{};
    for (final n in nodes) {
      columns.putIfAbsent(n.column, () => []).add(n);
    }
    if (columns.isEmpty) return;

    final colKeys = columns.keys.toList()..sort();
    final colCount = colKeys.length;
    final labelW = math.min(80.0, size.width * 0.2);
    final flowCount = math.max(1, colCount - 1);
    final flowW = (size.width -
            _padH * 2 -
            labelW -
            _nodeBarW * colCount) /
        flowCount;

    final colBarX = <int, double>{};
    var x = _padH + labelW;
    for (var i = 0; i < colKeys.length; i++) {
      colBarX[colKeys[i]] = x;
      x += _nodeBarW + (i < colCount - 1 ? flowW : 0);
    }

    _drawHeaders(canvas, colBarX, colKeys);

    final usableH = size.height - _padV * 2 - _headerH;
    final nodeLayouts = <String, _NodeLayout>{};
    final maxColTotal = colKeys
        .map((c) => columns[c]!.fold(0.0, (s, n) => s + n.value))
        .reduce(math.max);

    for (final col in colKeys) {
      final list = [...columns[col]!]..sort((a, b) => b.value.compareTo(a.value));
      final colTotal = list.fold(0.0, (s, n) => s + n.value);
      if (colTotal <= 0) continue;

      final stackH = usableH * (colTotal / maxColTotal);
      final top = _padV + _headerH + (usableH - stackH) / 2;
      var y = top;
      final barX = colBarX[col]!;

      for (final n in list) {
        final gapShare = _nodeGap * (list.length - 1) / list.length;
        final h = math.max(
          _minNodeH,
          stackH * (n.value / colTotal) - gapShare,
        );
        nodeLayouts[n.id] = _NodeLayout(
          rect: Rect.fromLTWH(barX, y, _nodeBarW, h),
          node: n,
          column: col,
        );
        y += h + _nodeGap;
      }
    }

    final sortedLinks = [...links]..sort((a, b) {
        final sa = nodeLayouts[a.sourceId]?.rect.top ?? 0;
        final sb = nodeLayouts[b.sourceId]?.rect.top ?? 0;
        if ((sa - sb).abs() > 0.5) return sa.compareTo(sb);
        final ta = nodeLayouts[a.targetId]?.rect.top ?? 0;
        final tb = nodeLayouts[b.targetId]?.rect.top ?? 0;
        return ta.compareTo(tb);
      });

    for (final layout in nodeLayouts.values) {
      layout.outOffset = 0;
      layout.inOffset = 0;
    }

    for (final link in sortedLinks) {
      final src = nodeLayouts[link.sourceId];
      final dst = nodeLayouts[link.targetId];
      if (src == null || dst == null) continue;
      if (src.node.value <= 0 || dst.node.value <= 0) continue;

      final linkH = math.max(
        _minLinkH,
        math.min(
          src.rect.height * (link.value / src.node.value),
          dst.rect.height * (link.value / dst.node.value),
        ),
      );

      final srcTop = src.rect.top + src.outOffset;
      final dstTop = dst.rect.top + dst.inOffset;
      src.outOffset += linkH;
      dst.inOffset += linkH;

      _drawFlow(
        canvas,
        srcRect: src.rect,
        dstRect: dst.rect,
        srcTop: srcTop,
        dstTop: dstTop,
        linkH: linkH,
        color: link.color,
      );
    }

    for (final layout in nodeLayouts.values) {
      _drawNode(canvas, layout, labelW);
    }
  }

  void _drawHeaders(Canvas canvas, Map<int, double> colBarX, List<int> colKeys) {
    const headers = ['กะ', 'ชนิด', 'ชำระ'];
    for (var i = 0; i < colKeys.length; i++) {
      final header = i < headers.length ? headers[i] : '';
      final tp = TextPainter(
        text: TextSpan(
          text: header,
          style: const TextStyle(
            color: AppColors.greyMedium,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(colBarX[colKeys[i]]!, 0));
    }
  }

  void _drawFlow(
    Canvas canvas, {
    required Rect srcRect,
    required Rect dstRect,
    required double srcTop,
    required double dstTop,
    required double linkH,
    required Color color,
  }) {
    final x0 = srcRect.right;
    final x1 = dstRect.left;
    final cx = (x0 + x1) / 2;

    final path = Path()
      ..moveTo(x0, srcTop)
      ..cubicTo(cx, srcTop, cx, dstTop, x1, dstTop)
      ..lineTo(x1, dstTop + linkH)
      ..cubicTo(cx, dstTop + linkH, cx, srcTop + linkH, x0, srcTop + linkH)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.32)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawNode(Canvas canvas, _NodeLayout layout, double labelW) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(layout.rect, const Radius.circular(3)),
      Paint()..color = layout.node.color,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: layout.node.label,
        style: const TextStyle(
          color: AppColors.greyDark,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: labelW - 6);

    final Offset pos;
    if (layout.column == 0) {
      pos = Offset(
        layout.rect.left - tp.width - 6,
        layout.rect.center.dy - tp.height / 2,
      );
    } else {
      pos = Offset(
        layout.rect.right + 6,
        layout.rect.center.dy - tp.height / 2,
      );
      final bg = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          pos.dx - 2,
          pos.dy - 1,
          tp.width + 4,
          tp.height + 2,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        bg,
        Paint()..color = AppColors.white.withValues(alpha: 0.85),
      );
    }
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter oldDelegate) =>
      oldDelegate.nodes != nodes || oldDelegate.links != links;
}

class _NodeLayout {
  final Rect rect;
  final SankeyNode node;
  final int column;
  double outOffset = 0;
  double inOffset = 0;

  _NodeLayout({
    required this.rect,
    required this.node,
    required this.column,
  });
}
