import 'dart:math';
import 'package:flutter/material.dart';

/// Animated donut chart for risk distribution visualization.
class AnimatedDonutChart extends StatefulWidget {
  final Map<String, int> data;
  final Map<String, Color> colors;
  final double size;
  final double strokeWidth;
  final Duration duration;

  const AnimatedDonutChart({
    super.key,
    required this.data,
    required this.colors,
    this.size = 180,
    this.strokeWidth = 28,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<AnimatedDonutChart> createState() => _AnimatedDonutChartState();
}

class _AnimatedDonutChartState extends State<AnimatedDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.data.values.fold<int>(0, (sum, v) => sum + v);
    if (total == 0) return SizedBox(width: widget.size, height: widget.size);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _DonutPainter(
            data: widget.data,
            colors: widget.colors,
            strokeWidth: widget.strokeWidth,
            progress: _animation.value,
            total: total,
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Map<String, int> data;
  final Map<String, Color> colors;
  final double strokeWidth;
  final double progress;
  final int total;

  _DonutPainter({
    required this.data,
    required this.colors,
    required this.strokeWidth,
    required this.progress,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -pi / 2;
    final totalAngle = 2 * pi * progress;

    data.forEach((key, value) {
      final fraction = value / total;
      final sweepAngle = fraction * totalAngle;

      if (sweepAngle > 0) {
        final paint = Paint()
          ..color = colors[key] ?? Colors.grey
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
        startAngle += sweepAngle;
      }
    });
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.data != data;
  }
}