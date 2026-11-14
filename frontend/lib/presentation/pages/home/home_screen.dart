import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../presentation/viewmodels/evaluacion_viewmodel.dart';
import '../../../presentation/viewmodels/auth_viewmodel.dart';

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
            color: Colors.black.withValues(alpha: 0.06),
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
