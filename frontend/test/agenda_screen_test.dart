import 'package:ansiedad_ml_app/core/app_colors.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/api_service.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/auth_remote_datasource.dart';
import 'package:ansiedad_ml_app/data/repositories/agenda_remote_repository.dart';
import 'package:ansiedad_ml_app/data/repositories/auth_repository_impl.dart';
import 'package:ansiedad_ml_app/domain/entities/actividad_academica.dart';
import 'package:ansiedad_ml_app/domain/repositories/agenda_repository.dart';
import 'package:ansiedad_ml_app/domain/services/session_store.dart';
import 'package:ansiedad_ml_app/domain/usecases/login_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/logout_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/register_usecase.dart';
import 'package:ansiedad_ml_app/presentation/pages/agenda/agenda_screen.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Repository implements AgendaRepository {
  _Repository(this.items);
  List<ActividadAcademica> items;
  int reads = 0;
  @override
  Future<List<ActividadAcademica>> obtener() async {
    reads++;
    return items;
  }

  @override
  Future<void> guardar(List<ActividadAcademica> next) async => items = next;
}

class _UnavailableRepository extends _Repository {
  _UnavailableRepository() : super([]);

  @override
  Future<void> guardar(List<ActividadAcademica> next) async {
    throw ApiException(statusCode: 503, mensaje: 'Base no disponible');
  }
}

class _InitiallyUnavailableRepository extends _Repository {
  _InitiallyUnavailableRepository() : super([]);

  @override
  Future<List<ActividadAcademica>> obtener() async {
    reads++;
    if (reads == 1) {
      throw ApiException(statusCode: 503, mensaje: 'Base no disponible');
    }
    return items;
  }
}

class _InsightRepository extends AgendaRemoteRepository {
  _InsightRepository(this.items)
    : super(ApiService(), 'http://localhost/agenda/actividades');
  final List<ActividadAcademica> items;
  Map<String, num>? indicators;

  @override
  Future<List<ActividadAcademica>> obtener() async => items;

  @override
  Future<AgendaWeeklyClassification> clasificarSemana(
    Map<String, num> values,
  ) async {
    indicators = values;
    return const AgendaWeeklyClassification(
      nivel: 'ALTA',
      probabilidadNivel: 0.8,
      probabilidades: {'BAJA': 0.1, 'MODERADA': 0.1, 'ALTA': 0.8},
    );
  }

  @override
  Future<AgendaPreventiveAlerts> obtenerAlertas(
    Map<String, num> values,
  ) async => const AgendaPreventiveAlerts(
    nivel: 'ALTA',
    alertas: [
      {
        'codigo': 'AB-004',
        'mensaje': 'Carga académica alta esta semana.',
        'severidad': 'alto',
      },
    ],
    recomendacion: 'Planifica las entregas.',
  );
}

class FakeSessionStore implements SessionStore {
  StoredSession? session;
  @override
  Future<StoredSession?> read() async => session;
  @override
  Future<void> write(StoredSession value) async {
    session = value;
  }

  @override
  Future<void> delete() async {
    session = null;
  }
}

ActividadAcademica _activity(
  String id,
  DateTime date,
  String title, {
  bool completed = false,
}) => ActividadAcademica(
  id: id,
  titulo: title,
  curso: 'Ingeniería de Software',
  tipo: 'proyecto',
  fecha: date,
  hora: '10:00',
  duracionEstimadaHoras: 2,
  prioridad: 'alta',
  descripcion: '',
  completada: completed,
);

Future<void> _pump(
  WidgetTester tester,
  AgendaRepository repository, {
  Size size = const Size(375, 667),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthViewModel(
        LoginUseCase(
          AuthRepositoryImpl(
            AuthRemoteDataSource(ApiService()),
            FakeSessionStore(),
          ),
        ),
        RegisterUseCase(
          AuthRepositoryImpl(
            AuthRemoteDataSource(ApiService()),
            FakeSessionStore(),
          ),
        ),
        LogoutUseCase(
          AuthRepositoryImpl(
            AuthRemoteDataSource(ApiService()),
            FakeSessionStore(),
          ),
        ),
      ),
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: AgendaScreen(repository: repository),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('un 503 de lectura muestra reintento y recupera la agenda', (tester) async {
    final repo = _InitiallyUnavailableRepository();
    await _pump(tester, repo, size: const Size(800, 1600));
    expect(find.textContaining('servicio de agenda no está disponible (503)'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(repo.reads, 2);
    expect(find.text('Aún no tienes actividades.'), findsOneWidget);
  });
  testWidgets(
    'muestra clasificación y avisos remotos con indicadores semanales',
    (tester) async {
      final repo = _InsightRepository([
        _activity('1', DateTime.now(), 'Entrega'),
      ]);
      await _pump(tester, repo);
      expect(repo.indicators?['num_actividades'], 1);
      expect(find.text('ALTA'), findsOneWidget);
      expect(
        find.textContaining('Carga académica alta esta semana.'),
        findsOneWidget,
      );
      expect(find.text('Planifica las entregas.'), findsOneWidget);
      expect(find.textContaining('Estimación local de respaldo'), findsNothing);
    },
  );
  testWidgets(
    'calendar uses current month, day activities and month navigation',
    (tester) async {
      final now = DateTime.now();
      final repo = _Repository([_activity('1', now, 'Entrega actual')]);
      await _pump(tester, repo);
      expect(find.text('Agenda Académica'), findsOneWidget);
      expect(find.text('Entrega actual'), findsOneWidget);
      expect(find.text('Nueva actividad'), findsOneWidget);
      final weekly = find.textContaining('Carga semanal');
      expect(weekly, findsOneWidget);
      final currentWeek = tester.widget<Text>(weekly).data;
      expect(
        tester.getTopLeft(weekly).dy,
        greaterThan(tester.getTopLeft(find.text('Calendario')).dy),
      );
      expect(
        tester.getTopLeft(weekly).dy,
        lessThan(tester.getTopLeft(find.byTooltip('Mes siguiente')).dy),
      );
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();
      expect(weekly, findsOneWidget);
      expect(tester.widget<Text>(weekly).data, isNot(currentWeek));
      expect(find.text('Entrega actual'), findsNothing);
      await tester.tap(find.text('Próximas'));
      await tester.pumpAndSettle();
      expect(weekly, findsOneWidget);
      expect(tester.widget<Text>(weekly).data, currentWeek);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'upcoming activities use repository data, order and detail actions',
    (tester) async {
      final now = DateTime.now();
      final later = DateTime(now.year, now.month, now.day + 3);
      final sooner = DateTime(now.year, now.month, now.day + 1);
      final repo = _Repository([
        _activity('2', later, 'Segunda entrega'),
        _activity('1', sooner, 'Primera entrega'),
      ]);
      await _pump(tester, repo);
      await tester.tap(find.text('Próximas'));
      await tester.pumpAndSettle();
      expect(repo.reads, 2);
      expect(find.text('Primera entrega'), findsOneWidget);
      expect(find.text('Segunda entrega'), findsOneWidget);
      final first = tester.getTopLeft(find.text('Primera entrega')).dy;
      final second = tester.getTopLeft(find.text('Segunda entrega')).dy;
      expect(first, lessThan(second));
      await tester.drag(find.byType(ListView), const Offset(0, -280));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Primera entrega'));
      await tester.pumpAndSettle();
      expect(find.text('Completar'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
      await tester.tap(find.text('Completar'));
      await tester.pumpAndSettle();
      expect(
        repo.items.singleWhere((item) => item.id == '1').completada,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty agenda and wide layout remain usable', (tester) async {
    final repo = _Repository([]);
    await _pump(tester, repo, size: const Size(1200, 900));
    expect(find.text('Aún no tienes actividades.'), findsOneWidget);
    await tester.tap(find.text('Próximas'));
    await tester.pumpAndSettle();
    expect(repo.reads, 2);
    expect(find.text('Aún no tienes actividades.'), findsOneWidget);
    expect(find.text('Nueva actividad'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un 503 conserva el borrador y permite reintentar', (
    tester,
  ) async {
    await _pump(tester, _UnavailableRepository(), size: const Size(800, 1600));
    await tester.tap(find.text('Nueva actividad'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título *'),
      'Trabajo final',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Curso/asignatura *'),
      'Curso',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('servicio de agenda'), findsWidgets);
    expect(find.text('Trabajo final'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });
}
