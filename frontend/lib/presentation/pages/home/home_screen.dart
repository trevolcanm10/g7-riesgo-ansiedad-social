import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../presentation/viewmodels/evaluacion_viewmodel.dart';
import '../../../presentation/viewmodels/auth_viewmodel.dart';
import '../../../domain/entities/evaluacion.dart';

String formatStudentDashboardDate(DateTime date) {
  const weekdays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]}';
}

/// Dashboard principal con vista de bienestar mental dinámica en español
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Cargar historial real de evaluaciones del usuario al entrar al dashboard
      context.read<EvaluacionViewModel>().obtenerHistorial();
    });
  }

  String _formatearFecha(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'No disponible';
    try {
      final dateTime = DateTime.parse(dateStr).toLocal();
      return 'Último test: ${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} a las ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      if (dateStr.length >= 10) {
        return 'Último test: ${dateStr.substring(0, 10)}';
      }
      return 'Último test: $dateStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final evaluacionVM = context.watch<EvaluacionViewModel>();
    final nombreUsuario = authVM.nombre?.trim().isNotEmpty == true
        ? authVM.nombre!.trim().split(RegExp(r'\s+')).first
        : 'Estudiante';
    final historial = evaluacionVM.historial;
    final tieneHistorial = historial.isNotEmpty;
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: evaluacionVM.obtenerHistorial,
                color: colors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(nombreUsuario),
                          const SizedBox(height: 28),
                          _buildWelcomeCard(tieneHistorial: tieneHistorial),
                          const SizedBox(height: 16),
                          _buildQuickAccess(colors),
                          const SizedBox(height: 34),
                          _buildInfoSection(colors),
                          if (evaluacionVM.isLoading && !tieneHistorial) ...[
                            const SizedBox(height: 24),
                            Center(
                              child: CircularProgressIndicator(
                                color: colors.primary,
                              ),
                            ),
                          ],
                          if (tieneHistorial) ...[
                            const SizedBox(height: 32),
                            _buildRiskCard(historial.first),
                            const SizedBox(height: 16),
                            _buildTrendChart(historial),
                            const SizedBox(height: 16),
                            _buildSecondaryMetrics(historial.first),
                            const SizedBox(height: 16),
                            _buildStartEvaluationButton(esNuevo: false),
                            const SizedBox(height: 16),
                            _buildQuickTip(historial.first),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HEADER
  // ==========================================
  Widget _buildHeader(String nombre) {
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatStudentDashboardDate(DateTime.now()),
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\u00a1Hola, $nombre!',
                style: TextStyle(
                  fontSize: 30,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: colors.primaryLight,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.psychology_outlined,
            color: colors.primary,
            size: 30,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard({required bool tieneHistorial}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 350;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF716BF4), Color(0xFF514EDC)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x305654DA),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -45,
                top: -75,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x18FFFFFF),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 68,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x16FFFFFF),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 24,
                  34,
                  compact ? 20 : 24,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0x24FFFFFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'TU ESPACIO SEGURO',
                      style: TextStyle(
                        color: Color(0xFFE7E7FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bienestar que te acompa\u00f1a',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 27 : 31,
                        height: 1.08,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Descubre c\u00f3mo te sientes y recibe orientaci\u00f3n hecha para ti.',
                      style: TextStyle(
                        color: Color(0xFFEDEBFF),
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/evaluacion'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF514CE8),
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                tieneHistorial
                                    ? 'Iniciar nueva evaluaci\u00f3n'
                                    : 'Iniciar mi primera evaluaci\u00f3n',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 21),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TARJETA DE RIESGO DINÁMICA
  // ==========================================
  Widget _buildRiskCard(Evaluacion ultimaEval) {
    final resultado = ultimaEval.resultado;
    final String nivelRiesgo = resultado?.nivelRiesgo ?? 'BAJO';
    final double probabilidad = resultado?.probabilidadAnsiedad ?? 0.0;

    // Configuración visual según nivel de riesgo
    Color baseColor;
    Color bgCardColor;
    Color borderColor;
    IconData riskIcon;
    String labelRiesgo;

    switch (nivelRiesgo.toUpperCase()) {
      case 'ALTO':
        baseColor = const Color(0xFFDC2626);
        bgCardColor = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFFCA5A5);
        riskIcon = Icons.error_outline_rounded;
        labelRiesgo = 'Alto';
        break;
      case 'MEDIO':
        baseColor = const Color(0xFFD97706);
        bgCardColor = const Color(0xFFFFF7ED);
        borderColor = const Color(0xFFFDBA74);
        riskIcon = Icons.warning_amber_rounded;
        labelRiesgo = 'Medio';
        break;
      case 'BAJO':
      default:
        baseColor = const Color(0xFF059669);
        bgCardColor = const Color(0xFFECFDF5);
        borderColor = const Color(0xFF6EE7B7);
        riskIcon = Icons.check_circle_outline_rounded;
        labelRiesgo = 'Bajo';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgCardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
      ),
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
                      'Nivel de Riesgo Actual',
                      style: TextStyle(
                        fontSize: 13,
                        color: baseColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labelRiesgo,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: baseColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Probabilidad de Ansiedad',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: baseColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(probabilidad * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: baseColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(riskIcon, size: 32, color: baseColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: probabilidad,
              minHeight: 8,
              backgroundColor: baseColor.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(baseColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatearFecha(ultimaEval.fechaRealizacion),
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // GRÁFICO DE TENDENCIA (DATOS REALES)
  // ==========================================
  Widget _buildTrendChart(List<Evaluacion> historialCompleto) {
    // Tomar las últimas 7 evaluaciones en orden cronológico (las más antiguas a las más recientes)
    final evaluacionesOrdenadas = historialCompleto.reversed.toList();
    List<Evaluacion> ultimasEval = evaluacionesOrdenadas;
    if (evaluacionesOrdenadas.length > 7) {
      ultimasEval = evaluacionesOrdenadas.sublist(
        evaluacionesOrdenadas.length - 7,
      );
    }

    final List<double> dataPoints = ultimasEval
        .map(
          (e) => (e.resultado?.probabilidadAnsiedad as num?)?.toDouble() ?? 0.0,
        )
        .toList();

    final List<String> labels = ultimasEval.map((e) {
      if (e.fechaRealizacion == null) return '';
      try {
        final dt = DateTime.parse(e.fechaRealizacion!);
        return '${dt.day}/${dt.month}';
      } catch (_) {
        return '';
      }
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tendencia de Ansiedad',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tus niveles de probabilidad de riesgo registrados en el tiempo',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _TrendChartPainter(
                dataPoints: dataPoints,
                labels: labels,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // METRICAS SECUNDARIAS
  // ==========================================
  Widget _buildSecondaryMetrics(Evaluacion ultimaEval) {
    // Mapeo dinámico de datos de la base de datos
    final sleep = (ultimaEval.sleepHours as num?)?.toDouble() ?? 0.0;
    final exercise = (ultimaEval.exerciseFreq as num?)?.toDouble() ?? 0.0;
    final stressLvlVal = (ultimaEval.academicStress as num?)?.toDouble() ?? 5.0;

    String stressLabel = 'Medio';
    Color stressColor = const Color(0xFFF59E0B);
    Color stressBg = const Color(0xFFFEF3C7);

    if (stressLvlVal <= 3.0) {
      stressLabel = 'Bajo';
      stressColor = const Color(0xFF10B981);
      stressBg = const Color(0xFFD1FAE5);
    } else if (stressLvlVal >= 8.0) {
      stressLabel = 'Alto';
      stressColor = const Color(0xFFEF4444);
      stressBg = const Color(0xFFFEE2E2);
    }

    return Column(
      children: [
        Row(
          children: [
            // Sleep Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.nightlight_round,
                            size: 20,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        const Text(
                          'Sueño',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${sleep.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Promedio diario',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Stress Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: stressBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.bolt, size: 20, color: stressColor),
                        ),
                        const Text(
                          'Estrés',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      stressLabel,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: stressColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Carga de estudio',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Activity Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 22,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${exercise.toStringAsFixed(0)} ${exercise == 1 ? "día" : "días"}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Frecuencia semanal de deporte',
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Activo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BOTÓN DE NUEVA EVALUACIÓN
  // ==========================================
  Widget _buildStartEvaluationButton({required bool esNuevo}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: () => Navigator.pushNamed(context, '/evaluacion'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          elevation: esNuevo ? 8 : 4,
          shadowColor: const Color(0xFF6366F1).withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              esNuevo
                  ? 'Iniciar mi primera evaluación'
                  : 'Iniciar Nueva Evaluación',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 22),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CONSEJO RÁPIDO (DASHBOARD ACTIVADO)
  // ==========================================
  Widget _buildQuickTip(Evaluacion ultimaEval) {
    String tipText =
        'Mantener rutinas fijas de descanso ayuda notablemente a estabilizar tus niveles de ansiedad.';
    if (ultimaEval.sleepHours < 6.0) {
      tipText =
          'Notamos que duermes menos de 6 horas. Un sueño insuficiente aumenta la vulnerabilidad al estrés.';
    } else if (ultimaEval.exerciseFreq < 2) {
      tipText =
          'Agregar una sesión corta de caminata o estiramiento de 15 minutos puede ayudarte a disminuir la tensión.';
    } else if (ultimaEval.academicStress > 7) {
      tipText =
          'El estrés por estudios se nota elevado. Realiza pausas activas de 5 minutos por cada 45 minutos de estudio.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFC7D2FE).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFDBEAFE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              size: 18,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consejo de Bienestar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tipText,
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF475569).withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccess(AppColors colors) {
    return Column(
      children: [
        _buildAccessCard(
          colors: colors,
          icon: Icons.sentiment_satisfied_alt_outlined,
          eyebrow: 'CHECK-IN DIARIO',
          title: '¿Cómo te sientes hoy?',
          description: 'Próximamente',
        ),
        const SizedBox(height: 12),
        _buildAccessCard(
          colors: colors,
          icon: Icons.verified_user_outlined,
          eyebrow: 'APOYO UNIVERSITARIO',
          title: 'Orientación UNAYOE',
          description: 'Próximamente',
          tinted: true,
        ),
        const SizedBox(height: 12),
        _buildAccessCard(
          colors: colors,
          icon: Icons.event_available_outlined,
          eyebrow: 'ORGANIZACIÓN ACADÉMICA',
          title: 'Agenda Académica',
          description: 'Revisa entregas, exámenes y proyectos',
          onTap: () => Navigator.pushNamed(context, '/agenda'),
        ),
      ],
    );
  }

  Widget _buildAccessCard({
    required AppColors colors,
    required IconData icon,
    required String eyebrow,
    required String title,
    required String description,
    VoidCallback? onTap,
    bool tinted = false,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tinted ? const Color(0xFFF0F5FF) : colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E7F3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tinted ? colors.primary : colors.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: tinted ? Colors.white : colors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
        ],
      ),
    );
    return onTap == null
        ? card
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: card,
          );
  }

  Widget _buildInfoSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UN PASO A LA VEZ',
          style: TextStyle(
            color: colors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '¿Cómo funciona?',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        _buildStepCard(
          colors,
          Icons.psychology_outlined,
          'PASO 01',
          'Conócete mejor',
          'Responde evaluaciones breves diseñadas por especialistas.',
        ),
        const SizedBox(height: 12),
        _buildStepCard(
          colors,
          Icons.bar_chart_rounded,
          'PASO 02',
          'Comprende tus resultados',
          'Recibe información clara y recomendaciones personalizadas.',
        ),
        const SizedBox(height: 12),
        _buildStepCard(
          colors,
          Icons.event_available_outlined,
          'PASO 03',
          'Avanza a tu ritmo',
          'Revisa tu progreso cuando quieras.',
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F7F2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_rounded, color: Color(0xFF2D806F)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recuerda: no estás solo. Estamos aquí para acompañarte.',
                  style: TextStyle(color: Color(0xFF267665), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard(
    AppColors colors,
    IconData icon,
    String eyebrow,
    String title,
    String description,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E7F3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: colors.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: colors.primary, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // NAV BAR INFERIOR
  // ==========================================
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildNavItem(
                  index: 0,
                  icon: Icons.home_rounded,
                  label: 'Inicio',
                  isActive: _currentNavIndex == 0,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  index: 1,
                  icon: Icons.calendar_month_outlined,
                  label: 'Agenda',
                  isActive: _currentNavIndex == 1,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  index: 2,
                  icon: Icons.show_chart_rounded,
                  label: 'Historial',
                  isActive: _currentNavIndex == 2,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  index: 3,
                  icon: Icons.person_outline_rounded,
                  label: 'Perfil',
                  isActive: _currentNavIndex == 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentNavIndex = index;
        });
        switch (index) {
          case 0:
            // Ya estamos aquí
            break;
          case 1:
            Navigator.pushNamed(context, '/agenda');
            break;
          case 2:
            Navigator.pushNamed(context, '/historial');
            break;
          case 3:
            Navigator.pushNamed(context, '/perfil');
            break;
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PAINTER DEL GRÁFICO (DATOS REALES)
// ==========================================
class _TrendChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final List<String> labels;

  _TrendChartPainter({required this.dataPoints, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final width = size.width;
    final height = size.height;

    final yLabels = ['100%', '75%', '50%', '25%', '0%'];

    const paddingLeft = 35.0;
    const paddingRight = 16.0;
    const paddingTop = 10.0;
    const paddingBottom = 28.0;

    final chartWidth = width - paddingLeft - paddingRight;
    final chartHeight = height - paddingTop - paddingBottom;

    // Dibujar rejilla horizontal (discontinua)
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      final y = paddingTop + (chartHeight / 4) * i;
      final dashCount = (chartWidth / 8).floor();
      for (int j = 0; j < dashCount; j += 2) {
        final startX = paddingLeft + (chartWidth / dashCount) * j;
        final endX = paddingLeft + (chartWidth / dashCount) * (j + 1);
        canvas.drawLine(Offset(startX, y), Offset(endX, y), gridPaint);
      }
    }

    // Dibujar etiquetas eje Y
    final yLabelPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < yLabels.length; i++) {
      yLabelPainter.text = TextSpan(
        text: yLabels[i],
        style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
      );
      yLabelPainter.layout();
      final y = paddingTop + (chartHeight / 4) * i - 6;
      yLabelPainter.paint(canvas, Offset(0, y));
    }

    // Calcular coordenadas de los puntos
    final points = <Offset>[];
    final count = dataPoints.length;
    for (int i = 0; i < count; i++) {
      final double xFactor = count > 1 ? i / (count - 1) : 0.5;
      final x = paddingLeft + chartWidth * xFactor;
      final y = paddingTop + chartHeight * (1 - dataPoints[i]);
      points.add(Offset(x, y));
    }

    if (count > 1) {
      // Gradiente bajo la curva
      final fillPath = Path();
      fillPath.moveTo(points.first.dx, paddingTop + chartHeight);
      for (final point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(points.last.dx, paddingTop + chartHeight);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF6366F1).withOpacity(0.2),
            const Color(0xFF6366F1).withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, width, height));

      canvas.drawPath(fillPath, fillPaint);

      // Dibujar línea principal
      final linePaint = Paint()
        ..color = const Color(0xFF6366F1)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(linePath, linePaint);
    }

    // Dibujar puntos
    final dotPaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final point in points) {
      canvas.drawCircle(point, 5, dotBorderPaint);
      canvas.drawCircle(point, 3.5, dotPaint);
    }

    // Dibujar etiquetas de X
    final xLabelPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < labels.length; i++) {
      xLabelPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
      );
      xLabelPainter.layout();
      final double xFactor = count > 1 ? i / (count - 1) : 0.5;
      final x = paddingLeft + chartWidth * xFactor;
      xLabelPainter.paint(
        canvas,
        Offset(x - xLabelPainter.width / 2, paddingTop + chartHeight + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints || oldDelegate.labels != labels;
  }
}
