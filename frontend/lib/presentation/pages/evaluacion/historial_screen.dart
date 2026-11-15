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
    if (aDate == null && bDate == null) {
      return a.idEvaluacion.compareTo(b.idEvaluacion);
    }
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
          p != null &&
          p.isFinite &&
          p >= 0 &&
          p <= 1;
    }).toList();

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});
  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  bool _following = false;
  String _riskFilter = 'Todas';
  int? _selectedPointId;
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

  String _fechaHora(Evaluacion eval) {
    final date = DateTime.tryParse(eval.fechaRealizacion ?? '')?.toLocal();
    if (date == null) return 'Fecha no disponible';
    return '${_fecha(eval)} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} · #${eval.idEvaluacion}';
  }

  bool _valid(Evaluacion eval) {
    final p = eval.resultado?.probabilidadAnsiedad;
    return p != null && p.isFinite && p >= 0 && p <= 1;
  }

  String _nivel(String? level) => switch (level?.toUpperCase()) {
    'BAJO' => 'Riesgo Bajo',
    'MEDIO' || 'MODERADO' => 'Riesgo Moderado',
    'ALTO' => 'Riesgo Alto',
    _ => 'Sin resultado',
  };

  Color _riskColor(String? level) => switch (level?.toUpperCase()) {
    'BAJO' => const Color(0xFF208E74),
    'MEDIO' || 'MODERADO' => const Color(0xFFB87916),
    'ALTO' => const Color(0xFFC84C5D),
    _ => const Color(0xFF64748B),
  };

  void _showResult(Evaluacion eval) {
    final result = eval.resultado;
    if (result == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Evaluación · ${_fechaHora(eval)}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RiskIndicator(
                  probabilidad: result.probabilidadAnsiedad,
                  nivelRiesgo: result.nivelRiesgo,
                ),
                const SizedBox(height: 18),
                Text(
                  '¿Qué influyó en tu resultado?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (result.shapExplanation?.disponible == true &&
                    result.shapExplanation!.factores.isNotEmpty)
                  ...result.shapExplanation!.factores.map(
                    (factor) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            factor.direccion == 'aumenta'
                                ? Icons.trending_up
                                : factor.direccion == 'disminuye'
                                ? Icons.trending_down
                                : Icons.trending_flat,
                            size: 20,
                            color: factor.direccion == 'aumenta'
                                ? const Color(0xFFC84C5D)
                                : const Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(factor.nombre)),
                          Text(
                            factor.direccion,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Text('Explicación no disponible para esta evaluación.'),
                if (result.shapExplanation?.disponible == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Factores en escala log-odds; no son porcentajes ni un diagnóstico.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  'Recomendaciones',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (result.recomendaciones.isEmpty)
                  const Text(
                    'No hay recomendaciones guardadas para esta evaluación.',
                  )
                else
                  ...result.recomendaciones.map(
                    (rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rec.titulo,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(rec.descripcion),
                        ],
                      ),
                    ),
                  ),
                if (result.reporteIA != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Reporte de orientación IA',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(result.reporteIA!.resumen),
                  _reportItems('Fortalezas', result.reporteIA!.fortalezas),
                  _reportItems(
                    'Factores a considerar',
                    result.reporteIA!.factoresPreocupantes,
                  ),
                  _reportItems(
                    'Recomendaciones IA',
                    result.reporteIA!.recomendaciones,
                  ),
                  _reportItems('Plan de 7 días', result.reporteIA!.plan7Dias),
                  _reportItems(
                    'Videos sugeridos',
                    result.reporteIA!.temasVideos,
                  ),
                  _reportItems(
                    'Lecturas sugeridas',
                    result.reporteIA!.temasLectura,
                  ),
                  const SizedBox(height: 8),
                  Text('Prioridad: ${result.reporteIA!.prioridadIntervencion}'),
                  Text(result.reporteIA!.mensajeMotivacional),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _reportItems(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ...items.map((item) => Text('• $item')),
        ],
      ),
    );
  }

  Widget _recordCard(Evaluacion eval, AppColors colors) {
    final result = eval.resultado;
    final valid = _valid(eval);
    final riskColor = _riskColor(result?.nivelRiesgo);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: InkWell(
        onTap: valid ? () => _showResult(eval) : null,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(Icons.bar_chart_rounded, color: riskColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fechaHora(eval),
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _nivel(result?.nivelRiesgo),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valid
                          ? 'Probabilidad XGBoost · ${(result!.probabilidadAnsiedad * 100).toStringAsFixed(1)}%'
                          : 'Probabilidad no disponible',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (valid)
                Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chart(List<Evaluacion> points, AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ÚLTIMOS REGISTROS',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Tu evolución',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Probabilidad de riesgo XGBoost',
            style: TextStyle(color: colors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 18),
          if (points.isEmpty)
            const Text(
              'No hay evaluaciones con fecha y probabilidad válidas para graficar.',
            )
          else ...[
            if (points.length == 1) const Text('Un solo registro disponible.'),
            LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(box.maxWidth, points.length * 72.0 + 56),
                  height: 190,
                  child: LayoutBuilder(
                    builder: (context, plot) => GestureDetector(
                      key: const ValueKey('history-chart'),
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final width = plot.maxWidth - 52;
                        final step = points.length > 1
                            ? width / (points.length - 1)
                            : 0.0;
                        final index = points.length == 1
                            ? 0
                            : ((details.localPosition.dx - 40) / step)
                                  .round()
                                  .clamp(0, points.length - 1);
                        final x = points.length == 1
                            ? 40 + width / 2
                            : 40 + index * step;
                        final y =
                            12 +
                            (1 -
                                    points[index]
                                        .resultado!
                                        .probabilidadAnsiedad) *
                                136;
                        if ((details.localPosition - Offset(x, y)).distance <=
                            24) {
                          setState(
                            () => _selectedPointId = points[index].idEvaluacion,
                          );
                        }
                      },
                      child: CustomPaint(
                        painter: _RiskChartPainter(
                          points: points,
                          color: colors.primary,
                          grid: colors.border,
                          text: colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              'Toca un punto para consultar el cambio y abrir su detalle.',
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _selectedPointCard(List<Evaluacion> points, AppColors colors) {
    final index = points.indexWhere((e) => e.idEvaluacion == _selectedPointId);
    if (index < 0) return const SizedBox.shrink();
    final current = points[index];
    final probability = current.resultado!.probabilidadAnsiedad;
    final previous = index > 0
        ? points[index - 1].resultado!.probabilidadAnsiedad
        : null;
    final variation = previous == null
        ? 'Sin registro anterior'
        : '${(probability - previous) >= 0 ? '+' : ''}${((probability - previous) * 100).toStringAsFixed(1)} puntos porcentuales';
    return Container(
      key: const ValueKey('selected-history-point'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fechaHora(current),
            style: TextStyle(color: colors.textTertiary),
          ),
          const SizedBox(height: 6),
          Text(
            _nivel(current.resultado!.nivelRiesgo),
            style: TextStyle(
              color: _riskColor(current.resultado!.nivelRiesgo),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Probabilidad XGBoost: ${(probability * 100).toStringAsFixed(1)}%',
          ),
          Text('Variación: $variation'),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showResult(current),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Ver detalle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Consumer<EvaluacionViewModel>(
          builder: (context, vm, _) {
            final records = ordenarHistorialCronologico(vm.historial);
            final visible = records.reversed.where((eval) {
              if (_riskFilter == 'Todas') return true;
              final level = eval.resultado?.nivelRiesgo.toUpperCase();
              return switch (_riskFilter) {
                'Bajo' => level == 'BAJO',
                'Medio' => level == 'MEDIO' || level == 'MODERADO',
                'Alto' => level == 'ALTO',
                _ => false,
              };
            }).toList();
            return RefreshIndicator(
              onRefresh: vm.obtenerHistorial,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Progreso personal',
                                      style: TextStyle(
                                        color: colors.textTertiary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tu historial',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: colors.primaryLight,
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: Icon(
                                  Icons.psychology_outlined,
                                  color: colors.primary,
                                  size: 30,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: colors.primaryLight,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              children: [
                                _tab('Evaluaciones', false, colors),
                                _tab('Seguimiento', true, colors),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (vm.isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(36),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (vm.error != null)
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    vm.error!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: colors.danger),
                                  ),
                                  TextButton(
                                    onPressed: vm.obtenerHistorial,
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            )
                          else if (records.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  'No hay evaluaciones realizadas aún.',
                                ),
                              ),
                            )
                          else ...[
                            if (_following) ...[
                              _chart(puntosDeRiesgo(records), colors),
                              _selectedPointCard(
                                puntosDeRiesgo(records),
                                colors,
                              ),
                            ] else ...[
                              Text(
                                'EVALUACIONES COMPLETADAS',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 12,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Evaluaciones anteriores',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ['Todas', 'Bajo', 'Medio', 'Alto']
                                    .map(
                                      (level) => ChoiceChip(
                                        label: Text(level),
                                        selected: _riskFilter == level,
                                        onSelected: (_) =>
                                            setState(() => _riskFilter = level),
                                        selectedColor: colors.primaryLight,
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 18),
                              if (visible.isEmpty)
                                Text(
                                  'No hay evaluaciones para este nivel.',
                                  style: TextStyle(color: colors.textTertiary),
                                )
                              else
                                ...visible.map(
                                  (eval) => _recordCard(eval, colors),
                                ),
                            ],
                          ],
                          if (!_following) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/evaluacion'),
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text('Realizar otra evaluación'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tab(String label, bool following, AppColors colors) => Expanded(
    child: InkWell(
      onTap: () => setState(() => _following = following),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          color: _following == following ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: _following == following
                  ? colors.primary
                  : colors.textTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

class _RiskChartPainter extends CustomPainter {
  final List<Evaluacion> points;
  final Color color;
  final Color grid;
  final Color text;
  const _RiskChartPainter({
    required this.points,
    required this.color,
    required this.grid,
    required this.text,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0;
    const top = 12.0;
    const height = 136.0;
    final width = size.width - 52;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final percent in [0, 25, 50, 75, 100]) {
      final y = top + (100 - percent) / 100 * height;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), gridPaint);
      _label(canvas, '$percent%', Offset(0, y - 7));
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? left + width / 2
          : left + i * width / (points.length - 1);
      final y = top + (1 - points[i].resultado!.probabilidadAnsiedad) * height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = color);
      final date = DateTime.parse(points[i].fechaRealizacion!).toLocal();
      _label(
        canvas,
        '${date.day}/${date.month}',
        Offset(x - 14, top + height + 8),
      );
      _label(
        canvas,
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} #${points[i].idEvaluacion}',
        Offset(x - 25, top + height + 22),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  void _label(Canvas canvas, String value, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(fontSize: 10, color: text),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _RiskChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.grid != grid ||
      oldDelegate.text != text;
}
