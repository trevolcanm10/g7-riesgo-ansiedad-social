import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/services/horarios_service.dart';
import '../../viewmodels/agenda_unayoe_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'citas_format.dart';

/// Publica una tanda de horarios de 30 min para un dia y un rango de horas.
class PublicarHorariosScreen extends StatefulWidget {
  const PublicarHorariosScreen({super.key});

  @override
  State<PublicarHorariosScreen> createState() => _PublicarHorariosScreenState();
}

class _PublicarHorariosScreenState extends State<PublicarHorariosScreen> {
  DateTime _dia = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _desde = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _hasta = const TimeOfDay(hour: 12, minute: 0);
  final _personal = TextEditingController();

  @override
  void dispose() {
    _personal.dispose();
    super.dispose();
  }

  DateTime _combinar(TimeOfDay t) =>
      DateTime(_dia.year, _dia.month, _dia.day, t.hour, t.minute);

  List<DateTime> get _inicios => generarInicios(_combinar(_desde), _combinar(_hasta));

  String _t(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _elegirDia() async {
    final hoy = DateTime.now();
    final r = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 90)),
    );
    if (r != null) setState(() => _dia = r);
  }

  Future<void> _elegirHora(bool inicio) async {
    final r = await showTimePicker(
      context: context,
      initialTime: inicio ? _desde : _hasta,
    );
    if (r != null) setState(() => inicio ? _desde = r : _hasta = r);
  }

  Future<void> _publicar(bool esAdmin) async {
    int? personalId;
    if (esAdmin) {
      personalId = int.tryParse(_personal.text.trim());
      if (personalId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indica el id del personal de UNAYOE.')),
        );
        return;
      }
    }
    final vm = context.read<AgendaUnayoeViewModel>();
    final n = await vm.publicar(_inicios, personalId: personalId);
    if (!mounted) return;
    if (n != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n horarios publicados.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AgendaUnayoeViewModel>();
    final esAdmin = context.watch<AuthViewModel>().esAdministrador;
    final scheme = Theme.of(context).colorScheme;
    final inicios = _inicios;
    final demasiados = inicios.length > maxHorariosPorPublicacion;
    final valido = inicios.isNotEmpty && !demasiados;

    return Scaffold(
      appBar: AppBar(title: const Text('Publicar horarios')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Se crean bloques de $minutosPorCita minutos dentro del rango que elijas.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text('Día: ${fechaCorta(_dia)}'),
              onTap: _elegirDia,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _elegirHora(true),
                    child: Text('Desde ${_t(_desde)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _elegirHora(false),
                    child: Text('Hasta ${_t(_hasta)}'),
                  ),
                ),
              ],
            ),
            if (esAdmin) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _personal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Id del personal de UNAYOE',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              !valido
                  ? (demasiados
                        ? 'Máximo $maxHorariosPorPublicacion horarios por publicación.'
                        : 'El rango debe permitir al menos un bloque de $minutosPorCita min.')
                  : 'Se publicarán ${inicios.length} horarios.',
              style: TextStyle(color: valido ? scheme.primary : scheme.error),
            ),
            if (vm.error != null) ...[
              const SizedBox(height: 8),
              Text(vm.error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: valido && !vm.guardando ? () => _publicar(esAdmin) : null,
                child: vm.guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Publicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
