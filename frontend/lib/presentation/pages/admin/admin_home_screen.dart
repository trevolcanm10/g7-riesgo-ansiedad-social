import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/app_icons.dart';
import '../../../core/app_colors.dart';
import '../../../presentation/viewmodels/auth_viewmodel.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../core/constants.dart';
import '../../widgets/animated_counter.dart';
import '../../widgets/animated_donut_chart.dart';
import '../../widgets/animated_bar_chart.dart';
import 'admin_user_form.dart';
import 'admin_users_screen.dart';
import 'admin_user_detail_screen.dart';

/// Dashboard principal para el rol Admin
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentNavIndex = 0;
  Map<String, dynamic>? _estadisticas;
  List<dynamic> _usuarios = [];
  bool _isLoadingStats = true;
  bool _isLoadingUsers = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    await Future.wait([
      _cargarEstadisticas(),
      _cargarUsuarios(),
    ]);
  }

  Future<void> _cargarEstadisticas() async {
    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.get(AppConstants.adminEstadisticas);
      setState(() {
        _estadisticas = response;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _cargarUsuarios() async {
    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.getList(AppConstants.adminUsuarios);
      setState(() {
        _usuarios = response;
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingUsers = false;
      });
    }
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
        return _buildUsuariosView(colors);
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

          // ── GRÁFICOS ──
          if (!_isLoadingStats && _estadisticas != null) ...[
            FadeInSlide(
              delay: const Duration(milliseconds: 500),
              child: _buildChartsSection(colors),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
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
                  '$greeting, ${authVM.nombre ?? "Admin"} 👋',
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
                  'Panel de administración del sistema',
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
              PhosphorIconsFill.chartLineUp,
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
    if (_isLoadingStats) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    final stats = _estadisticas;
    final totalUsuarios = stats?['total_usuarios'] ?? 0;
    final totalEvals = stats?['total_evaluaciones'] ?? 0;
    final usuariosPorRol = stats?['usuarios_por_rol'] as Map<String, dynamic>?;

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
              icon: PhosphorIcons.usersThree,
              accentColor: const Color(0xFF6366F1),
              label: 'Usuarios',
              value: totalUsuarios,
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
              icon: PhosphorIcons.graduationCap,
              accentColor: const Color(0xFF3B82F6),
              label: 'Estudiantes',
              value: usuariosPorRol?['estudiantes'] ?? 0,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              colors: colors,
              icon: PhosphorIcons.stethoscope,
              accentColor: const Color(0xFFF59E0B),
              label: 'Médicos',
              value: usuariosPorRol?['medicos'] ?? 0,
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

  // ──────────────────── SECCIÓN DE GRÁFICOS ────────────────────
  Widget _buildChartsSection(AppColors colors) {
    final distribucion = _estadisticas?['distribucion_riesgo'] as Map<String, dynamic>?;
    final usuariosPorRol = _estadisticas?['usuarios_por_rol'] as Map<String, dynamic>?;

    final bajo = distribucion?['bajo'] ?? 0;
    final medio = distribucion?['medio'] ?? 0;
    final alto = distribucion?['alto'] ?? 0;
    final totalRiesgo = bajo + medio + alto;

    final estudiantes = usuariosPorRol?['estudiantes'] ?? 0;
    final medicos = usuariosPorRol?['medicos'] ?? 0;
    final admins = usuariosPorRol?['admins'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Análisis Visual',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Donut chart de distribución de riesgo
            Expanded(
              child: Container(
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
                  children: [
                    Text(
                      'Distribución de Riesgo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Mostrar donut o estado vacío
                    if (totalRiesgo > 0)
                      AnimatedDonutChart(
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
                        size: 150,
                        strokeWidth: 24,
                      )
                    else
                      SizedBox(
                        width: 150,
                        height: 150,
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
                    const SizedBox(height: 16),
                    _buildLegend(colors, distribucion),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Bar chart de usuarios por rol
            Expanded(
              child: Container(
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
                  children: [
                    Text(
                      'Usuarios por Rol',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Mostrar barras o estado vacío
                    if (estudiantes + medicos + admins > 0)
                      AnimatedBarChart(
                        data: {
                          'estudiantes': estudiantes,
                          'medicos': medicos,
                          'admins': admins,
                        },
                        colors: const {
                          'estudiantes': Color(0xFF3B82F6),
                          'medicos': Color(0xFFF59E0B),
                          'admins': Color(0xFF6366F1),
                        },
                        labels: const {
                          'estudiantes': 'Estudiantes',
                          'medicos': 'Médicos',
                          'admins': 'Admins',
                        },
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Column(
                          children: [
                            PhosphorIcon(
                              PhosphorIcons.chartBar,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegend(AppColors colors, Map<String, dynamic>? distribucion) {
    final items = [
      {'label': 'Bajo', 'color': const Color(0xFF10B981), 'value': distribucion?['bajo'] ?? 0},
      {'label': 'Medio', 'color': const Color(0xFFF59E0B), 'value': distribucion?['medio'] ?? 0},
      {'label': 'Alto', 'color': const Color(0xFFEF4444), 'value': distribucion?['alto'] ?? 0},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: item['color'] as Color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${item['label']} (${item['value']})',
              style: TextStyle(
                fontSize: 11,
                color: colors.textSecondary,
              ),
            ),
          ],
        );
      }).toList(),
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
              icon: PhosphorIcons.users,
              color: const Color(0xFF3B82F6),
              label: 'Gestionar\nUsuarios',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                );
              },
            ),
            const SizedBox(width: 12),
            _buildActionCard(
              colors: colors,
              icon: PhosphorIcons.userGear,
              color: const Color(0xFFF59E0B),
              label: 'Mi\nPerfil',
              onTap: () {
                Navigator.pushNamed(context, '/perfil');
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
    final ultimosUsuarios = _usuarios.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Usuarios Recientes',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        if (ultimosUsuarios.isEmpty)
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
                  PhosphorIcons.userPlus,
                  size: 40,
                  color: colors.iconMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'No hay usuarios registrados',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...ultimosUsuarios.asMap().entries.map((entry) {
            final index = entry.key;
            final usuario = entry.value;
            final rol = usuario['rol'] ?? 'Estudiante';
            final nombre = usuario['nombre'] ?? '';
            final correo = usuario['correo'] ?? '';
            final fechaReg = usuario['fecha_registro'] as String?;

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
                      backgroundColor: _getRolColor(rol).withValues(alpha: 0.15),
                      child: PhosphorIcon(
                        _getRolIcon(rol),
                        size: 20,
                        color: _getRolColor(rol),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            correo,
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
                            color: _getRolColor(rol).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            rol,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getRolColor(rol),
                            ),
                          ),
                        ),
                        if (fechaReg != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatFechaCorta(fechaReg),
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

  // ──────────────────── VISTA USUARIOS ────────────────────
  Widget _buildUsuariosView(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              PhosphorIcon(
                AppIcons.usersFill,
                size: 26,
                color: colors.primary,
              ),
              const SizedBox(width: 10),
              Text(
                'Usuarios',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _abrirFormUsuario(null),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: PhosphorIcon(
                        PhosphorIcons.plus,
                        size: 20,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_usuarios.length} total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildUsersList(colors)),
      ],
    );
  }

  Widget _buildUsersList(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingUsers)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: CircularProgressIndicator(color: colors.primary),
              ),
            )
          else if (_usuarios.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  PhosphorIcon(
                    AppIcons.usersIcon,
                    size: 56,
                    color: colors.iconMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No hay usuarios registrados',
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _abrirFormUsuario(null),
                    icon: PhosphorIcon(PhosphorIcons.plus, size: 18),
                    label: const Text('Crear Usuario'),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _cargarUsuarios,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _usuarios.length,
                  itemBuilder: (context, index) {
                    final usuario = _usuarios[index];
                    final rol = usuario['rol'] ?? 'Estudiante';
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: _getRolColor(rol).withValues(alpha: 0.15),
                            child: PhosphorIcon(
                              _getRolIcon(rol),
                              size: 20,
                              color: _getRolColor(rol),
                            ),
                          ),
                          title: Text(
                            usuario['nombre'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            usuario['correo'] ?? '',
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'detalle') {
                                _abrirDetalle(usuario);
                              } else if (action == 'editar') {
                                _abrirFormUsuario(usuario);
                              } else if (action == 'eliminar') {
                                _eliminarUsuario(usuario);
                              } else if (action.startsWith('rol_')) {
                                _cambiarRol(usuario, action.replaceFirst('rol_', ''));
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'detalle', child: ListTile(
                                leading: Icon(Icons.visibility, size: 20),
                                title: Text('Ver detalle'),
                                contentPadding: EdgeInsets.zero,
                              )),
                              const PopupMenuItem(value: 'editar', child: ListTile(
                                leading: Icon(Icons.edit, size: 20),
                                title: Text('Editar'),
                                contentPadding: EdgeInsets.zero,
                              )),
                              PopupMenuItem(value: 'rol_Estudiante', child: ListTile(
                                leading: PhosphorIcon(PhosphorIcons.graduationCap, size: 20),
                                title: const Text('Rol: Estudiante'),
                                contentPadding: EdgeInsets.zero,
                              )),
                              PopupMenuItem(value: 'rol_Medico', child: ListTile(
                                leading: PhosphorIcon(PhosphorIcons.stethoscope, size: 20),
                                title: const Text('Rol: Médico'),
                                contentPadding: EdgeInsets.zero,
                              )),
                              PopupMenuItem(value: 'rol_Admin', child: ListTile(
                                leading: PhosphorIcon(PhosphorIcons.shieldCheck, size: 20),
                                title: const Text('Rol: Admin'),
                                contentPadding: EdgeInsets.zero,
                              )),
                              const PopupMenuDivider(),
                              const PopupMenuItem(value: 'eliminar', child: ListTile(
                                leading: Icon(Icons.delete, size: 20, color: Colors.red),
                                title: Text('Eliminar', style: TextStyle(color: Colors.red)),
                                contentPadding: EdgeInsets.zero,
                              )),
                            ],
                            icon: PhosphorIcon(PhosphorIcons.dotsThreeVertical,
                                size: 20, color: colors.iconMuted),
                          ),
                          onTap: () => _abrirDetalle(usuario),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _abrirFormUsuario(Map<String, dynamic>? usuario) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserForm(usuario: usuario),
      ),
    );
    if (result == true) await _cargarUsuarios();
  }

  Future<void> _abrirDetalle(Map<String, dynamic> usuario) async {
    final userId = usuario['id_usuario'] as int;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserDetailScreen(userId: userId),
      ),
    );
    await _cargarUsuarios();
  }

  Future<void> _eliminarUsuario(Map<String, dynamic> usuario) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Usuario'),
        content: Text('¿Estás seguro de eliminar a "${usuario['nombre']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final apiService = context.read<ApiService>();
      await apiService.delete(
        AppConstants.adminUsuarioById(usuario['id_usuario']),
      );
      await _cargarUsuarios();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cambiarRol(Map<String, dynamic> usuario, String nuevoRol) async {
    try {
      final apiService = context.read<ApiService>();
      await apiService.put(
        AppConstants.adminCambiarRol(usuario['id_usuario']),
        body: {'rol': nuevoRol},
      );
      await _cargarUsuarios();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getRolColor(String rol) {
    switch (rol) {
      case 'Admin':
        return const Color(0xFF6366F1);
      case 'Medico':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _getRolIcon(String rol) {
    switch (rol) {
      case 'Admin':
        return PhosphorIcons.shieldCheck;
      case 'Medico':
        return PhosphorIcons.stethoscope;
      default:
        return PhosphorIcons.graduationCap;
    }
  }

  String _mes(int month) {
    const meses = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return meses[month];
  }

  String _formatFechaCorta(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
    }
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
              _buildNavItem(
                colors: colors,
                index: 0,
                icon: AppIcons.dashboardFill,
                label: 'Inicio',
              ),
              _buildNavItem(
                colors: colors,
                index: 1,
                icon: AppIcons.usersFill,
                label: 'Usuarios',
              ),
              _buildNavItem(
                colors: colors,
                index: 2,
                icon: AppIcons.profileFill,
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required AppColors colors,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isActive = _currentNavIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 2) {
          Navigator.pushNamed(context, '/perfil');
          return;
        }
        setState(() {
          _currentNavIndex = index;
        });
        // Si ya estamos en Dashboard, hacer scroll al inicio
        if (index == 0 && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                color: colors.navActiveBg,
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              icon,
              size: 24,
              color: isActive ? colors.primary : colors.iconMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? colors.primary : colors.iconMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}