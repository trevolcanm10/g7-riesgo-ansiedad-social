import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../domain/entities/solicitud_orientacion.dart';
import '../../viewmodels/orientacion_viewmodel.dart';

class _OrientacionTokens {
  static const double radiusMd = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 24.0;
  static const double radiusPill = 30.0;
  static const double maxContentWidth = 640.0;
  static const Color heroStart = Color(0xFF6366F1);
  static const Color heroEnd = Color(0xFF4F46E5);
  static const Color success = Color(0xFF047857);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFB45309);
  static const Color warningLight = Color(0xFFFEF3C7);
}

class OrientacionScreen extends StatefulWidget {
  const OrientacionScreen({super.key});

  @override
  State<OrientacionScreen> createState() => _OrientacionScreenState();
}

class _OrientacionScreenState extends State<OrientacionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
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

  AppColors _resolveColors(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light);
  }

  String _formatTema(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'ansiedad_estres':
        return 'Ansiedad y estrés';
      case 'academico':
        return 'Académico';
      case 'economico':
        return 'Económico';
      case 'familiar':
        return 'Familiar';
      case 'personal':
        return 'Personal';
      default:
        final clean = raw.replaceAll('_', ' ').trim();
        if (clean.isEmpty) return 'General';
        return '${clean[0].toUpperCase()}${clean.substring(1).toLowerCase()}';
    }
  }

  String _formatFecha(DateTime fecha) {
    final day = fecha.day.toString().padLeft(2, '0');
    final month = fecha.month.toString().padLeft(2, '0');
    return '$day/$month/${fecha.year}';
  }

  Future<void> _submitSolicitud() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<OrientacionViewModel>();
    final colors = _resolveColors(context);
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
                  child: Text(
                    'Solicitud enviada con éxito. UNAYOE responderá pronto.',
                  ),
                ),
              ],
            ),
            backgroundColor: _OrientacionTokens.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_OrientacionTokens.radiusMd),
            ),
          ),
        );
      }

      _tabController.animateTo(1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.error ?? 'Error desconocido'),
          backgroundColor: colors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_OrientacionTokens.radiusMd),
          ),
        ),
      );
    }
  }

  void _mostrarAlertaUrgencia(AlertaUrgencia alerta) {
    final colors = _resolveColors(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_OrientacionTokens.radiusLg),
        ),
        backgroundColor: colors.dangerLight,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.danger, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Soporte Inmediato Requerido',
                style: TextStyle(
                  color: colors.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detectamos una situación delicada en tu mensaje. Tu seguridad es nuestra prioridad. Recuerda que la orientación digital no reemplaza la atención de emergencia.',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Líneas comunitarias y de ayuda inmediata:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.danger,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            ...alerta.lineasAyuda.map(
              (linea) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.danger.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_in_talk_rounded,
                      size: 18,
                      color: colors.danger,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        linea,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: const Text(
              'Entendido',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text(
          'Orientación Confidencial',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _OrientacionTokens.maxContentWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: _buildTabSwitcher(colors),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildForm(colors),
                  _buildHistory(colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(_OrientacionTokens.radiusMd),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _OrientacionTokens.heroStart,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: colors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
        tabs: const [
          Tab(
            height: 42,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_note_rounded, size: 18),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Solicitar Apoyo',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Tab(
            height: 42,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_chat_read_rounded, size: 18),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Mis Solicitudes',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_OrientacionTokens.heroStart, _OrientacionTokens.heroEnd],
        ),
        borderRadius: BorderRadius.circular(_OrientacionTokens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: _OrientacionTokens.heroStart.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
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
            child: const Icon(
              Icons.lock_person_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Cómo te sientes hoy?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Espacio protegido y confidencial. El equipo orientador de UNAYOE leerá tu consulta.',
                  style: TextStyle(
                    color: Color(0xFFE0E7FF),
                    fontSize: 12.5,
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

  Widget _buildForm(AppColors colors) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _OrientacionTokens.maxContentWidth,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeBanner(),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Text(
                      'Redacta tu mensaje',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.chipBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 13,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Privado',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(
                      _OrientacionTokens.radiusMd,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _mensajeController,
                    maxLines: 6,
                    maxLength: 1500,
                    style: TextStyle(fontSize: 14, color: colors.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colors.card,
                      hintText:
                          'Cuéntanos lo que estás pasando o si necesitas apoyo académico, personal o emocional...',
                      hintStyle: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 13.5,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          _OrientacionTokens.radiusMd,
                        ),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          _OrientacionTokens.radiusMd,
                        ),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          _OrientacionTokens.radiusMd,
                        ),
                        borderSide: BorderSide(
                          color: colors.primary,
                          width: 1.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          _OrientacionTokens.radiusMd,
                        ),
                        borderSide: BorderSide(color: colors.danger),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          _OrientacionTokens.radiusMd,
                        ),
                        borderSide: BorderSide(
                          color: colors.danger,
                          width: 1.5,
                        ),
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
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(
                      _OrientacionTokens.radiusMd,
                    ),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Consumer<OrientacionViewModel>(
                    builder: (context, vm, _) {
                      final puedeCompartir = vm.puedeCompartirEvaluacion;
                      final valorActual =
                          puedeCompartir && _comparteEvaluacion;
                      return SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.analytics_outlined,
                            color: colors.primary,
                            size: 21,
                          ),
                        ),
                        title: Text(
                          'Compartir mi último test de riesgo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: colors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          puedeCompartir
                              ? 'Opcional. Permite a UNAYOE darte una respuesta más contextualizada.'
                              : 'Realiza primero una evaluación de riesgo para poder adjuntarla.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                        activeThumbColor: colors.primary,
                        value: valorActual,
                        onChanged: puedeCompartir
                            ? (val) =>
                                  setState(() => _comparteEvaluacion = val)
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: Consumer<OrientacionViewModel>(
                    builder: (context, vm, _) {
                      return ElevatedButton.icon(
                        onPressed: vm.isLoading ? null : _submitSolicitud,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _OrientacionTokens.heroStart,
                          disabledBackgroundColor: _OrientacionTokens.heroStart
                              .withValues(alpha: 0.6),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: _OrientacionTokens.heroStart.withValues(
                            alpha: 0.35,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              _OrientacionTokens.radiusPill,
                            ),
                          ),
                        ),
                        icon: vm.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 20),
                        label: Text(
                          vm.isLoading
                              ? 'Enviando...'
                              : 'Enviar Solicitud Confidencial',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
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

  Widget _buildHistory(AppColors colors) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _OrientacionTokens.maxContentWidth,
        ),
        child: Consumer<OrientacionViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading && vm.historial.isEmpty) {
              return Center(
                child: CircularProgressIndicator(color: colors.primary),
              );
            }

            if (vm.error != null && vm.historial.isEmpty) {
              return _buildErrorHistory(colors, vm);
            }

            if (vm.historial.isEmpty) {
              return _buildEmptyHistory(colors);
            }

            return RefreshIndicator(
              onRefresh: vm.cargarHistorial,
              color: colors.primary,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                itemCount: vm.historial.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildSolicitudCard(colors, vm.historial[index]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyHistory(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 44,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes solicitudes previas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Las consultas que envíes a UNAYOE aparecerán aquí registradas con su respuesta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorHistory(AppColors colors, OrientacionViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(_OrientacionTokens.radiusLg),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 36, color: colors.danger),
              const SizedBox(height: 12),
              Text(
                vm.error ?? 'No pudimos cargar tus solicitudes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: vm.cargarHistorial,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSolicitudCard(AppColors colors, SolicitudOrientacion sol) {
    final isAtendida = sol.estado.toLowerCase() == 'atendida';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final temaRaw = sol.temaConfirmado ?? sol.temaSugerido;
    final prioridadRaw =
        (sol.prioridadConfirmada ?? sol.prioridadSugerida ?? '').toLowerCase();
    final isPrioritaria =
        sol.urgenciaDetectada ||
        prioridadRaw == 'alta' ||
        prioridadRaw == 'critica';

    final statusBg = isAtendida
        ? (isDark
              ? _OrientacionTokens.success.withValues(alpha: 0.22)
              : _OrientacionTokens.successLight)
        : (isDark
              ? _OrientacionTokens.warning.withValues(alpha: 0.22)
              : _OrientacionTokens.warningLight);
    final statusFg = isAtendida
        ? (isDark ? const Color(0xFF34D399) : _OrientacionTokens.success)
        : (isDark ? const Color(0xFFFBBF24) : _OrientacionTokens.warning);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(_OrientacionTokens.radiusMd),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          iconColor: colors.primary,
          collapsedIconColor: colors.textTertiary,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAtendida
                                ? Icons.check_circle_outline_rounded
                                : Icons.access_time_rounded,
                            size: 13.5,
                            color: statusFg,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isAtendida ? 'Atendida' : 'Pendiente',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (temaRaw != null && temaRaw.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.borderLight),
                        ),
                        child: Text(
                          _formatTema(temaRaw),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    if (isPrioritaria)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Prioritaria',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: colors.danger,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (sol.fechaCreacion != null) ...[
                const SizedBox(width: 8),
                Text(
                  _formatFecha(sol.fechaCreacion!),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              sol.mensaje,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.divider)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Mensaje enviado',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (sol.comparteEvaluacionRiesgo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.chipBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                size: 12,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Test adjunto',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sol.mensaje,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (isAtendida)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.rate_review_rounded,
                                size: 16,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  sol.atendidoPor != null
                                      ? 'Respuesta de UNAYOE (Orientador #${sol.atendidoPor})'
                                      : 'Respuesta de UNAYOE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                              if (sol.fechaAtencion != null)
                                Text(
                                  _formatFecha(sol.fechaAtencion!),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (sol.respuestaEscrita ?? '').trim().isNotEmpty
                                ? sol.respuestaEscrita!
                                : 'Solicitud marcada como atendida.',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.hourglass_top_rounded,
                            size: 15,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'En espera de revisión del equipo orientador.',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
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
}
