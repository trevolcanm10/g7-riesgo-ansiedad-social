import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../presentation/viewmodels/evaluacion_viewmodel.dart';
import '../../../presentation/viewmodels/auth_viewmodel.dart';
import '../../../domain/entities/evaluacion.dart';

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

    final nombreUsuario = authVM.nombre ?? 'Estudiante';
    final historial = evaluacionVM.historial;
    final tieneHistorial = historial.isNotEmpty;

    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ==========================================
            // CONTENIDO PRINCIPAL
            // ==========================================
            Expanded(
              child: evaluacionVM.isLoading && historial.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        color: colors.primary,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => evaluacionVM.obtenerHistorial(),
                      color: colors.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(nombreUsuario),
                            const SizedBox(height: 20),

                            if (!tieneHistorial) ...[
                              // ==========================================
                              // PANTALLA DE BIENVENIDA (USUARIO NUEVO)
                              // ==========================================
                              _buildWelcomeCard(),
                              const SizedBox(height: 20),
                              _buildStartEvaluationButton(esNuevo: true),
                              const SizedBox(height: 20),
                              _buildInfoSection(),
                            ] else ...[
                              // ==========================================
                              // DASHBOARD DINÁMICO CON HISTORIAL REAL
                              // ==========================================
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
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
            ),

            // ==========================================
            // BARRA DE NAVEGACIÓN INFERIOR FIJA
            // ==========================================
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¡Hola, $nombre! 👋',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Este es el estado de tu salud y bienestar mental.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TARJETA DE BIENVENIDA (ESTADO VACÍO)
  // ==========================================
  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.spa_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Te damos la bienvenida!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tu salud mental es una prioridad. Realiza tu primera evaluación interactiva para estimar tu riesgo de ansiedad a través de Inteligencia Artificial y obtener recomendaciones preventivas de forma instantánea.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
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
        border: Border.all(
          color: borderColor.withOpacity(0.5),
          width: 1.5,
        ),
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
                child: Icon(
                  riskIcon,
                  size: 32,
                  color: baseColor,
                ),
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
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
            ),
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
      ultimasEval = evaluacionesOrdenadas.sublist(evaluacionesOrdenadas.length - 7);
    }

    final List<double> dataPoints = ultimasEval
        .map((e) => (e.resultado?.probabilidadAnsiedad as num?)?.toDouble() ?? 0.0)
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
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _TrendChartPainter(dataPoints: dataPoints, labels: labels),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
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
                          child: Icon(
                            Icons.bolt,
                            size: 20,
                            color: stressColor,
                          ),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
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
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              esNuevo ? 'Iniciar mi primera evaluación' : 'Iniciar Nueva Evaluación',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
    String tipText = 'Mantener rutinas fijas de descanso ayuda notablemente a estabilizar tus niveles de ansiedad.';
    if (ultimaEval.sleepHours < 6.0) {
      tipText = 'Notamos que duermes menos de 6 horas. Un sueño insuficiente aumenta la vulnerabilidad al estrés.';
    } else if (ultimaEval.exerciseFreq < 2) {
      tipText = 'Agregar una sesión corta de caminata o estiramiento de 15 minutos puede ayudarte a disminuir la tensión.';
    } else if (ultimaEval.academicStress > 7) {
      tipText = 'El estrés por estudios se nota elevado. Realiza pausas activas de 5 minutos por cada 45 minutos de estudio.';
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

  // ==========================================
  // SECCIÓN INFORMATIVA PARA NUEVO USUARIO
  // ==========================================
  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            '¿Cómo funciona?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        _buildInfoTile(
          icon: Icons.shield_outlined,
          title: 'Totalmente Privado',
          description: 'Tus respuestas son confidenciales y se procesan de manera local y encriptada.',
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          icon: Icons.auto_awesome_outlined,
          title: 'Algoritmo Multimodelo',
          description: 'Combinamos predicciones de 6 modelos de Machine Learning para garantizar un resultado preciso.',
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Inicio',
                isActive: _currentNavIndex == 0,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.show_chart_rounded,
                label: 'Historial',
                isActive: _currentNavIndex == 1,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.person_outline_rounded,
                label: 'Perfil',
                isActive: _currentNavIndex == 2,
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
            Navigator.pushNamed(context, '/historial');
            break;
          case 2:
            Navigator.pushNamed(context, '/perfil');
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
              color: isActive ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
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
        canvas.drawLine(
          Offset(startX, y),
          Offset(endX, y),
          gridPaint,
        );
      }
    }

    // Dibujar etiquetas eje Y
    final yLabelPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    for (int i = 0; i < yLabels.length; i++) {
      yLabelPainter.text = TextSpan(
        text: yLabels[i],
        style: const TextStyle(
          fontSize: 9,
          color: Color(0xFF94A3B8),
        ),
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
    final xLabelPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    for (int i = 0; i < labels.length; i++) {
      xLabelPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(
          fontSize: 9,
          color: Color(0xFF94A3B8),
        ),
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