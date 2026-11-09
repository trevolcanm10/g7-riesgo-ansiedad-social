import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_icons.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../core/constants.dart';
import 'admin_user_form.dart';
import 'admin_user_detail_screen.dart';

/// Pantalla de gestión de usuarios para el Admin
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _usuarios = [];
  List<dynamic> _usuariosFiltrados = [];
  bool _isLoading = true;
  String _busqueda = '';
  String _filtroRol = 'Todos';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.getList(AppConstants.adminUsuarios);
      setState(() {
        _usuarios = response;
        _isLoading = false;
        _aplicarFiltros();
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _usuariosFiltrados = _usuarios.where((u) {
        final nombre = (u['nombre'] ?? '').toString().toLowerCase();
        final correo = (u['correo'] ?? '').toString().toLowerCase();
        final q = _busqueda.toLowerCase();
        final coincideBusqueda = q.isEmpty ||
            nombre.contains(q) ||
            correo.contains(q);
        final coincideRol = _filtroRol == 'Todos' ||
            (u['rol'] ?? '').toString() == _filtroRol;
        return coincideBusqueda && coincideRol;
      }).toList();
    });
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

  Future<void> _abrirForm(Map<String, dynamic>? usuario) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserForm(usuario: usuario),
      ),
    );
    if (result == true) await _cargarUsuarios();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final total = _usuarios.length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: PhosphorIcon(PhosphorIcons.plus, color: colors.primary),
            onPressed: () => _abrirForm(null),
            tooltip: 'Crear Usuario',
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            color: colors.surface,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      _busqueda = v;
                      _aplicarFiltros();
                    },
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Buscar por nombre o correo...',
                      hintStyle: TextStyle(color: colors.textSecondary),
                      prefixIcon: PhosphorIcon(
                        PhosphorIcons.magnifyingGlass,
                        size: 20,
                        color: colors.iconMuted,
                      ),
                      suffixIcon: _busqueda.isNotEmpty
                          ? IconButton(
                              icon: PhosphorIcon(
                                PhosphorIcons.x,
                                size: 18,
                                color: colors.iconMuted,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _busqueda = '');
                                _aplicarFiltros();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Filtro por rol
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ['Todos', 'Estudiante', 'Medico', 'Admin']
                        .map((rol) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                  rol == 'Medico' ? 'Médico' : rol,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _filtroRol == rol
                                        ? Colors.white
                                        : colors.textSecondary,
                                  ),
                                ),
                                selected: _filtroRol == rol,
                                selectedColor: colors.primary,
                                checkmarkColor: Colors.white,
                                backgroundColor: colors.background,
                                side: BorderSide(color: colors.border),
                                onSelected: (_) {
                                  setState(() => _filtroRol = rol);
                                  _aplicarFiltros();
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${_usuariosFiltrados.length} de $total usuarios',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de usuarios
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : _usuariosFiltrados.isEmpty
                    ? _buildEmptyState(colors)
                    : RefreshIndicator(
                        onRefresh: _cargarUsuarios,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _usuariosFiltrados.length,
                          itemBuilder: (context, index) =>
                              _buildUserCard(colors, _usuariosFiltrados[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            _busqueda.isNotEmpty
                ? PhosphorIcons.magnifyingGlass
                : AppIcons.usersIcon,
            size: 48,
            color: colors.iconMuted,
          ),
          const SizedBox(height: 12),
          Text(
            _busqueda.isNotEmpty
                ? 'No se encontraron usuarios'
                : 'No hay usuarios registrados',
            style: TextStyle(fontSize: 15, color: colors.textSecondary),
          ),
        ],
      ),
    );
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

  Widget _buildUserCard(AppColors colors, Map<String, dynamic> usuario) {
    final rol = usuario['rol'] ?? 'Estudiante';
    final nombre = usuario['nombre'] ?? '';
    final correo = usuario['correo'] ?? '';

    return Container(
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
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'detalle') {
              _abrirDetalle(usuario);
            } else if (action == 'editar') {
              _abrirForm(usuario);
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
        return PhosphorIcons.shieldCheck;
      case 'Medico':
        return PhosphorIcons.stethoscope;
      default:
        return PhosphorIcons.graduationCap;
    }
  }
}