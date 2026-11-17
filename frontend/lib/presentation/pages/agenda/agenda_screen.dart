import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../data/repositories/agenda_remote_repository.dart';
import '../../../domain/entities/actividad_academica.dart';
import '../../../domain/repositories/agenda_repository.dart';
import '../../../domain/services/calcular_carga_semanal.dart';
import '../../../presentation/viewmodels/auth_viewmodel.dart';

class AgendaScreen extends StatefulWidget {
  final AgendaRepository repository;
  const AgendaScreen({super.key, required this.repository});
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
  AgendaWeeklyClassification? _classification;
  AgendaPreventiveAlerts? _alerts;
  DateTime? _insightWeek;
  int _insightRequest = 0;
  late final AuthViewModel _auth;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository;
    _auth = context.read<AuthViewModel>();
    _loadAfterAuth();
  }

  Future<void> _loadAfterAuth() async {
    final startTime = DateTime.now();
    while (_auth.token == null && !_auth.isLoading) {
      if (DateTime.now().difference(startTime).inSeconds > 2) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.obtener();
      if (mounted) {
        setState(() => _items = items);
        _refreshInsights();
      }
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('ERROR loading agenda: $e\n$stackTrace');
      if (mounted) setState(() => _error = 'No se pudo cargar la agenda.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _save(List<ActividadAcademica> next) async {
    try {
      await _repo.guardar(next);
      final saved = _repo is AgendaRemoteRepository
          ? await _repo.obtener()
          : next;
      if (mounted) {
        setState(() {
          _items = saved;
          _error = null;
        });
        _refreshInsights();
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron guardar los cambios.');
      }
      return false;
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  DateTime get _weekDate => _listView ? DateTime.now() : _selected;

  Future<void> _refreshInsights() async {
    final request = ++_insightRequest;
    final weekDate = _weekDate;
    final week = calcularCargaSemanal(_items, weekDate).lunes;
    setState(() {
      _insightWeek = week;
      _classification = null;
      _alerts = null;
    });
    if (_repo is! AgendaRemoteRepository) return;
    final remote = _repo;
    final indicators = indicadoresCargaSemanal(_items, weekDate);
    try {
      final classification = await remote.clasificarSemana(indicators);
      if (!mounted || request != _insightRequest) return;
      setState(() => _classification = classification);
    } catch (error) {
      if (kDebugMode) debugPrint('Clasificación semanal no disponible: $error');
    }
    try {
      final alerts = await remote.obtenerAlertas(indicators);
      if (!mounted || request != _insightRequest) return;
      setState(() => _alerts = alerts);
    } catch (error) {
      if (kDebugMode) debugPrint('Avisos preventivos no disponibles: $error');
    }
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _form([ActividadAcademica? item]) async {
    final result = await showDialog<ActividadAcademica>(
      context: context,
      builder: (_) => _ActivityForm(initial: item, selected: _selected),
    );
    if (result == null) return;
    final next = [..._items.where((a) => a.id != result.id), result];
    if (await _save(next) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item == null ? 'Actividad creada' : 'Actividad actualizada',
          ),
        ),
      );
    }
  }

  Future<void> _detail(ActividadAcademica item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.titulo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Curso: ${item.curso}'),
              Text('Tipo: ${item.tipo}'),
              Text(
                'Fecha: ${_date(item.fecha)}${item.hora == null ? '' : ' · ${item.hora}'}',
              ),
              if (item.duracionEstimadaHoras != null)
                Text('Duración estimada: ${item.duracionEstimadaHoras} h'),
              Text('Prioridad: ${item.prioridad}'),
              Text('Estado: ${item.completada ? 'Completada' : 'Pendiente'}'),
              if (item.descripcion.isNotEmpty) Text(item.descripcion),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              final next = _items
                  .map(
                    (a) => a.id == item.id
                        ? a.copyWith(completada: !a.completada)
                        : a,
                  )
                  .toList();
              if (await _save(next) && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: Text(item.completada ? 'Reactivar' : 'Completar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _form(item);
            },
            child: const Text('Editar'),
          ),
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: dialogContext,
                builder: (c) => AlertDialog(
                  title: const Text('Eliminar actividad'),
                  content: const Text('¿Eliminar esta actividad?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                final next = _items.where((a) => a.id != item.id).toList();
                if (await _save(next) && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              }
            },
            child: Text(
              'Eliminar',
              style: TextStyle(color: AppColors.of(context).danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendar(AppColors colors) {
    final first = DateTime(_selected.year, _selected.month, 1);
    final days = DateTime(_selected.year, _selected.month + 1, 0).day;
    final offset = first.weekday - 1;
    final today = DateTime.now();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                tooltip: 'Mes anterior',
                onPressed: () {
                  setState(
                    () => _selected = DateTime(
                      _selected.year,
                      _selected.month - 1,
                      1,
                    ),
                  );
                  _refreshInsights();
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'VISTA MENSUAL',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_month(_selected.month)} ${_selected.year}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Mes siguiente',
                onPressed: () {
                  setState(
                    () => _selected = DateTime(
                      _selected.year,
                      _selected.month + 1,
                      1,
                    ),
                  );
                  _refreshInsights();
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellHeight = (constraints.maxWidth / 7).clamp(36.0, 64.0);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: cellHeight,
                ),
                itemCount: offset + days,
                itemBuilder: (context, index) {
                  if (index < offset) return const SizedBox.shrink();
                  final day = DateTime(
                    _selected.year,
                    _selected.month,
                    index - offset + 1,
                  );
                  final selected = _sameDay(day, _selected);
                  final hasItems = _items.any((a) => _sameDay(a.fecha, day));
                  return InkWell(
                    key: ValueKey(
                      'agenda-day-${day.year}-${day.month}-${day.day}',
                    ),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() => _selected = day);
                      if (!_sameDay(
                        calcularCargaSemanal(_items, day).lunes,
                        _insightWeek ?? DateTime(1900),
                      )) {
                        _refreshInsights();
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: selected ? colors.primary : null,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : colors.textPrimary,
                              fontWeight: _sameDay(day, today)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          if (hasItems)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected ? Colors.white : colors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: 9, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'Actividad',
                style: TextStyle(fontSize: 12, color: colors.textTertiary),
              ),
              const SizedBox(width: 18),
              Icon(Icons.circle_outlined, size: 11, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'Hoy',
                style: TextStyle(fontSize: 12, color: colors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _month(int month) => const [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ][month - 1];

  Widget _weeklyLoad(AppColors colors, DateTime weekDate) {
    final carga = calcularCargaSemanal(_items, weekDate);
    final current =
        _insightWeek != null && _sameDay(_insightWeek!, carga.lunes);
    final remoteLevel = current ? _classification?.nivel : null;
    final alerts = current ? _alerts : null;
    final label =
        remoteLevel ??
        switch (carga.nivel) {
          NivelCargaAcademica.baja => 'BAJA',
          NivelCargaAcademica.moderada => 'MODERADA',
          NivelCargaAcademica.alta => 'ALTA',
        };
    final color = switch (label) {
      'BAJA' => const Color(0xFF059669),
      'MODERADA' => const Color(0xFFD97706),
      _ => colors.danger,
    };
    return Card(
      color: colors.card,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_available_outlined, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Carga semanal · ${_date(carga.lunes)}–${_date(carga.domingo)}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${carga.horasConocidas.toStringAsFixed(1)} h conocidas · ${carga.pendientes} pendientes · ${carga.completadas} completadas',
              style: TextStyle(color: colors.textTertiary),
            ),
            if (carga.estimacionParcial)
              Text(
                'Estimación parcial: faltan duraciones',
                style: TextStyle(color: colors.textTertiary),
              ),
            if (remoteLevel == null)
              Text(
                'Estimación local de respaldo (10/20 h)',
                style: TextStyle(color: colors.textTertiary),
              ),
            if (alerts != null) ...[
              const SizedBox(height: 8),
              ...alerts.alertas.map(
                (alert) => Text(
                  '• ${alert['mensaje'] ?? ''}',
                  style: TextStyle(color: colors.textPrimary),
                ),
              ),
              if (alerts.recomendacion.isNotEmpty)
                Text(
                  alerts.recomendacion,
                  style: TextStyle(color: colors.textTertiary),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _longDate(DateTime day) {
    const weekdays = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    return '${weekdays[day.weekday - 1]}, ${day.day} de ${_month(day.month)} de ${day.year}';
  }

  Widget _activityCard(ActividadAcademica item, AppColors colors) {
    final icon = switch (item.tipo.toLowerCase()) {
      'examen' => Icons.psychology_outlined,
      'exposicion' => Icons.person_outline,
      'tarea' => Icons.check_rounded,
      _ => Icons.book_outlined,
    };
    final priorityColor = switch (item.prioridad.toLowerCase()) {
      'alta' => const Color(0xFFBE3B4B),
      'baja' => const Color(0xFF287F97),
      _ => const Color(0xFFA66B13),
    };
    final priorityBg = switch (item.prioridad.toLowerCase()) {
      'alta' => const Color(0xFFFFEFF1),
      'baja' => const Color(0xFFE8F6F9),
      _ => const Color(0xFFFFF4DD),
    };
    final time = item.hora == null ? '' : ' · ${item.hora}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: colors.border),
      ),
      child: InkWell(
        onTap: () => _detail(item),
        borderRadius: BorderRadius.circular(23),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: colors.primaryLight,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: colors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.curso,
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.titulo,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: item.completada
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.completada)
                    const Icon(Icons.check_circle, color: Color(0xFF62B9A6)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_longDate(item.fecha)}$time',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _chip(item.tipo, colors.primaryLight, colors.primary),
                  _chip(
                    'Prioridad ${item.prioridad}',
                    priorityBg,
                    priorityColor,
                  ),
                  _chip(
                    item.completada ? 'Completada' : 'Pendiente',
                    item.completada
                        ? const Color(0xFFE7F7F2)
                        : const Color(0xFFFFF4DD),
                    item.completada
                        ? const Color(0xFF25806C)
                        : const Color(0xFF986411),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color background, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: foreground,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final shown =
        _items
            .where(
              (a) => _listView
                  ? !a.fecha.isBefore(today)
                  : _sameDay(a.fecha, _selected),
            )
            .toList()
          ..sort((a, b) {
            final d = a.fecha.compareTo(b.fecha);
            return d != 0 ? d : (a.hora ?? '').compareTo(b.hora ?? '');
          });
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        centerTitle: true,
        title: Text(
          'Agenda Académica',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TU CICLO, EN ORDEN',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mi agenda académica',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Organiza tus actividades y mantente al día.',
                      style: TextStyle(color: colors.textTertiary),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: colors.primaryLight,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          _tab(
                            false,
                            'Calendario',
                            Icons.event_available_outlined,
                            colors,
                          ),
                          _tab(true, 'Próximas', Icons.history_rounded, colors),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!_loading && _error == null) ...[
                      _weeklyLoad(
                        colors,
                        _listView ? DateTime.now() : _selected,
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (!_listView) ...[
                      _calendar(colors),
                      const SizedBox(height: 24),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _listView
                                    ? 'LO QUE VIENE'
                                    : 'ACTIVIDADES DEL DÍA',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                _listView
                                    ? 'Próximas Actividades'
                                    : _longDate(_selected),
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_loading && _error == null)
                          _chip(
                            '${shown.length}',
                            colors.primaryLight,
                            colors.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_error != null)
                      Center(
                        child: Column(
                          children: [
                            Text(
                              _error!,
                              style: TextStyle(color: colors.danger),
                            ),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    else if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            _items.isEmpty
                                ? 'Aún no tienes actividades.'
                                : _listView
                                ? 'No hay próximas actividades.'
                                : 'No hay actividades este día.',
                            style: TextStyle(color: colors.textTertiary),
                          ),
                        ),
                      )
                    else
                      ...shown.map((item) => _activityCard(item, colors)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () => _form(),
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva actividad'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
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

  Widget _tab(bool listView, String label, IconData icon, AppColors colors) =>
      Expanded(
        child: InkWell(
          onTap: () {
            if (_listView == listView) return;
            setState(() => _listView = listView);
            _load();
          },
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
            decoration: BoxDecoration(
              color: _listView == listView
                  ? colors.surface
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: _listView == listView
                      ? colors.primary
                      : colors.textTertiary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _listView == listView
                          ? colors.primary
                          : colors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
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
  late final TextEditingController _title = TextEditingController(
    text: widget.initial?.titulo,
  );
  late final TextEditingController _course = TextEditingController(
    text: widget.initial?.curso,
  );
  late final TextEditingController _duration = TextEditingController(
    text: widget.initial?.duracionEstimadaHoras?.toString(),
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.initial?.descripcion,
  );
  late DateTime _date = widget.initial?.fecha ?? widget.selected;
  late TimeOfDay? _time = widget.initial?.hora == null
      ? null
      : TimeOfDay(
          hour: int.parse(widget.initial!.hora!.split(':')[0]),
          minute: int.parse(widget.initial!.hora!.split(':')[1]),
        );
  late String _type = widget.initial?.tipo ?? 'tarea';
  late String _priority = widget.initial?.prioridad ?? 'media';

  @override
  void dispose() {
    _title.dispose();
    _course.dispose();
    _duration.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null ? 'Nueva actividad' : 'Editar actividad',
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Título *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresa un título' : null,
              ),
              TextFormField(
                controller: _course,
                decoration: const InputDecoration(
                  labelText: 'Curso/asignatura *',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresa un curso' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items:
                    const ['examen', 'tarea', 'exposicion', 'proyecto', 'otro']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              ListTile(
                title: Text('Fecha: ${_date.day}/${_date.month}/${_date.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _date = date);
                },
              ),
              ListTile(
                title: Text(
                  _time == null
                      ? 'Hora (opcional)'
                      : 'Hora: ${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
                ),
                trailing: _time == null
                    ? const Icon(Icons.access_time)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _time = null),
                      ),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _time ?? TimeOfDay.now(),
                  );
                  if (time != null) setState(() => _time = time);
                },
              ),
              TextFormField(
                controller: _duration,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Duración estimada (horas)',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = double.tryParse(v.trim().replaceAll(',', '.'));
                  return n == null || !n.isFinite || n < 0
                      ? 'Ingresa un número no negativo'
                      : null;
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Prioridad'),
                items: const ['baja', 'media', 'alta']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _priority = v!),
              ),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_key.currentState!.validate()) return;
          final raw = _duration.text.trim();
          Navigator.pop(
            context,
            ActividadAcademica(
              id:
                  widget.initial?.id ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              titulo: _title.text.trim(),
              curso: _course.text.trim(),
              tipo: _type,
              fecha: _date,
              hora: _time == null
                  ? null
                  : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
              duracionEstimadaHoras: raw.isEmpty
                  ? null
                  : double.parse(raw.replaceAll(',', '.')),
              prioridad: _priority,
              descripcion: _description.text.trim(),
              completada: widget.initial?.completada ?? false,
            ),
          );
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
