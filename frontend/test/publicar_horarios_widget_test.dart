import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/api_service.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/auth_remote_datasource.dart';
import 'package:ansiedad_ml_app/data/repositories/auth_repository_impl.dart';
import 'package:ansiedad_ml_app/domain/entities/cita.dart';
import 'package:ansiedad_ml_app/domain/repositories/citas_repository.dart';
import 'package:ansiedad_ml_app/domain/usecases/login_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/logout_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/register_usecase.dart';
import 'package:ansiedad_ml_app/presentation/pages/citas/agenda_unayoe_screen.dart';
import 'package:ansiedad_ml_app/presentation/pages/citas/publicar_horarios_screen.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/agenda_unayoe_viewmodel.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/auth_viewmodel.dart';
import 'fake_session_store.dart';

class _Repo implements CitasRepository {
  List<DateTime>? publicados;

  @override
  Future<List<Horario>> publicarHorarios(
    List<DateTime> inicios, {
    int? personalId,
  }) async {
    publicados = inicios;
    return [
      for (var i = 0; i < inicios.length; i++)
        Horario(
          id: i,
          staffUserId: 1,
          inicio: inicios[i],
          fin: inicios[i].add(const Duration(minutes: 30)),
        ),
    ];
  }

  @override
  Future<List<Cita>> agenda({String? estado}) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthViewModel _auth() {
  final repo = AuthRepositoryImpl(
    AuthRemoteDataSource(ApiService()),
    FakeSessionStore(),
  );
  return AuthViewModel(
    LoginUseCase(repo),
    RegisterUseCase(repo),
    LogoutUseCase(repo),
  );
}

Widget _app(_Repo repo, Widget home, {AuthViewModel? auth}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AgendaUnayoeViewModel(repo)),
    ChangeNotifierProvider<AuthViewModel>(create: (_) => auth ?? _auth()),
  ],
  child: MaterialApp(home: home),
);

void main() {
  group('Publicar horarios', () {
    Future<void> abrir(WidgetTester tester, _Repo repo) async {
      await tester.pumpWidget(
        _app(
          repo,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PublicarHorariosScreen(),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('lista cada bloque del rango, todos marcados', (tester) async {
      await abrir(tester, _Repo());
      // Rango por defecto 10:00-12:00 = 4 bloques de 30 min.
      for (final h in ['10:00', '10:30', '11:00', '11:30']) {
        expect(find.widgetWithText(FilterChip, h), findsOneWidget);
      }
      expect(find.text('Se publicarán 4 horarios.'), findsOneWidget);
    });

    testWidgets('desmarcar un bloque lo excluye de lo que se publica', (
      tester,
    ) async {
      final repo = _Repo();
      await abrir(tester, repo);

      await tester.tap(find.widgetWithText(FilterChip, '11:00'));
      await tester.pump();
      expect(find.text('Se publicarán 3 horarios.'), findsOneWidget);

      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();

      final horas = repo.publicados!.map((d) => '${d.hour}:${d.minute}').toList();
      expect(horas, ['10:0', '10:30', '11:30']);
    });

    testWidgets('con todos desmarcados no se puede publicar', (tester) async {
      await abrir(tester, _Repo());
      for (final h in ['10:00', '10:30', '11:00', '11:30']) {
        await tester.tap(find.widgetWithText(FilterChip, h));
      }
      await tester.pump();
      expect(find.text('Marca al menos un horario para publicar.'), findsOneWidget);
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Publicar'),
      );
      expect(boton.onPressed, isNull);
    });
  });

  group('Agenda UNAYOE: cerrar sesion', () {
    // AuthViewModel.onSessionReset se invoca al empezar a cerrar la sesion.
    var cerrada = false;
    setUp(() => cerrada = false);

    testWidgets('pide confirmacion y Volver no cierra la sesion', (tester) async {
      final auth = _auth();
      auth.onSessionReset = () => cerrada = true;
      await tester.pumpWidget(_app(_Repo(), const AgendaUnayoeScreen(), auth: auth));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();
      expect(find.text('¿Seguro que quieres cerrar sesión?'), findsOneWidget);

      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('¿Seguro que quieres cerrar sesión?'), findsNothing);
      expect(find.text('Agenda UNAYOE'), findsOneWidget);
      expect(cerrada, isFalse);
    });

    testWidgets('al confirmar se cierra la sesion', (tester) async {
      final auth = _auth();
      auth.onSessionReset = () => cerrada = true;
      await tester.pumpWidget(
        _app(_Repo(), const AgendaUnayoeScreen(), auth: auth),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();
      expect(cerrada, isFalse, reason: 'el diálogo aún no se confirmó');

      await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(cerrada, isTrue);
      expect(find.text('¿Seguro que quieres cerrar sesión?'), findsNothing);
    });
  });
}
