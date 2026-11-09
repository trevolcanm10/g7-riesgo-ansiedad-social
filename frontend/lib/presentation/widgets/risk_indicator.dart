import 'package:flutter/material.dart';

/// Widget que muestra visualmente el nivel de riesgo con un indicador de color
class RiskIndicator extends StatelessWidget {
  final double probabilidad;
  final String nivelRiesgo;

  const RiskIndicator({
    super.key,
    required this.probabilidad,
    required this.nivelRiesgo,
  });

  Color get _color {
    switch (nivelRiesgo.toUpperCase()) {
      case 'BAJO':
        return Colors.green;
      case 'MEDIO':
        return Colors.orange;
      case 'ALTO':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get _icon {
    switch (nivelRiesgo.toUpperCase()) {
      case 'BAJO':
        return Icons.check_circle;
      case 'MEDIO':
        return Icons.warning;
      case 'ALTO':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(_icon, size: 64, color: _color),
          const SizedBox(height: 16),
          Text(
            nivelRiesgo,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(probabilidad * 100).toStringAsFixed(1)}% de probabilidad',
            style: TextStyle(fontSize: 16, color: _color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}