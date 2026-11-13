import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ansiedad_ml_app/domain/entities/cita.dart';
import 'package:ansiedad_ml_app/domain/repositories/citas_repository.dart';
import 'package:ansiedad_ml_app/presentation/pages/citas/mis_citas_screen.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/citas_viewmodel.dart';

class _Repo implements CitasRepository {
  _Repo(this.recordatorios);
  final List<Recordatorio> recordatorios;

  // Dentro de 20 h: el aviso toca y todavia se puede cambiar (faltan >= 12 h).
  static final inicio = DateTime.now().toUtc().add(const Duration(hours: 20));

  @override
  Future<List<Cita>> misCitas() async => [
    Cita(
      id: 1,
      slotId: 1,
      inicio: inicio,
      fin: inicio.add(const Duration(minutes: 30)),
      estado: Cita.confirmada,
      prioridad: 'NORMAL',
    ),
  ];

  @override
  Future<List<Recordatorio>> misRecordatorios() async => recordatorios;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Recordatorio _rec({required bool corresponde, bool puedeCambiar = true}) =>
    Recordatorio(
      citaId: 1,
      inicio: _Repo.inicio,
      fin: _Repo.inicio.add(const Duration(minutes: 30)),
      estado: Cita.confirmada,
      horasRestantes: 20,
      corresponde: corresponde,
      puedeCambiar: puedeCambiar,
      puedeCambiarHasta: _Repo.inicio.subtract(const Duration(hours: 12)),
    );

Widget _app(_Repo repo) => ChangeNotifierProvider(
  create: (_) => CitasViewModel(repo),
  child: const MaterialApp(home: MisCitasScreen()),
);

void main() {
  testWidgets('muestra el recordatorio cuando ya corresponde', (tester) async {
    await tester.pumpWidget(_app(_Repo([_rec(corresponde: true)])));
    await tester.pumpAndSettle();
    expect(find.text('Tienes una cita próxima'), findsOneWidget);
    expect(find.textContaining('faltan 20 horas'), findsOneWidget);
    expect(find.textContaining('cancélala o reprográmala hasta'), findsOneWidget);
    // El aviso nunca menciona riesgo ni probabilidad.
    expect(find.textContaining('riesgo'), findsNothing);
    expect(find.textContaining('probabilidad'), findsNothing);
  });

  testWidgets('si todavia no corresponde, no muestra nada', (tester) async {
    await tester.pumpWidget(_app(_Repo([_rec(corresponde: false)])));
    await tester.pumpAndSettle();
    expect(find.text('Tienes una cita próxima'), findsNothing);
  });

  testWidgets('sin margen para cambiar, indica avisar a UNAYOE', (tester) async {
    await tester.pumpWidget(
      _app(_Repo([_rec(corresponde: true, puedeCambiar: false)])),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('avisa a UNAYOE'), findsOneWidget);
  });
}
