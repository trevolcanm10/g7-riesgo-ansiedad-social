import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/entities/cita.dart';
import '../../viewmodels/agenda_unayoe_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'citas_format.dart';

/// Agenda del personal de UNAYOE: confirmar, marcar asistencia, cancelar y
/// consultar la probabilidad orientativa de inasistencia.
class AgendaUnayoeScreen extends StatefulWidget {
  const AgendaUnayoeScreen({super.key});

  @override
  State<AgendaUnayoeScreen> createState() => _AgendaUnayoeScreenState();
}

class _AgendaUnayoeScreenState extends State<AgendaUnayoeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AgendaUnayoeViewModel>().cargarAgenda();
    });
  }

  Future<void> _cambiar(Cita c, String estado, String exito) async {
    final ok = await context.read<AgendaUnayoeViewModel>().cambiarEstado(
      c.id,
      estado,
    );
    if (!mounted) return;
    _avisar(ok, exito);
  }

  Future<void> _cancelar(Cita c) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: Text(
          'Se cancelará la cita del ${fechaCorta(c.inicio)} a las ${hora(c.inicio)} y el horario quedará libre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar cita'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final ok = await context.read<AgendaUnayoeViewModel>().cancelar(c.id);
    if (!mounted) return;
    _avisar(ok, 'Cita cancelada.');
  }

  /// Pide confirmacion y solo entonces cierra la sesion (SessionGate lleva al login).
  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await context.read<AuthViewModel>().logout();
  }

  void _avisar(bool ok, String exito) {
    final vm = context.read<AgendaUnayoeViewModel>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? exito : (vm.error ?? 'No se pudo completar.'))),
    );
  }

  Future<void> _verRiesgo(Cita c) async {
    final vm = context.read<AgendaUnayoeViewModel>();
    final r = await vm.riesgo(c.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Riesgo de inasistencia'),
        content: r.riesgo == null
            ? Text(r.error ?? 'No disponible.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(r.riesgo!.probabilidad * 100).round()} %',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (r.riesgo!.factores.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final f in r.riesgo!.factores) Text('• $f'),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Estimación orientativa (${r.riesgo!.modelo}). Úsala solo para decidir un recordatorio; nunca para negar o retrasar una cita.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AgendaUnayoeViewModel>();
    final auth = context.watch<AuthViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final ahora = DateTime.now();
    final citas = [...vm.agenda]..sort((a, b) => a.inicio.compareTo(b.inicio));

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.esAdministrador ? 'Agenda (administrador)' : 'Agenda UNAYOE'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: auth.isLoading ? null : _cerrarSesion,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/publicar-horarios');
        },
        icon: const Icon(Icons.add),
        label: const Text('Publicar horarios'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final f in const [
                    (null, 'Todas'),
                    (Cita.solicitada, 'Pendientes'),
                    (Cita.confirmada, 'Confirmadas'),
                  ])
                    ChoiceChip(
                      label: Text(f.$2),
                      selected: vm.filtro == f.$1,
                      onSelected: (_) => vm.cargarAgenda(filtro: f.$1),
                    ),
                ],
              ),
            ),
            Expanded(
              child: vm.cargando && vm.agenda.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => vm.cargarAgenda(conservarFiltro: true),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
                        children: [
                          if (vm.error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                vm.error!,
                                style: TextStyle(color: scheme.error),
                              ),
                            ),
                          if (citas.isEmpty && vm.error == null && !vm.cargando)
                            Padding(
                              padding: const EdgeInsets.only(top: 48),
                              child: Center(
                                child: Text(
                                  'No hay citas para mostrar.',
                                  style: TextStyle(color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ),
                          for (final c in citas)
                            _CitaPersonalCard(
                              cita: c,
                              yaOcurrio: !c.inicio.isAfter(ahora),
                              ocupado: vm.guardando,
                              onConfirmar: () => _cambiar(
                                c,
                                Cita.confirmada,
                                'Cita confirmada.',
                              ),
                              onAtendida: () =>
                                  _cambiar(c, Cita.atendida, 'Marcada como atendida.'),
                              onNoAsistio: () => _cambiar(
                                c,
                                Cita.noAsistio,
                                'Marcada como no asistió.',
                              ),
                              onCancelar: () => _cancelar(c),
                              onRiesgo: () => _verRiesgo(c),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CitaPersonalCard extends StatelessWidget {
  final Cita cita;
  final bool yaOcurrio;
  final bool ocupado;
  final VoidCallback onConfirmar;
  final VoidCallback onAtendida;
  final VoidCallback onNoAsistio;
  final VoidCallback onCancelar;
  final VoidCallback onRiesgo;

  const _CitaPersonalCard({
    required this.cita,
    required this.yaOcurrio,
    required this.ocupado,
    required this.onConfirmar,
    required this.onAtendida,
    required this.onNoAsistio,
    required this.onCancelar,
    required this.onRiesgo,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final acciones = <Widget>[];
    if (cita.estado == Cita.solicitada) {
      acciones.add(
        FilledButton(
          onPressed: ocupado ? null : onConfirmar,
          child: const Text('Confirmar'),
        ),
      );
    }
    if (cita.estado == Cita.confirmada && yaOcurrio) {
      acciones.addAll([
        FilledButton(
          onPressed: ocupado ? null : onAtendida,
          child: const Text('Atendida'),
        ),
        OutlinedButton(
          onPressed: ocupado ? null : onNoAsistio,
          child: const Text('No asistió'),
        ),
      ]);
    }
    if (cita.activa) {
      acciones.add(
        TextButton(
          onPressed: ocupado ? null : onCancelar,
          child: const Text('Cancelar'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${fechaCorta(cita.inicio)} · ${hora(cita.inicio)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (cita.prioridad == 'ALTA')
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Prioritaria',
                      style: TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Text(
                  etiquetaEstado(cita.estado),
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Estudiante #${cita.estudianteId ?? "?"}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (cita.motivo != null && cita.motivo!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(cita.motivo!),
            ],
            if (cita.activa) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...acciones,
                  TextButton.icon(
                    onPressed: onRiesgo,
                    icon: const Icon(Icons.insights_outlined, size: 18),
                    label: const Text('Riesgo de inasistencia'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
