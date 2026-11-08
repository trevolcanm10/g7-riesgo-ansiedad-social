import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../core/constants.dart';

/// Modal para crear o editar un usuario desde el admin.
class AdminUserForm extends StatefulWidget {
  final Map<String, dynamic>? usuario;

  const AdminUserForm({super.key, this.usuario});

  @override
  State<AdminUserForm> createState() => _AdminUserFormState();
}

class _AdminUserFormState extends State<AdminUserForm> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  final _facultadCtrl = TextEditingController();
  final _cicloCtrl = TextEditingController();
  String _rol = 'Estudiante';
  bool _isLoading = false;
  bool get _isEditing => widget.usuario != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final u = widget.usuario!;
      _nombreCtrl.text = u['nombre'] ?? '';
      _correoCtrl.text = u['correo'] ?? '';
      _facultadCtrl.text = u['facultad'] ?? '';
      _cicloCtrl.text = u['ciclo']?.toString() ?? '';
      _rol = u['rol'] ?? 'Estudiante';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _contrasenaCtrl.dispose();
    _facultadCtrl.dispose();
    _cicloCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiService = context.read<ApiService>();

      final body = {
        'nombre': _nombreCtrl.text.trim(),
        'correo': _correoCtrl.text.trim(),
        'rol': _rol,
        if (_rol == 'Estudiante') ...{
          if (_facultadCtrl.text.trim().isNotEmpty)
            'facultad': _facultadCtrl.text.trim(),
          if (_cicloCtrl.text.trim().isNotEmpty)
            'ciclo': int.tryParse(_cicloCtrl.text.trim()),
        },
      };

      if (_isEditing) {
        await apiService.put(
          AppConstants.adminUsuarioById(widget.usuario!['id_usuario']),
          body: body,
        );
      } else {
        body['contrasena'] = _contrasenaCtrl.text.trim();
        await apiService.post(AppConstants.adminUsuarios, body: body);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final title = _isEditing ? 'Editar Usuario' : 'Crear Usuario';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _guardar,
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  )
                : Text(
                    'Guardar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Información del Usuario',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _buildField(
                colors: colors,
                controller: _nombreCtrl,
                label: 'Nombre completo',
                icon: PhosphorIcons.user,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              _buildField(
                colors: colors,
                controller: _correoCtrl,
                label: 'Correo electrónico',
                icon: PhosphorIcons.envelope,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo requerido';
                  if (!v.contains('@')) return 'Correo inválido';
                  return null;
                },
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 16),
                _buildField(
                  colors: colors,
                  controller: _contrasenaCtrl,
                  label: 'Contraseña',
                  icon: PhosphorIcons.lock,
                  obscureText: true,
                  validator: (v) {
                    if (_isEditing) return null;
                    if (v == null || v.trim().isEmpty) return 'Campo requerido';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              // Rol selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: DropdownButtonFormField<String>(
                  value: _rol,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: 'Rol',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Estudiante', child: Text('Estudiante')),
                    DropdownMenuItem(value: 'Medico', child: Text('Médico')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _rol = v;

                        if (v != 'Estudiante') {
                          _facultadCtrl.clear();
                          _cicloCtrl.clear();
                        }
                      });
                    }
                  },
                ),
              ),
              if (_rol == 'Estudiante') ...[
                const SizedBox(height: 16),
                _buildField(
                  colors: colors,
                  controller: _facultadCtrl,
                  label: 'Facultad',
                  icon: PhosphorIcons.building,
                ),
                const SizedBox(height: 16),
                _buildField(
                  colors: colors,
                  controller: _cicloCtrl,
                  label: 'Ciclo',
                  icon: PhosphorIcons.hash,
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    _isEditing ? 'Actualizar Usuario' : 'Crear Usuario',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required AppColors colors,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: TextStyle(color: colors.textSecondary),
          prefixIcon: PhosphorIcon(icon, size: 20, color: colors.iconMuted),
        ),
      ),
    );
  }
}