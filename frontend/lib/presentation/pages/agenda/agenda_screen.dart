import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../core/constants.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../data/repositories/agenda_local_repository.dart';
import '../../../data/repositories/agenda_remote_repository.dart';
import '../../../domain/entities/actividad_academica.dart';
import '../../../domain/repositories/agenda_repository.dart';
import '../../../domain/services/calcular_carga_semanal.dart';
import '../../viewmodels/auth_viewmodel.dart';

class AgendaScreen extends StatefulWidget {
  final AgendaRepository? repository;
  const AgendaScreen({super.key, this.repository});
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late final AgendaRepository _repo;
  List<ActividadAcademica> _items = [];
  DateTime _selected = DateTime.now();
  bool _loading = true;
  bool _listView = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ??
        (AppConstants.gateway.enabled
            ? AgendaRemoteRepository(
                context.read<ApiService>(),
                '${AppConstants.gateway.academicAgendaOrigin}/actividades',
              )
            : AgendaLocalRepository(context.read<AuthViewModel>().idUsuario!));
    _load();
  }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _repo.obtener();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar la agenda.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _save(List<ActividadAcademica> next) async {
    try {
      await _repo.guardar(next);
      final saved = _repo is AgendaRemoteRepository ? await _repo.obtener() : next;
      if (mounted) setState(() { _items = saved; _error = null; });
      return true;
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron guardar los cambios.');
      return false;
    }
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _form([ActividadAcademica? item]) async {
    final result = await showDialog<ActividadAcademica>(
      context: context,
      builder: (_) => _ActivityForm(initial: item, selected: _selected),
    );
    if (result == null) return;
    final next = [..._items.where((a) => a.id != result.id), result];
    if (await _save(next) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(item == null ? 'Actividad creada' : 'Actividad actualizada')));
    }
  }

  Future<void> _detail(ActividadAcademica item) async {
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(item.titulo),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Curso: ${item.curso}'), Text('Tipo: ${item.tipo}'),
        Text('Fecha: ${_date(item.fecha)}${item.hora == null ? '' : ' · ${item.hora}'}'),
        if (item.duracionEstimadaHoras != null) Text('Duración estimada: ${item.duracionEstimadaHoras} h'),
        Text('Prioridad: ${item.prioridad}'), Text('Estado: ${item.completada ? 'Completada' : 'Pendiente'}'),
        if (item.descripcion.isNotEmpty) Text(item.descripcion),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar')),
        TextButton(onPressed: () async {
          final next = _items.map((a) => a.id == item.id ? a.copyWith(completada: !a.completada) : a).toList();
          if (await _save(next) && dialogContext.mounted) Navigator.pop(dialogContext);
        }, child: Text(item.completada ? 'Reactivar' : 'Completar')),
        TextButton(onPressed: () { Navigator.pop(dialogContext); _form(item); }, child: const Text('Editar')),
        TextButton(onPressed: () async {
          final confirmed = await showDialog<bool>(context: dialogContext, builder: (c) => AlertDialog(
            title: const Text('Eliminar actividad'), content: const Text('¿Eliminar esta actividad?'),
            actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar'))],
          ));
          if (confirmed == true) {
            final next = _items.where((a) => a.id != item.id).toList();
            if (await _save(next) && dialogContext.mounted) Navigator.pop(dialogContext);
          }
        }, child: Text('Eliminar', style: TextStyle(color: AppColors.of(context).danger))),
      ],
    ));
  }

  Widget _calendar(AppColors colors) {
    final first = DateTime(_selected.year, _selected.month, 1);
    final days = DateTime(_selected.year, _selected.month + 1, 0).day;
    final offset = first.weekday - 1;
    final today = DateTime.now();
    return Card(color: colors.card, child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(onPressed: () => setState(() => _selected = DateTime(_selected.year, _selected.month - 1, 1)), icon: const Icon(Icons.chevron_left)),
        Text('${_month(_selected.month)} ${_selected.year}', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
        IconButton(onPressed: () => setState(() => _selected = DateTime(_selected.year, _selected.month + 1, 1)), icon: const Icon(Icons.chevron_right)),
      ]),
      Row(children: ['L', 'M', 'M', 'J', 'V', 'S', 'D'].map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(color: colors.textSecondary))))).toList()),
      const SizedBox(height: 6),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.15),
        itemCount: offset + days, itemBuilder: (context, index) {
          if (index < offset) return const SizedBox.shrink();
          final day = DateTime(_selected.year, _selected.month, index - offset + 1);
          final selected = _sameDay(day, _selected);
          final hasItems = _items.any((a) => _sameDay(a.fecha, day));
          return InkWell(onTap: () => setState(() => _selected = day), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircleAvatar(radius: 15, backgroundColor: selected ? colors.primary : Colors.transparent,
              child: Text('${day.day}', style: TextStyle(color: selected ? Colors.white : colors.textPrimary,
                fontWeight: _sameDay(day, today) ? FontWeight.bold : FontWeight.normal))),
            if (hasItems) Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: colors.primary)),
          ]));
        }),
    ])));
  }

  String _month(int month) => const ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'][month - 1];

  Widget _weeklyLoad(AppColors colors) {
    final carga = calcularCargaSemanal(_items, _selected);
    final label = switch (carga.nivel) {
      NivelCargaAcademica.baja => 'BAJA',
      NivelCargaAcademica.moderada => 'MODERADA',
      NivelCargaAcademica.alta => 'ALTA',
    };
    final color = switch (carga.nivel) {
      NivelCargaAcademica.baja => const Color(0xFF059669),
      NivelCargaAcademica.moderada => const Color(0xFFD97706),
      NivelCargaAcademica.alta => colors.danger,
    };
    return Card(
      color: colors.card,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.event_available_outlined, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text('Carga semanal · ${_date(carga.lunes)}–${_date(carga.domingo)}',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600))),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text('${carga.horasConocidas.toStringAsFixed(1)} h conocidas · ${carga.pendientes} pendientes · ${carga.completadas} completadas',
            style: TextStyle(color: colors.textTertiary)),
          if (carga.estimacionParcial)
            Text('Estimación parcial: faltan duraciones', style: TextStyle(color: colors.textTertiary)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final shown = _items.where((a) => _listView ? !a.fecha.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) : _sameDay(a.fecha, _selected)).toList()
      ..sort((a, b) { final d = a.fecha.compareTo(b.fecha); return d != 0 ? d : (a.hora ?? '').compareTo(b.hora ?? ''); });
    return Scaffold(backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Mi agenda académica')),
      body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Organiza tus actividades académicas', style: TextStyle(color: colors.textSecondary)),
        const SizedBox(height: 16), _calendar(colors),
        if (!_loading && _error == null) ...[
          const SizedBox(height: 8),
          _weeklyLoad(colors),
        ],
        SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('Calendario')), ButtonSegment(value: true, label: Text('Próximas actividades'))],
          selected: {_listView}, onSelectionChanged: (v) => setState(() => _listView = v.first)),
        const SizedBox(height: 12),
        if (_loading) const Center(child: CircularProgressIndicator())
        else if (_error != null) Column(children: [Text(_error!, style: TextStyle(color: colors.danger)), TextButton(onPressed: _load, child: const Text('Reintentar'))])
        else if (shown.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(_items.isEmpty ? 'Aún no tienes actividades.' : _listView ? 'No hay próximas actividades.' : 'No hay actividades este día.', style: TextStyle(color: colors.textSecondary))))
        else ...shown.map((item) => Card(color: colors.card, child: ListTile(onTap: () => _detail(item),
          leading: Icon(item.completada ? Icons.check_circle : Icons.event_note, color: colors.primary),
          title: Text(item.titulo, style: TextStyle(color: colors.textPrimary, decoration: item.completada ? TextDecoration.lineThrough : null)),
          subtitle: Text('${item.curso} · ${item.tipo} · ${_date(item.fecha)}${item.hora == null ? '' : ' ${item.hora}'}\n${item.prioridad} · ${item.completada ? 'Completada' : 'Pendiente'}'),
          isThreeLine: true, trailing: const Icon(Icons.chevron_right)))),
      ])),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _form(), icon: const Icon(Icons.add), label: const Text('Nueva actividad')),
    );
  }
}

class _ActivityForm extends StatefulWidget {
  final ActividadAcademica? initial;
  final DateTime selected;
  const _ActivityForm({required this.initial, required this.selected});
  @override
  State<_ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends State<_ActivityForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(text: widget.initial?.titulo);
  late final TextEditingController _course = TextEditingController(text: widget.initial?.curso);
  late final TextEditingController _duration = TextEditingController(text: widget.initial?.duracionEstimadaHoras?.toString());
  late final TextEditingController _description = TextEditingController(text: widget.initial?.descripcion);
  late DateTime _date = widget.initial?.fecha ?? widget.selected;
  late TimeOfDay? _time = widget.initial?.hora == null ? null : TimeOfDay(hour: int.parse(widget.initial!.hora!.split(':')[0]), minute: int.parse(widget.initial!.hora!.split(':')[1]));
  late String _type = widget.initial?.tipo ?? 'tarea';
  late String _priority = widget.initial?.prioridad ?? 'media';

  @override
  void dispose() { _title.dispose(); _course.dispose(); _duration.dispose(); _description.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Nueva actividad' : 'Editar actividad'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(key: _key, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Título *'), validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa un título' : null),
      TextFormField(controller: _course, decoration: const InputDecoration(labelText: 'Curso/asignatura *'), validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa un curso' : null),
      DropdownButtonFormField<String>(initialValue: _type, decoration: const InputDecoration(labelText: 'Tipo'), items: const ['examen', 'tarea', 'exposicion', 'proyecto', 'otro'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _type = v!)),
      ListTile(title: Text('Fecha: ${_date.day}/${_date.month}/${_date.year}'), trailing: const Icon(Icons.calendar_today), onTap: () async {
        final date = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (date != null) setState(() => _date = date);
      }),
      ListTile(title: Text(_time == null ? 'Hora (opcional)' : 'Hora: ${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'),
        trailing: _time == null ? const Icon(Icons.access_time) : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _time = null)),
        onTap: () async { final time = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now()); if (time != null) setState(() => _time = time); }),
      TextFormField(controller: _duration, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Duración estimada (horas)'),
        validator: (v) { if (v == null || v.trim().isEmpty) return null; final n = double.tryParse(v.trim().replaceAll(',', '.')); return n == null || !n.isFinite || n < 0 ? 'Ingresa un número no negativo' : null; }),
      DropdownButtonFormField<String>(initialValue: _priority, decoration: const InputDecoration(labelText: 'Prioridad'), items: const ['baja', 'media', 'alta'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _priority = v!)),
      TextFormField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Descripción (opcional)')),
    ])))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: () {
        if (!_key.currentState!.validate()) return;
        final raw = _duration.text.trim();
        Navigator.pop(context, ActividadAcademica(
          id: widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          titulo: _title.text.trim(), curso: _course.text.trim(), tipo: _type, fecha: _date,
          hora: _time == null ? null : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
          duracionEstimadaHoras: raw.isEmpty ? null : double.parse(raw.replaceAll(',', '.')),
          prioridad: _priority, descripcion: _description.text.trim(), completada: widget.initial?.completada ?? false,
        ));
      }, child: const Text('Guardar'))],
  );
}
