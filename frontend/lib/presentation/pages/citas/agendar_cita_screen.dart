import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/entities/cita.dart';
import '../../viewmodels/citas_viewmodel.dart';
import '../../viewmodels/evaluacion_viewmodel.dart';
import 'citas_format.dart';

/// Elegir un horario libre para solicitar una cita o reprogramar una existente.
///
/// Si recibe un [Cita] como argumento de ruta, funciona en modo reprogramar.
class AgendarCitaScreen extends StatefulWidget {
  const AgendarCitaScreen({super.key});

  @override
  State<AgendarCitaScreen> createState() => _AgendarCitaScreenState();
}

class _AgendarCitaScreenState extends State<AgendarCitaScreen> {
  final _motivo = TextEditingController();
  Horario? _seleccion;
  Cita? _reprogramar;
  bool _argumentoLeido = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CitasViewModel>().cargarHorarios();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentoLeido) return;
    _argumentoLeido = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Cita) _reprogramar = arg;
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  /// ALTA solo si el ultimo resultado fue de riesgo alto. Es informativa.
  String _prioridad() {
    final historial = context.read<EvaluacionViewModel>().historial;
    final nivel = historial.isEmpty
        ? null
        : historial.first.resultado?.nivelRiesgo;
    return nivel?.toUpperCase() == 'ALTO' ? 'ALTA' : 'NORMAL';
  }

  Future<void> _confirmar() async {
    final horario = _seleccion;
    if (horario == null) return;
    final vm = context.read<CitasViewModel>();
    final destino = _reprogramar;
    final ok = destino == null
        ? await vm.solicitar(
            slotId: horario.id,
            prioridad: _prioridad(),
            motivo: _motivo.text,
          )
        : await vm.reprogramar(destino.id, horario.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            destino == null
                ? 'Cita solicitada. UNAYOE la confirmará pronto.'
                : 'Cita reprogramada. Queda pendiente de confirmación.',
          ),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CitasViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final reprogramando = _reprogramar != null;

    // Agrupa por dia local.
    final porDia = <DateTime, List<Horario>>{};
    for (final h in vm.horarios) {
      porDia.putIfAbsent(soloDia(h.inicio), () => []).add(h);
    }
    final dias = porDia.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(reprogramando ? 'Reprogramar cita' : 'Agendar cita'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: vm.cargando && vm.horarios.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: vm.cargarHorarios,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        children: [
                          Text(
                            reprogramando
                                ? 'Elige un nuevo horario. Tu cita volverá a quedar pendiente de confirmación.'
                                : 'Elige un horario libre de 30 minutos con UNAYOE.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          if (vm.error != null) _Aviso(texto: vm.error!),
                          if (dias.isEmpty && vm.error == null && !vm.cargando)
                            const _Aviso(
                              texto:
                                  'No hay horarios libres por ahora. Vuelve a intentarlo más tarde.',
                              informativo: true,
                            ),
                          for (final dia in dias) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: Text(
                                fechaCorta(dia),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final h in porDia[dia]!)
                                  ChoiceChip(
                                    label: Text(hora(h.inicio)),
                                    selected: _seleccion?.id == h.id,
                                    onSelected: (_) =>
                                        setState(() => _seleccion = h),
                                  ),
                              ],
                            ),
                          ],
                          if (!reprogramando && _seleccion != null) ...[
                            const SizedBox(height: 20),
                            TextField(
                              controller: _motivo,
                              maxLength: 200,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Motivo (opcional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            Text(
                              'Si tu último resultado indicó riesgo alto, tu solicitud se marcará como prioritaria para que UNAYOE la vea primero. No cambia tus derechos ni se comparte tu cuestionario.',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _seleccion == null || vm.guardando
                      ? null
                      : _confirmar,
                  child: vm.guardando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _seleccion == null
                              ? 'Elige un horario'
                              : '${reprogramando ? "Reprogramar" : "Solicitar"} ${fechaCorta(_seleccion!.inicio)} · ${hora(_seleccion!.inicio)}',
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;
  final bool informativo;
  const _Aviso({required this.texto, this.informativo = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = informativo ? scheme.primary : scheme.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(texto, style: TextStyle(color: color)),
    );
  }
}
