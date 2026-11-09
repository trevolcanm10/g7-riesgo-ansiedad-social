import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/escuela.dart';
import '../../../presentation/viewmodels/escuela_viewmodel.dart';
import '../../../presentation/viewmodels/auth_viewmodel.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _codigoController = TextEditingController();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  Escuela? _escuelaSeleccionada;
  int _ciclo = 1; // Ciclo seleccionado por defecto
  bool _enviandoRegistro = false;

  /// Decoración del selector de escuela profesional.
  /// Conserva el mismo diseño visual del resto del formulario.
  InputDecoration get _escuelaDecoration => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: 'Escuela profesional',
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(
          Icons.school_outlined,
          color: Color(0xFF94A3B8),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: Color(0xFF6366F1),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 18,
        ),
      );

  @override
  void initState() {
    super.initState();
    // Inicialización segura: se carga el catálogo después del primer frame
    // para no llamar a notifyListeners() durante la construcción de widgets.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EscuelaViewModel>().cargarEscuelas();
    });
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _codigoController.dispose();
    _correoController.dispose();
    _contrasenaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  /// Valida el formulario y registra al estudiante en el microservicio Users.
  ///
  /// La llamada se realiza a través de [AuthViewModel.registrar] (sin HTTP
  /// directo en el widget) y no envía la confirmación de contraseña.
  Future<void> _handleRegistro() async {
    if (!_formKey.currentState!.validate()) return;
    if (_enviandoRegistro) return;

    final escuela = _escuelaSeleccionada;
    if (escuela == null) return;

    setState(() => _enviandoRegistro = true);

    final authVM = context.read<AuthViewModel>();
    var registroExitoso = false;
    try {
      // AuthViewModel no lanza excepciones: devuelve true en éxito y false
      // almacenando el detalle del backend en authVM.error.
      registroExitoso = await authVM.registrar(
        nombres: _nombresController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        codigo: _codigoController.text.trim(),
        correo: _correoController.text.trim(),
        contrasena: _contrasenaController.text,
        escuela: escuela.nombre,
        ciclo: _ciclo,
      );
    } finally {
      // El indicador de envío se apaga aunque ocurra un error inesperado.
      if (mounted) {
        setState(() => _enviandoRegistro = false);
      }
    }

    if (!mounted) return;

    if (registroExitoso) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '¡Cuenta creada con éxito! Inicia sesión para continuar.',
          ),
          backgroundColor: Color(0xFF6366F1),
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mensajeDeErrorRegistro(authVM.error)),
          backgroundColor: Colors.red,
        ),
      );
      authVM.clearError();
    }
  }

  /// Mensaje legible en español para el error guardado en el ViewModel:
  /// conserva el detalle del backend (400/409) sin prefijos técnicos.
  String _mensajeDeErrorRegistro(String? error) {
    final detalle = (error ?? '')
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();
    if (detalle.isEmpty) {
      return 'No se pudo completar el registro. Inténtalo de nuevo.';
    }
    return detalle;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8E0FF), // pastel lavender top
              Color(0xFFF5F5FC), // whitish-silver center
              Color(0xFFD0F0EC), // soft mint/teal bottom right
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ==========================================
                    // LOGO
                    // ==========================================
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.psychology,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ==========================================
                    // TITLE & SUBTITLE
                    // ==========================================
                    const Text(
                      'Crear Cuenta',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B), // dark navy/slate
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Comienza tu viaje hacia el bienestar mental hoy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF94A3B8), // muted grey/blue
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ==========================================
                    // NOMBRES FIELD
                    // ==========================================
                    TextFormField(
                      controller: _nombresController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Nombres',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, ingresa tus nombres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ==========================================
                    // APELLIDOS FIELD
                    // ==========================================
                    TextFormField(
                      controller: _apellidosController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Apellidos',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, ingresa tus apellidos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ==========================================
                    // CÓDIGO DE ESTUDIANTE FIELD (texto, admite ceros)
                    // ==========================================
                    TextFormField(
                      controller: _codigoController,
                      keyboardType: TextInputType.text,
                      style: const TextStyle(color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Código de estudiante',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(
                          Icons.badge_outlined,
                          color: Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, ingresa tu código de estudiante';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ==========================================
                    // EMAIL FIELD
                    // ==========================================
                    TextFormField(
                      controller: _correoController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Correo electrónico',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, ingresa tu correo';
                        }
                        final correo = value.trim();
                        final regexCorreo = RegExp(
                          r'^[\w.\-]+@([\w\-]+\.)+[\w\-]{2,}$',
                        );
                        if (!regexCorreo.hasMatch(correo)) {
                          return 'Ingresa un correo válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ==========================================
                    // PASSWORD FIELD
                    // ==========================================
                    TextFormField(
                      controller: _contrasenaController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Contraseña',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(
                          Icons.lock_outlined,
                          color: Color(0xFF94A3B8),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa una contraseña';
                        }
                        if (value.length < 6) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ==========================================
                    // CONFIRM PASSWORD FIELD
                    // ==========================================
                    TextFormField(
                      controller: _confirmarController,
                      obscureText: _obscureConfirm,
                      style: const TextStyle(color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Confirmar contraseña',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(
                          Icons.lock_outlined,
                          color: Color(0xFF94A3B8),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirm = !_obscureConfirm;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value != _contrasenaController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // ==========================================
                    // ESCUELA PROFESIONAL FIELD (catálogo local)
                    // ==========================================
                    Consumer<EscuelaViewModel>(
                      builder: (context, escuelaVM, _) {
                        if (escuelaVM.cargando) {
                          return InputDecorator(
                            decoration: _escuelaDecoration,
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Cargando catálogo de escuelas...',
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          );
                        }

                        if (escuelaVM.error != null) {
                          return InputDecorator(
                            decoration: _escuelaDecoration,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'No se pudo cargar el catálogo de escuelas',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: escuelaVM.cargarEscuelas,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          );
                        }

                        // Si un mismo nombre de escuela aparece en más de
                        // una facultad, se muestra la facultad para poder
                        // diferenciarlas en el menú.
                        final nombresVistos = <String>{};
                        final nombresRepetidos = <String>{};
                        for (final escuela in escuelaVM.escuelas) {
                          if (!nombresVistos.add(escuela.nombre)) {
                            nombresRepetidos.add(escuela.nombre);
                          }
                        }

                        return DropdownButtonFormField<Escuela>(
                          initialValue: _escuelaSeleccionada,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          style: const TextStyle(color: Color(0xFF1E293B)),
                          decoration: _escuelaDecoration,
                          items: escuelaVM.escuelas.map((escuela) {
                            final etiqueta = nombresRepetidos
                                    .contains(escuela.nombre)
                                ? '${escuela.nombre} — ${escuela.facultad}'
                                : escuela.nombre;
                            return DropdownMenuItem<Escuela>(
                              value: escuela,
                              child: Text(
                                etiqueta,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          validator: (value) {
                            if (value == null) {
                              return 'Selecciona tu escuela profesional';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              _escuelaSeleccionada = value;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // ==========================================
                    // CICLO FIELD
                    // ==========================================
                    DropdownButtonFormField<int>(
                      initialValue: _ciclo,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Ciclo académico',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          color: Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                      ),
                      items: List.generate(12, (index) {
                        final c = index + 1;
                        return DropdownMenuItem<int>(
                          value: c,
                          child: Text('Ciclo $c'),
                        );
                      }),
                      validator: (value) {
                        if (value == null || value < 1 || value > 12) {
                          return 'Selecciona un ciclo académico (1-12)';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          if (value != null) _ciclo = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // ==========================================
                    // CREATE ACCOUNT BUTTON
                    // ==========================================
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _enviandoRegistro ? null : _handleRegistro,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF6366F1),
                          disabledForegroundColor: Colors.white70,
                          elevation: 8,
                          shadowColor:
                              const Color(0xFF6366F1).withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _enviandoRegistro
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Crear Cuenta',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ==========================================
                    // FOOTER
                    // ==========================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "¿Ya tienes una cuenta? ",
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Inicia sesión',
                            style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}