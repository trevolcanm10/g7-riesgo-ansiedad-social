import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/app_icons.dart';
import '../../../core/app_colors.dart';
import '../../../presentation/viewmodels/auth_viewmodel.dart';
import '../../../presentation/viewmodels/theme_viewmodel.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final themeNotifier = context.watch<ThemeNotifier>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: colors.surface,
        elevation: 0,
        foregroundColor: colors.textPrimary,
      ),
      body: Consumer<AuthViewModel>(
        builder: (context, authVM, _) {
          final usuario = authVM.usuario;
          const rol = 'Sin rol asignado';
          final nombre = authVM.nombre ?? 'Usuario';
          final correo = authVM.correo ?? '';
          final escuela = usuario?.escuela;
          final ciclo = usuario?.ciclo;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar con color según rol
                CircleAvatar(
                  radius: 44,
                  backgroundColor: _getRolColor(rol).withValues(alpha: 0.15),
                  child: PhosphorIcon(
                    _getRolIcon(rol),
                    size: 44,
                    color: _getRolColor(rol),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  nombre,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(correo, style: TextStyle(color: colors.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getRolColor(rol).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rol,
                    style: TextStyle(
                      color: _getRolColor(rol),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Apariencia section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(14),
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
                        'Apariencia',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: PhosphorIcon(
                              themeNotifier.isDark
                                  ? PhosphorIcons.moon
                                  : PhosphorIcons.sun,
                              size: 20,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Modo Oscuro',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  themeNotifier.isDark
                                      ? 'Activado'
                                      : 'Desactivado',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: themeNotifier.isDark,
                            onChanged: (_) => themeNotifier.toggleTheme(),
                            activeThumbColor: colors.primary,
                            inactiveTrackColor: colors.border,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Datos académicos recibidos de Users.
                if (usuario != null) ...[
                  _buildInfoCard(
                    colors: colors,
                    icon: AppIcons.student,
                    label: 'Escuela',
                    value: escuela!,
                  ),
                  if (ciclo != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      colors: colors,
                      icon: PhosphorIcons.calendar,
                      label: 'Ciclo',
                      value: '$ciclo',
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                _buildInfoCard(
                  colors: colors,
                  icon: PhosphorIcons.envelope,
                  label: 'Correo',
                  value: correo,
                ),

                const SizedBox(height: 32),

                // Logout button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: PhosphorIcon(
                      AppIcons.signOutIcon,
                      color: colors.danger,
                    ),
                    title: Text(
                      'Cerrar Sesión',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    trailing: PhosphorIcon(
                      PhosphorIcons.caretRight,
                      size: 18,
                      color: colors.iconMuted,
                    ),
                    onTap: authVM.isLoading
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            final success = await authVM.logout();
                            if (!navigator.mounted) return;
                            navigator.pushNamedAndRemoveUntil(
                              success ? '/login' : '/session',
                              (route) => false,
                            );
                          },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required AppColors colors,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: PhosphorIcon(icon, size: 20, color: colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        return AppIcons.shieldCheckFill;
      case 'Medico':
        return AppIcons.firstAidFill;
      default:
        return AppIcons.student;
    }
  }
}
