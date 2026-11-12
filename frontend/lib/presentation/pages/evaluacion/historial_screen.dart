import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../domain/entities/evaluacion.dart';
import '../../viewmodels/evaluacion_viewmodel.dart';
import '../../widgets/risk_indicator.dart';

List<Evaluacion> ordenarHistorialCronologico(Iterable<Evaluacion> historial) {
  final ordered = historial.toList();
  ordered.sort((a, b) {
    final aDate = DateTime.tryParse(a.fechaRealizacion ?? '');
    final bDate = DateTime.tryParse(b.fechaRealizacion ?? '');
    if (aDate == null && bDate == null) return a.idEvaluacion.compareTo(b.idEvaluacion);
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    final byDate = aDate.compareTo(bDate);
    return byDate == 0 ? a.idEvaluacion.compareTo(b.idEvaluacion) : byDate;
  });
  return ordered;
}

List<Evaluacion> puntosDeRiesgo(Iterable<Evaluacion> historial) =>
    ordenarHistorialCronologico(historial).where((e) {
      final p = e.resultado?.probabilidadAnsiedad;
      return DateTime.tryParse(e.fechaRealizacion ?? '') != null &&
          p != null && p.isFinite && p >= 0 && p <= 1;
    }).toList();

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});
  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EvaluacionViewModel>().obtenerHistorial();
    });
  }

  String _fecha(Evaluacion eval) {
    final date = DateTime.tryParse(eval.fechaRealizacion ?? '');
    if (date == null) return 'Fecha no disponible';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  void _showResult(Evaluacion eval) {
    final result = eval.resultado;
    if (result == null) return;
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text('Evaluación · ${_fecha(eval)}'),
      content: SingleChildScrollView(child: RiskIndicator(
        probabilidad: result.probabilidadAnsiedad,
        nivelRiesgo: result.nivelRiesgo,
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: Consumer<EvaluacionViewModel>(builder: (context, evVM, _) {
        if (evVM.isLoading) return const Center(child: CircularProgressIndicator());
        if (evVM.error != null) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(evVM.error!, textAlign: TextAlign.center, style: TextStyle(color: colors.danger)),
            TextButton(onPressed: evVM.obtenerHistorial, child: const Text('Reintentar')),
          ]));
        }
        final records = ordenarHistorialCronologico(evVM.historial);
        if (records.isEmpty) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay evaluaciones realizadas aún.'),
          ]));
        }
        final points = puntosDeRiesgo(records);
        return RefreshIndicator(
          onRefresh: evVM.obtenerHistorial,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(color: colors.card, child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Evolución del riesgo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                const SizedBox(height: 4),
                Text('Probabilidad de ansiedad registrada', style: TextStyle(color: colors.textTertiary)),
                const SizedBox(height: 12),
                if (points.isEmpty)
                  const Text('No hay evaluaciones con fecha y puntuación válidas para graficar.')
                else ...[
                  if (points.length == 1) const Text('Un solo registro disponible.'),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(
                    width: math.max(MediaQuery.sizeOf(context).width - 64, points.length * 64.0 + 56),
                    height: 190,
                    child: LayoutBuilder(builder: (context, constraints) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final width = constraints.maxWidth - 52;
                        final step = points.length > 1 ? width / (points.length - 1) : 0.0;
                        final index = points.length == 1 ? 0 : ((details.localPosition.dx - 40) / step).round().clamp(0, points.length - 1);
                        final x = points.length == 1 ? 40 + width / 2 : 40 + index * step;
                        final y = 12 + (1 - points[index].resultado!.probabilidadAnsiedad) * 136;
                        if ((details.localPosition - Offset(x, y)).distance <= 24) _showResult(points[index]);
                      },
                      child: CustomPaint(painter: _RiskChartPainter(points: points, color: colors.primary, grid: colors.border, text: colors.textTertiary)),
                    )),
                  )),
                  Text('Toca un punto para consultar su resultado.', style: TextStyle(fontSize: 12, color: colors.textTertiary)),
                ],
              ],
            ))),
            const SizedBox(height: 12),
            ...records.map((eval) {
              final res = eval.resultado;
              final valid = res != null && res.probabilidadAnsiedad.isFinite && res.probabilidadAnsiedad >= 0 && res.probabilidadAnsiedad <= 1;
              return Card(color: colors.card, margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                onTap: valid ? () => _showResult(eval) : null,
                leading: Icon(
                  res?.nivelRiesgo == 'BAJO' ? Icons.check_circle : res?.nivelRiesgo == 'MEDIO' ? Icons.warning : Icons.error,
                  color: res?.nivelRiesgo == 'BAJO' ? Colors.green : res?.nivelRiesgo == 'MEDIO' ? Colors.orange : colors.danger,
                ),
                title: Text(res?.nivelRiesgo ?? 'Sin resultado'),
                subtitle: Text(valid ? 'Probabilidad: ${(res.probabilidadAnsiedad * 100).toStringAsFixed(1)}%' : 'Probabilidad: N/A'),
                trailing: Text(_fecha(eval), style: TextStyle(color: colors.textSecondary)),
              ));
            }),
          ]),
        );
      }),
    );
  }
}

class _RiskChartPainter extends CustomPainter {
  final List<Evaluacion> points;
  final Color color;
  final Color grid;
  final Color text;
  const _RiskChartPainter({required this.points, required this.color, required this.grid, required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0;
    const top = 12.0;
    const height = 136.0;
    final width = size.width - 52;
    final gridPaint = Paint()..color = grid..strokeWidth = 1;
    for (final percent in [0, 25, 50, 75, 100]) {
      final y = top + (100 - percent) / 100 * height;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), gridPaint);
      _label(canvas, '$percent%', Offset(0, y - 7));
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1 ? left + width / 2 : left + i * width / (points.length - 1);
      final y = top + (1 - points[i].resultado!.probabilidadAnsiedad) * height;
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = color);
      final date = DateTime.parse(points[i].fechaRealizacion!).toLocal();
      _label(canvas, '${date.day}/${date.month}', Offset(x - 14, top + height + 10));
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke);
  }

  void _label(Canvas canvas, String value, Offset offset) {
    final painter = TextPainter(text: TextSpan(text: value, style: TextStyle(fontSize: 10, color: text)), textDirection: TextDirection.ltr)..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _RiskChartPainter oldDelegate) => oldDelegate.points != points || oldDelegate.color != color || oldDelegate.grid != grid || oldDelegate.text != text;
}
