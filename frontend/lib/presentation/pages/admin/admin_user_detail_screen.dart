import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../core/constants.dart';
import 'admin_user_form.dart';

/// Pantalla de detalle de un usuario (admin) - Muestra info + evaluaciones
class AdminUserDetailScreen extends StatefulWidget {
  final int userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  Map<String, dynamic>? _usuario;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    setState(() => _isLoading = true);
    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.get(
        AppConstants.adminUsuarioById(widget.userId),
      );
      setState(() {
        _usuario = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _eliminarEvaluacion(Map<String, dynamic> evaluacion) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Evaluación'),
        content: Text(
          '¿Estás seguro de eliminar la evaluación #${evaluacion['id_evaluacion']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
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
        AppConstants.adminEvaluacionById(evaluacion['id_evaluacion']),
      );
      await _cargarDetalle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evaluación eliminada')),
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

  Future<void> _abrirFormEditar() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserForm(usuario: _usuario),
      ),
    );
    if (result == true) await _cargarDetalle();
  }

  Future<void> _eliminarUsuario() async {
    final rol = _usuario?['rol'] ?? 'Estudiante';
    final esEstudiante = rol == 'Estudiante';
    final nombre = _usuario?['nombre'] ?? 'este usuario';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Usuario'),
        content: Text(
          esEstudiante
              ? '¿Estás seguro de eliminar a "$nombre"?\n\nSe eliminarán también todas sus evaluaciones y datos asociados.'
              : '¿Estás seguro de eliminar a "$nombre"?',
        ),
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
        AppConstants.adminUsuarioById(widget.userId),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario eliminado')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rol = _usuario?['rol'] ?? 'Estudiante';
    final esEstudiante = rol == 'Estudiante';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_usuario?['nombre'] ?? 'Detalle de Usuario'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        actions: [
          if (_usuario != null) ...[
            IconButton(
              icon: PhosphorIcon(PhosphorIcons.pencil, color: colors.primary),
              onPressed: _abrirFormEditar,
              tooltip: 'Editar Usuario',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _eliminarUsuario,
              tooltip: 'Eliminar Usuario',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _usuario == null
              ? _buildErrorState(colors)
              : RefreshIndicator(
                  onRefresh: _cargarDetalle,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUserInfoCard(colors),
                        if (esEstudiante) ...[
                          const SizedBox(height: 20),
                          _buildEvaluacionesSection(colors),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            PhosphorIcons.warning,
            size: 48,
            color: colors.iconMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'No se pudo cargar el usuario',
            style: TextStyle(fontSize: 15, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _cargarDetalle,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(AppColors colors) {
    final u = _usuario!;
    final rol = u['rol'] ?? 'Estudiante';
    final esEstudiante = rol == 'Estudiante';
    final evaluaciones = esEstudiante
        ? (u['evaluaciones'] as List<dynamic>? ?? [])
        : [];
    final totalEvals = esEstudiante
        ? (u['total_evaluaciones'] ?? evaluaciones.length)
        : 0;

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
        children: [
          // Avatar
          CircleAvatar(
            radius: 36,
            backgroundColor: _getRolColor(rol).withValues(alpha: 0.15),
            child: PhosphorIcon(
              _getRolIcon(rol),
              size: 32,
              color: _getRolColor(rol),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            u['nombre'] ?? '',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getRolColor(rol).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              rol,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _getRolColor(rol),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Datos
          _buildInfoRow(colors, PhosphorIcons.envelope, 'Correo', u['correo'] ?? ''),
          if (esEstudiante &&
              u['facultad'] != null &&
              (u['facultad'] as String).isNotEmpty)
            _buildInfoRow(
              colors,
              PhosphorIcons.building,
              'Facultad',
              u['facultad'],
            ),
          if (esEstudiante && u['ciclo'] != null)
            _buildInfoRow(
              colors,
              PhosphorIcons.hash,
              'Ciclo',
              u['ciclo'].toString(),
            ),
          if (u['fecha_registro'] != null)
            _buildInfoRow(
              colors,
              PhosphorIcons.calendar,
              'Registrado',
              _formatFecha(u['fecha_registro']),
            ),
          const SizedBox(height: 12),
          // Contador de evaluaciones
          if (esEstudiante)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primaryLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    PhosphorIcons.clipboardText,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$totalEvals ${totalEvals == 1 ? 'evaluación' : 'evaluaciones'} realizadas',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(AppColors colors, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          PhosphorIcon(icon, size: 16, color: colors.iconMuted),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluacionesSection(AppColors colors) {
    final evaluaciones = _usuario?['evaluaciones'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.clipboardText,
              size: 20,
              color: colors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Evaluaciones',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (evaluaciones.isEmpty)
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
                  PhosphorIcons.clipboardText,
                  size: 40,
                  color: colors.iconMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'Este usuario no ha realizado evaluaciones',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...evaluaciones.asMap().entries.map((entry) {
            final index = entry.key;
            final eval = entry.value as Map<String, dynamic>;
            final resultado = eval['resultado'] as Map<String, dynamic>?;
            final nivelRiesgo = resultado?['nivel_riesgo'] ?? 'BAJO';
            final probabilidad = (resultado?['probabilidad_ansiedad'] as num?)?.toDouble() ?? 0.0;
            final explicacion = resultado?['explicacion'] as String?;
            final recomendaciones = resultado?['recomendaciones'] as List<dynamic>?;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
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
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _riesgoColor(nivelRiesgo).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Riesgo $nivelRiesgo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _riesgoColor(nivelRiesgo),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${eval['id_evaluacion']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(probabilidad * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _riesgoColor(nivelRiesgo),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _eliminarEvaluacion(eval),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  if (eval['fecha_realizacion'] != null)
                    _buildDetailRow(colors, 'Fecha', _formatFecha(eval['fecha_realizacion'] as String)),
                  if (explicacion != null)
                    _buildDetailRow(colors, 'Explicación', explicacion),
                  if (recomendaciones != null && recomendaciones.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Recomendaciones:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...recomendaciones.map((rec) {
                      final recMap = rec as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PhosphorIcon(
                              PhosphorIcons.lightbulb,
                              size: 16,
                              color: const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recMap['titulo'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    recMap['descripcion'] ?? '',
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
                      );
                    }),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDetailRow(AppColors colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _riesgoColor(String nivel) {
    switch (nivel.toUpperCase()) {
      case 'ALTO':
        return const Color(0xFFEF4444);
      case 'MEDIO':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
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

  String _formatFecha(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
    }
  }
}