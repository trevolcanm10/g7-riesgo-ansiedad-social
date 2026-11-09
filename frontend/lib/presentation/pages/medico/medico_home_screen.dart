import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../presentation/viewmodels/auth_viewmodel.dart';
import '../../../presentation/viewmodels/medico_viewmodel.dart';
import 'medico_paciente_detail_screen.dart';
import '../../widgets/animated_counter.dart';
import '../../widgets/animated_donut_chart.dart';

/// Dashboard principal para el rol Médico
class MedicoHomeScreen extends StatefulWidget {
  const MedicoHomeScreen({super.key});

  @override
  State<MedicoHomeScreen> createState() => _MedicoHomeScreenState();
}

class _MedicoHomeScreenState extends State<MedicoHomeScreen> {
  int _currentNavIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MedicoViewModel>().cargarTodo();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(child: _buildCurrentView(colors)),
            _buildBottomNav(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView(AppColors colors) {
    switch (_currentNavIndex) {
      case 0:
        return _buildDashboardView(colors);
      case 1:
        return _buildEvaluacionesView(colors);
      default:
        return _buildDashboardView(colors);
    }
  }

  // ──────────────────── VISTA DASHBOARD ────────────────────
  Widget _buildDashboardView(AppColors colors) {
    final authVM = context.read<AuthViewModel>();
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Buenos días' : hour < 18 ? 'Buenas tardes' : 'Buenas noches';
    final fechaStr = '${now.day} de ${_mes(now.month)}';

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER CON GRADIENTE ──
          FadeInSlide(
            delay: const Duration(milliseconds: 100),
            child: _buildGradientHeader(colors, authVM, greeting, fechaStr),
          ),
          const SizedBox(height: 24),

          // ── ESTADÍSTICAS CON ANIMACIÓN ──
          FadeInSlide(
            delay: const Duration(milliseconds: 300),
            child: _buildStatsGrid(colors),
          ),
          const SizedBox(height: 24),

          // ── GRÁFICO DE DISTRIBUCIÓN ──
          if (!context.watch<MedicoViewModel>().isLoadingStats) ...[
            FadeInSlide(
              delay: const Duration(milliseconds: 500),
              child: _buildDistribucionChart(colors),
            ),
            const SizedBox(height: 24),
          ],

          // ── ACCIONES RÁPIDAS ──
          FadeInSlide(
            delay: const Duration(milliseconds: 700),
            child: _buildQuickActions(colors),
          ),
          const SizedBox(height: 24),

          // ── ACTIVIDAD RECIENTE ──
          FadeInSlide(
            delay: const Duration(milliseconds: 900),
            child: _buildRecentActivity(colors),
          ),
        ],
      ),
    );
  }

  // ──────────────────── HEADER CON GRADIENTE ────────────────────
  Widget _buildGradientHeader(AppColors colors, AuthViewModel authVM, String greeting, String fechaStr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF59E0B),
            Color(0xFFD97706),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, Dr. ${authVM.nombre ?? "Médico"} 👨‍⚕️',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  fechaStr,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Panel de gestión de pacientes',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const PhosphorIcon(
              PhosphorIconsFill.stethoscope,
              size: 28,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────── ESTADÍSTICAS ────────────────────
  Widget _buildStatsGrid(AppColors colors) {
    final medVM = context.watch<MedicoViewModel>();

    if (medVM.isLoadingStats) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    final stats = medVM.estadisticas;
    final totalPacientes = stats?['total_pacientes'] ?? 0;
    final totalEvals = stats?['total_evaluaciones'] ?? 0;
    final distribucion = stats?['distribucion_riesgo'] as Map<String, dynamic>?;
    final riesgoAlto = distribucion?['alto'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen General',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildStatCard(
              colors: colors,
              icon: PhosphorIcons.userList,
              accentColor: const Color(0xFF3B82F6),
              label: 'Pacientes',
              value: totalPacientes,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              colors: colors,
              icon: PhosphorIcons.clipboardText,
              accentColor: const Color(0xFF059669),
              label: 'Evaluaciones',
              value: totalEvals,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              colors: colors,
              icon: PhosphorIcons.warningOctagon,
              accentColor: const Color(0xFFEF4444),
              label: 'Riesgo Alto',
              value: riesgoAlto,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              colors: colors,
              icon: PhosphorIcons.stethoscope,
              accentColor: const Color(0xFFF59E0B),
              label: 'Atendidos hoy',
              value: 0, // Placeholder - podría ampliarse después
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required AppColors colors,
    required IconData icon,
    required Color accentColor,
    required String label,
    required int value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: PhosphorIcon(icon, size: 22, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedCounter(
                    end: value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── GRÁFICO DE DISTRIBUCIÓN ────────────────────
  Widget _buildDistribucionChart(AppColors colors) {
    final medVM = context.watch<MedicoViewModel>();
    final stats = medVM.estadisticas;
    final distribucion = stats?['distribucion_riesgo'] as Map<String, dynamic>?;

    final bajo = distribucion?['bajo'] ?? 0;
    final medio = distribucion?['medio'] ?? 0;
    final alto = distribucion?['alto'] ?? 0;
    final totalRiesgo = bajo + medio + alto;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución de Riesgo',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: totalRiesgo > 0
                    ? AnimatedDonutChart(
                        data: {
                          'bajo': bajo,
                          'medio': medio,
                          'alto': alto,
                        },
                        colors: const {
                          'bajo': Color(0xFF10B981),
                          'medio': Color(0xFFF59E0B),
                          'alto': Color(0xFFEF4444),
                        },
                        size: 140,
                        strokeWidth: 22,
                      )
                    : SizedBox(
                        width: 140,
                        height: 140,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PhosphorIcon(
                                PhosphorIcons.chartPieSlice,
                                size: 40,
                                color: colors.iconMuted,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sin datos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(
                      colors: colors,
                      label: 'Bajo',
                      color: const Color(0xFF10B981),
                      value: bajo,
                    ),
                    const SizedBox(height: 10),
                    _buildLegendItem(
                      colors: colors,
                      label: 'Medio',
                      color: const Color(0xFFF59E0B),
                      value: medio,
                    ),
                    const SizedBox(height: 10),
                    _buildLegendItem(
                      colors: colors,
                      label: 'Alto',
                      color: const Color(0xFFEF4444),
                      value: alto,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required AppColors colors,
    required String label,
    required Color color,
    required int value,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ──────────────────── ACCIONES RÁPIDAS ────────────────────
  Widget _buildQuickActions(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones Rápidas',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildActionCard(
              colors: colors,
              icon: PhosphorIcons.userList,
              color: const Color(0xFF3B82F6),
              label: 'Pacientes',
              onTap: () {
                _setNavIndex(1);
              },
            ),
            const SizedBox(width: 12),
            _buildActionCard(
              colors: colors,
              icon: PhosphorIcons.chartLineUp,
              color: const Color(0xFF059669),
              label: 'Reportes\n',
              onTap: () {
                final medVM = context.read<MedicoViewModel>();
                medVM.cargarEvaluacionesRecientes();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Actualizando reportes...'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: colors.primary,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required AppColors colors,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: PhosphorIcon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────── ACTIVIDAD RECIENTE ────────────────────
  Widget _buildRecentActivity(AppColors colors) {
    final medVM = context.watch<MedicoViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actividad Reciente',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        if (medVM.isLoadingRecientes)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: CircularProgressIndicator(color: colors.primary),
            ),
          )
        else if (medVM.evaluacionesRecientes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                PhosphorIcon(
                  PhosphorIcons.timer,
                  size: 48,
                  color: colors.iconMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'No hay actividad reciente',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Las evaluaciones de tus pacientes aparecerán aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.iconMuted,
                  ),
                ),
              ],
            ),
          )
        else
          ...medVM.evaluacionesRecientes.asMap().entries.map((entry) {
            final index = entry.key;
            final eval = entry.value;
            final nivelRiesgo = eval['nivel_riesgo'] as String? ?? 'N/A';
            final nombrePaciente = eval['nombre_paciente'] as String? ?? '';
            final probabilidad = eval['probabilidad_ansiedad'] != null
                ? ((eval['probabilidad_ansiedad'] as num) * 100).toStringAsFixed(1)
                : 'N/A';
            final fecha = eval['fecha_realizacion'] as String? ?? '';

            return FadeInSlide(
              delay: Duration(milliseconds: 1000 + index * 100),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _getRiesgoColor(nivelRiesgo).withValues(alpha: 0.15),
                      child: PhosphorIcon(
                        _getRiesgoIcon(nivelRiesgo),
                        size: 20,
                        color: _getRiesgoColor(nivelRiesgo),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombrePaciente,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Probabilidad: $probabilidad%',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getRiesgoColor(nivelRiesgo).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            nivelRiesgo,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getRiesgoColor(nivelRiesgo),
                            ),
                          ),
                        ),
                        if (fecha.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatFechaCorta(fecha),
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ──────────────────── VISTA EVALUACIONES ────────────────────
  Widget _buildEvaluacionesView(AppColors colors) {
    final medVM = context.watch<MedicoViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.clipboardText,
                size: 26,
                color: colors.primary,
              ),
              const SizedBox(width: 10),
              Text(
                'Pacientes',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              if (!medVM.isLoadingPacientes)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${medVM.pacientes.length} total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildPacientesList(colors, medVM)),
      ],
    );
  }

  Widget _buildPacientesList(AppColors colors, MedicoViewModel medVM) {
    if (medVM.isLoadingPacientes) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: medVM.pacientes.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.userList,
                    size: 56,
                    color: colors.iconMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No hay pacientes registrados',
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => medVM.cargarPacientes(),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: medVM.pacientes.length,
                itemBuilder: (context, index) {
                  final paciente = medVM.pacientes[index];
                  final nombre = paciente['nombre'] ?? '';
                  final correo = paciente['correo'] ?? '';
                  final ultimoRiesgo = paciente['ultimo_riesgo'] as String?;
                  final ultimaProb = paciente['ultima_probabilidad'];

                  return FadeInSlide(
                    delay: Duration(milliseconds: index * 80),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow,
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ListTile(
                        onTap: () {
                          final idUsuario = paciente['id_usuario'];
                          if (idUsuario != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MedicoPacienteDetailScreen(
                                  userId: idUsuario is int ? idUsuario : int.parse(idUsuario.toString()),
                                ),
                              ),
                            );
                          }
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          child: PhosphorIcon(
                            PhosphorIconsFill.student,
                            size: 20,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                        title: Text(
                          nombre,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          correo,
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        ),
                        trailing: ultimoRiesgo != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getRiesgoColor(ultimoRiesgo).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$ultimoRiesgo${ultimaProb != null ? " (${((ultimaProb as num) * 100).toStringAsFixed(0)}%)" : ""}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getRiesgoColor(ultimoRiesgo),
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.borderLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Sin evaluación',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  // ──────────────────── BOTTOM NAV ────────────────────
  Widget _buildBottomNav(AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
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
              _buildNavItem(index: 0, icon: PhosphorIcons.house, label: 'Inicio'),
              _buildNavItem(index: 1, icon: PhosphorIcons.clipboardText, label: 'Pacientes'),
              _buildNavItem(index: 2, icon: PhosphorIcons.userCircle, label: 'Perfil'),
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
  }) {
    final colors = AppColors.of(context);
    final isActive = _currentNavIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 2) {
          Navigator.pushNamed(context, '/perfil');
        } else {
          _setNavIndex(index);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              icon,
              size: 24,
              color: isActive ? const Color(0xFFF59E0B) : colors.iconMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? const Color(0xFFF59E0B) : colors.iconMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── HELPERS ────────────────────
  void _setNavIndex(int index) {
    setState(() {
      _currentNavIndex = index;
    });
  }

  String _mes(int month) {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return meses[month - 1];
  }

  Color _getRiesgoColor(String nivel) {
    switch (nivel) {
      case 'BAJO':
        return const Color(0xFF10B981);
      case 'MEDIO':
        return const Color(0xFFF59E0B);
      case 'ALTO':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  IconData _getRiesgoIcon(String nivel) {
    switch (nivel) {
      case 'BAJO':
        return PhosphorIcons.smiley;
      case 'MEDIO':
        return PhosphorIcons.warning;
      case 'ALTO':
        return PhosphorIcons.xCircle;
      default:
        return PhosphorIcons.question;
    }
  }

  String _formatFechaCorta(String fecha) {
    try {
      // Handle ISO format: "2026-01-15T10:30:00" -> "15/01/2026"
      final partes = fecha.split('T').first.split('-');
      if (partes.length == 3) {
        return '${partes[2]}/${partes[1]}/${partes[0]}';
      }
      return fecha.substring(0, 10);
    } catch (_) {
      return fecha;
    }
  }
}