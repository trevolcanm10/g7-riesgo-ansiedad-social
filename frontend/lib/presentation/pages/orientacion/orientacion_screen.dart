import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/orientacion_viewmodel.dart';
import '../../../domain/entities/solicitud_orientacion.dart';

/// Tokens de diseño estandarizados para el módulo de Orientación
class _OrientacionTokens {
  static const double radiusMd = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusPill = 30.0;

  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color slateDark = Color(0xFF1E293B);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color background = Color(0xFFF8FAFC);
  static const double maxContentWidth = 640.0;
}

class OrientacionScreen extends StatefulWidget {
  const OrientacionScreen({super.key});

  @override
  State<OrientacionScreen> createState() => _OrientacionScreenState();
}

class _OrientacionScreenState extends State<OrientacionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _mensajeController = TextEditingController();
  bool _comparteEvaluacion = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrientacionViewModel>().cargarHistorial();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _submitSolicitud() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<OrientacionViewModel>();
    final mensaje = _mensajeController.text.trim();
    FocusScope.of(context).unfocus();

    final success = await vm.enviarSolicitud(mensaje, _comparteEvaluacion);

    if (!mounted) return;

    if (success) {
      _mensajeController.clear();
      setState(() => _comparteEvaluacion = false);

      if (vm.ultimaAlerta != null) {
        _mostrarAlertaUrgencia(vm.ultimaAlerta!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Solicitud enviada con éxito. UNAYOE responderá pronto.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_OrientacionTokens.radiusMd)),
          ),
        );
      }

      _tabController.animateTo(1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.error ?? 'Error desconocido'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_OrientacionTokens.radiusMd)),
        ),
      );
    }
  }

  void _mostrarAlertaUrgencia(AlertaUrgencia alerta) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_OrientacionTokens.radiusLg)),
        backgroundColor: const Color(0xFFFEF2F2),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 30),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Soporte Inmediato Requerido',
                style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detectamos una situación delicada en tu mensaje. Tu seguridad es nuestra prioridad. Recuerda que la orientación digital no reemplaza la atención de emergencia.',
              style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Líneas comunitarias y de ayuda inmediata:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 13),
            ),
            const SizedBox(height: 10),
            ...alerta.lineasAyuda.map((linea) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_in_talk_rounded, size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      linea,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF7F1D1D), fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _OrientacionTokens.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _OrientacionTokens.slateDark,
        centerTitle: true,
        title: const Text(
          'Orientación Confidencial',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _OrientacionTokens.primary,
          unselectedLabelColor: _OrientacionTokens.slateMuted,
          indicatorColor: _OrientacionTokens.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Solicitar Apoyo', icon: Icon(Icons.edit_note_rounded)),
            Tab(text: 'Mis Solicitudes', icon: Icon(Icons.mark_chat_read_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildForm(),
          _buildHistory(),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _OrientacionTokens.maxContentWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner de Bienvenida estilizado con gradiente
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_OrientacionTokens.primary, _OrientacionTokens.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(_OrientacionTokens.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: _OrientacionTokens.primary.withValues(alpha: 0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_person_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¿Cómo te sientes hoy?',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Espacio protegido y 100% confidencial. El equipo de UNAYOE te orientará.',
                              style: TextStyle(color: Color(0xFFE0E7FF), fontSize: 12.5, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Redacta tu mensaje',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _OrientacionTokens.slateDark),
                ),
                const SizedBox(height: 8),

                // TextArea estilizada con contenedor limpio
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_OrientacionTokens.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _mensajeController,
                    maxLines: 7,
                    maxLength: 1500,
                    style: const TextStyle(fontSize: 14, color: _OrientacionTokens.slateDark),
                    decoration: InputDecoration(
                      hintText: 'Cuéntanos lo que estás pasando o si necesitas apoyo académico, personal o de estrés...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_OrientacionTokens.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_OrientacionTokens.radiusMd),
                        borderSide: const BorderSide(color: _OrientacionTokens.primary, width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Por favor escribe tu mensaje antes de enviar.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Switch Card estilizado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_OrientacionTokens.radiusMd),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.analytics_outlined, color: _OrientacionTokens.primary, size: 22),
                    ),
                    title: const Text(
                      'Compartir mi último test de riesgo',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: _OrientacionTokens.slateDark),
                    ),
                    subtitle: const Text(
                      'Opcional. Permite a UNAYOE darte una respuesta más contextualizada.',
                      style: TextStyle(fontSize: 11.5, color: _OrientacionTokens.slateMuted),
                    ),
                    activeThumbColor: _OrientacionTokens.primary,
                    value: _comparteEvaluacion,
                    onChanged: (val) => setState(() => _comparteEvaluacion = val),
                  ),
                ),
                const SizedBox(height: 28),

                // Botón enviar con gradiente
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Consumer<OrientacionViewModel>(
                    builder: (context, vm, _) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_OrientacionTokens.primary, _OrientacionTokens.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(_OrientacionTokens.radiusPill),
                          boxShadow: [
                            BoxShadow(
                              color: _OrientacionTokens.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: vm.isLoading ? null : _submitSolicitud,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_OrientacionTokens.radiusPill)),
                          ),
                          icon: vm.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                          label: Text(
                            vm.isLoading ? 'Enviando...' : 'Enviar Solicitud Confidencial',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _OrientacionTokens.maxContentWidth),
        child: Consumer<OrientacionViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading && vm.historial.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: _OrientacionTokens.primary));
            }

            if (vm.historial.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.inbox_outlined, size: 48, color: _OrientacionTokens.primary),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No tienes solicitudes previas',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _OrientacionTokens.slateDark),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Las consultas que envíes a UNAYOE aparecerán aquí registradas con su respuesta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _OrientacionTokens.slateMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: vm.cargarHistorial,
              color: _OrientacionTokens.primary,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: vm.historial.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final sol = vm.historial[index];
                  final isAtendida = sol.estado.toLowerCase() == 'atendida';

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_OrientacionTokens.radiusMd),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAtendida ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAtendida ? Icons.check_circle_outline_rounded : Icons.access_time_rounded,
                                    size: 14,
                                    color: isAtendida ? const Color(0xFF047857) : const Color(0xFFB45309),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isAtendida ? 'ATENDIDA' : 'PENDIENTE',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: isAtendida ? const Color(0xFF047857) : const Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (sol.temaSugerido != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  (sol.temaConfirmado ?? sol.temaSugerido!).toUpperCase(),
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _OrientacionTokens.slateMuted),
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (sol.fechaCreacion != null)
                              Text(
                                '${sol.fechaCreacion!.day}/${sol.fechaCreacion!.month}/${sol.fechaCreacion!.year}',
                                style: const TextStyle(fontSize: 11.5, color: _OrientacionTokens.slateMuted),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            sol.mensaje,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _OrientacionTokens.slateDark, fontSize: 13, height: 1.3),
                          ),
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(_OrientacionTokens.radiusMd),
                                bottomRight: Radius.circular(_OrientacionTokens.radiusMd),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tu Mensaje:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _OrientacionTokens.slateMuted)),
                                const SizedBox(height: 4),
                                Text(sol.mensaje, style: const TextStyle(color: _OrientacionTokens.slateDark, fontSize: 13, height: 1.4)),
                                const SizedBox(height: 16),
                                if (isAtendida) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFC7D2FE)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.rate_review_rounded, size: 16, color: _OrientacionTokens.primary),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Respuesta de UNAYOE (${sol.atendidoPor ?? "Orientador"}):',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _OrientacionTokens.primaryDark),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          sol.respuestaEscrita ?? '',
                                          style: const TextStyle(color: _OrientacionTokens.slateDark, fontSize: 13, height: 1.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else
                                  const Row(
                                    children: [
                                      Icon(Icons.hourglass_top_rounded, size: 14, color: _OrientacionTokens.slateMuted),
                                      SizedBox(width: 6),
                                      Text(
                                        'Esperando revisión del orientador...',
                                        style: TextStyle(fontStyle: FontStyle.italic, color: _OrientacionTokens.slateMuted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
