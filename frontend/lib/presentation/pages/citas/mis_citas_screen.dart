import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/entities/cita.dart';
import '../../viewmodels/citas_viewmodel.dart';
import 'citas_format.dart';

/// Lista de citas del estudiante con acciones de cancelar y reprogramar.
class MisCitasScreen extends StatefulWidget {
  const MisCitasScreen({super.key});

  @override
  State<MisCitasScreen> createState() => _MisCitasScreenState();
}

class _MisCitasScreenState extends State<MisCitasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CitasViewModel>().cargarMisCitas();
    });
  }

  Future<void> _cancelar(Cita cita) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: Text(
          '¿Cancelar tu cita del ${fechaCorta(cita.inicio)} a las ${hora(cita.inicio)}? El horario quedará libre para otra persona.',
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
    final vm = context.read<CitasViewModel>();
    final ok = await vm.cancelar(cita.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cita cancelada.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CitasViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final ahora = DateTime.now();

    final activas = vm.citas.where((c) => c.activa).toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
    final anteriores = vm.citas.where((c) => !c.activa).toList()
      ..sort((a, b) => b.inicio.compareTo(a.inicio));

    return Scaffold(
      appBar: AppBar(title: const Text('Mis citas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/agendar-cita');
          if (mounted) context.read<CitasViewModel>().cargarMisCitas();
        },
        icon: const Icon(Icons.add),
        label: const Text('Agendar cita'),
      ),
      body: SafeArea(
        child: vm.cargando && vm.citas.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: vm.cargarMisCitas,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
                  children: [
                    if (vm.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          vm.error!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    if (vm.citas.isEmpty && vm.error == null && !vm.cargando)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              size: 56,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Aún no tienes citas.',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Puedes agendar una con UNAYOE cuando lo necesites.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    if (activas.isNotEmpty) const _Titulo('Próximas'),
                    for (final c in activas)
                      _CitaCard(
                        cita: c,
                        puedeModificar: c.puedeModificar(ahora),
                        ocupado: vm.guardando,
                        onCancelar: () => _cancelar(c),
                        onReprogramar: () async {
                          await Navigator.pushNamed(
                            context,
                            '/agendar-cita',
                            arguments: c,
                          );
                          if (mounted) {
                            context.read<CitasViewModel>().cargarMisCitas();
                          }
                        },
                      ),
                    if (anteriores.isNotEmpty) const _Titulo('Anteriores'),
                    for (final c in anteriores)
                      _CitaCard(
                        cita: c,
                        puedeModificar: false,
                        ocupado: false,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(
      texto,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  );
}

class _CitaCard extends StatelessWidget {
  final Cita cita;
  final bool puedeModificar;
  final bool ocupado;
  final VoidCallback? onCancelar;
  final VoidCallback? onReprogramar;

  const _CitaCard({
    required this.cita,
    required this.puedeModificar,
    required this.ocupado,
    this.onCancelar,
    this.onReprogramar,
  });

  Color _color(ColorScheme s) {
    switch (cita.estado) {
      case Cita.confirmada:
      case Cita.atendida:
        return const Color(0xFF059669);
      case Cita.cancelada:
      case Cita.noAsistio:
        return s.error;
      default:
        return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _color(scheme);
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    etiquetaEstado(cita.estado),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (cita.motivo != null && cita.motivo!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                cita.motivo!,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            if (cita.activa) ...[
              const SizedBox(height: 12),
              if (puedeModificar)
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: ocupado ? null : onReprogramar,
                      child: const Text('Reprogramar'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: ocupado ? null : onCancelar,
                      child: const Text('Cancelar'),
                    ),
                  ],
                )
              else
                Text(
                  'Ya no se puede cambiar desde la app (faltan menos de ${Cita.horasMinimasParaCambiar} h). Contacta a UNAYOE.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
