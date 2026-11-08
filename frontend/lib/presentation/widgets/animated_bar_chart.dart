import 'package:flutter/material.dart';

/// Animated horizontal bar chart for role distribution visualization.
class AnimatedBarChart extends StatefulWidget {
  final Map<String, int> data;
  final Map<String, Color> colors;
  final Map<String, String> labels;
  final Duration duration;

  const AnimatedBarChart({
    super.key,
    required this.data,
    required this.colors,
    required this.labels,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<AnimatedBarChart> createState() => _AnimatedBarChartState();
}

class _AnimatedBarChartState extends State<AnimatedBarChart>
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
    final maxValue = widget.data.values.fold<int>(0, (max, v) => v > max ? v : max);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          children: widget.data.entries.map((entry) {
            final fraction = maxValue > 0 ? entry.value / maxValue : 0.0;
            final barWidth = fraction * _animation.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      widget.labels[entry.key] ?? entry.key,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: widget.colors[entry.key]?.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: barWidth,
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.colors[entry.key] ?? Colors.grey,
                                  (widget.colors[entry.key] ?? Colors.grey)
                                      .withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.colors[entry.key],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}