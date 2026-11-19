import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_colors.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../data/repositories/academic_support_repository.dart';

class AcademicSupportScreen extends StatelessWidget {
  const AcademicSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Apoyo universitario')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7478F6), Color(0xFF5555DE)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 40),
                SizedBox(height: 48),
                Text(
                  'TU COMUNIDAD TE ACOMPAÑA',
                  style: TextStyle(color: Colors.white, letterSpacing: 2),
                ),
                SizedBox(height: 12),
                Text(
                  'Herramientas para crecer y sentirte bien',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 31,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Encuentra recursos preventivos, espacios entre estudiantes y actividades creadas para tu bienestar universitario.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _entry(
            context,
            colors,
            Icons.psychology_outlined,
            'Recursos de bienestar',
            'Guías breves y prácticas para tu día a día.',
            0,
          ),
          _entry(
            context,
            colors,
            Icons.person_outline,
            'Tutorías entre pares',
            'Conecta con estudiantes mentores.',
            1,
          ),
          _entry(
            context,
            colors,
            Icons.event_available_outlined,
            'Talleres universitarios',
            'Actividades organizadas para la comunidad.',
            2,
          ),
          Card(
            color: colors.primaryLight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Estos espacios son preventivos y complementan la atención de un profesional.',
                style: TextStyle(color: colors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/orientacion'),
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Orientación UNAYOE'),
          ),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context,
    AppColors colors,
    IconData icon,
    String title,
    String subtitle,
    int tab,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: colors.border),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(
        backgroundColor: colors.primaryLight,
        child: Icon(icon, color: colors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AcademicSupportCatalogScreen(
            initialTab: tab,
            repository: context.read<AcademicSupportRepository>(),
          ),
        ),
      ),
    ),
  );
}

class AcademicSupportCatalogScreen extends StatefulWidget {
  final int initialTab;
  final AcademicSupportRepository repository;
  const AcademicSupportCatalogScreen({
    super.key,
    required this.repository,
    this.initialTab = 0,
  });

  @override
  State<AcademicSupportCatalogScreen> createState() =>
      _AcademicSupportCatalogScreenState();
}

class _AcademicSupportCatalogScreenState
    extends State<AcademicSupportCatalogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<SupportResource> _items = const [];
  List<SupportResource> _recommended = const [];
  Set<int> _enrolled = const {};
  bool _loading = true;
  String? _error;
  int? _busyId;
  int _generation = 0;
  static const _types = ['MATERIAL', 'TUTORING', 'WORKSHOP'];
  static const _titles = [
    'Recursos de bienestar',
    'Tutorías entre pares',
    'Talleres universitarios',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _load();
      setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final type = _types[_tabs.index];
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.repository.resources(type);
      final recommendations = await widget.repository.recommendations();
      final enrolled = type == 'WORKSHOP'
          ? await widget.repository.enrollments()
          : <int>{};
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = items;
        _recommended = recommendations;
        _enrolled = enrolled;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  String _message(Object error) => error is ApiException
      ? error.mensaje
      : 'No se pudo conectar con Apoyo Universitario. Reintenta más tarde.';

  Future<void> _action(SupportResource item) async {
    if (_busyId != null) return;
    setState(() => _busyId = item.id);
    try {
      if (item.type == 'WORKSHOP') {
        if (_enrolled.contains(item.id)) {
          await widget.repository.cancelEnrollment(item.id);
          _enrolled = {..._enrolled}..remove(item.id);
        } else {
          await widget.repository.enroll(item.id);
          _enrolled = {..._enrolled, item.id};
        }
      } else {
        await widget.repository.interact(item.id, 'CLICK');
        if (item.type == 'MATERIAL' && item.url != null) {
          final uri = Uri.tryParse(item.url!);
          if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              throw StateError('No se pudo abrir el recurso.');
            }
          }
        } else if (item.type == 'TUTORING') {
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(item.title),
              content: Text(
                '${item.description}\n\n${item.location ?? 'Consulta la disponibilidad con el mentor.'}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        }
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item.type == 'WORKSHOP'
                  ? (_enrolled.contains(item.id)
                        ? 'Inscripción confirmada'
                        : 'Inscripción cancelada')
                  : item.type == 'MATERIAL'
                  ? 'Recurso abierto'
                  : 'Detalles de tutoría',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _editPreferences() async {
    try {
      final current = await widget.repository.preferences();
      if (!mounted) return;
      final controller = TextEditingController(
        text: (current['interests'] as List<dynamic>? ?? const []).join(', '),
      );
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tus intereses'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Temas separados por comas',
              hintText: 'bienestar, estudio',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (save == true) {
        final interests = controller.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .take(30)
            .toList();
        await widget.repository.savePreferences({
          'interests': interests,
          'courseCodes': current['courseCodes'] ?? <String>[],
          'availableSlots': current['availableSlots'] ?? <dynamic>[],
          'preferredModalities': current['preferredModalities'] ?? <String>[],
          'timeZone': current['timeZone'] ?? 'America/Lima',
        });
        await _load();
      }
      controller.dispose();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tab = _tabs.index;
    return Scaffold(
      appBar: AppBar(title: Text(_titles[tab])),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Container(
              decoration: BoxDecoration(
                color: colors.primaryLight,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                controller: _tabs,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(30),
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Recursos'),
                  Tab(text: 'Tutorías'),
                  Tab(text: 'Talleres'),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Center(
                    child: Text(
                      [
                        'BIBLIOTECA DE BIENESTAR',
                        'ESTUDIANTES QUE ACOMPAÑAN',
                        'AGENDA PREVENTIVA UNAYOE',
                      ][tab],
                      style: TextStyle(
                        color: colors.primary,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    [
                      'Recursos para tu día a día',
                      'Aprendemos mejor juntos',
                      'Espacios para conectar y aprender',
                    ][tab],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      'Explora herramientas sencillas a tu propio ritmo.',
                      'Conoce espacios con estudiantes mentores.',
                      'Participa en experiencias para fortalecer el bienestar.',
                    ][tab],
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _editPreferences,
                    icon: const Icon(Icons.tune),
                    label: const Text('Personalizar recomendaciones'),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Center(
                      child: Column(
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  else if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('Aún no hay contenidos disponibles.'),
                      ),
                    )
                  else
                    ..._items.map((item) => _resourceCard(item, colors)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resourceCard(SupportResource item, AppColors colors) {
    final recommended = _recommended.any((r) => r.id == item.id);
    final enrolled = _enrolled.contains(item.id);
    final seats = item.availableSeats;
    return Card(
      margin: const EdgeInsets.only(top: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryLight,
                  child: Icon(
                    item.type == 'MATERIAL'
                        ? Icons.psychology_outlined
                        : item.type == 'TUTORING'
                        ? Icons.person_outline
                        : Icons.event_available_outlined,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recommended
                            ? 'RECOMENDADO PARA TI'
                            : item.type == 'MATERIAL'
                            ? 'RECURSO DE BIENESTAR'
                            : item.type == 'TUTORING'
                            ? 'TUTORÍA ENTRE PARES'
                            : 'TALLER PREVENTIVO',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        item.title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.description,
              style: TextStyle(color: colors.textSecondary),
            ),
            if (item.startAt != null) ...[
              const SizedBox(height: 12),
              Text(
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(item.startAt!.toLocal()),
                style: TextStyle(color: colors.textSecondary),
              ),
            ],
            if (item.modality != null || seats != null) ...[
              const SizedBox(height: 8),
              Text(
                '${item.modality ?? ''}${seats != null ? ' · $seats cupos disponibles' : ''}',
                style: TextStyle(color: colors.textSecondary),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _busyId != null ||
                        (item.type == 'WORKSHOP' && !enrolled && seats == 0)
                    ? null
                    : () => _action(item),
                child: _busyId == item.id
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        item.type == 'WORKSHOP'
                            ? (enrolled
                                  ? 'Cancelar inscripción'
                                  : 'Inscribirme')
                            : item.type == 'TUTORING'
                            ? 'Ver tutoría'
                            : 'Ver recurso',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
