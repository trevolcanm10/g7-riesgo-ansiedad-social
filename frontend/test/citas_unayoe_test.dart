import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ansiedad_ml_app/core/jwt_claims.dart';
import 'package:ansiedad_ml_app/data/models/cita_model.dart';
import 'package:ansiedad_ml_app/domain/entities/cita.dart';
import 'package:ansiedad_ml_app/domain/repositories/citas_repository.dart';
import 'package:ansiedad_ml_app/domain/services/horarios_service.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/agenda_unayoe_viewmodel.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/citas_viewmodel.dart';

String _jwt(Map<String, dynamic> payload) {
  String b64(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64(payload)}.firma';
}

class _FakeRepo implements CitasRepository {
  List<Cita> citas = [];
  final llamadas = <String>[];
  Object? falla;

  Cita _c(int id, String estado) => Cita(
    id: id,
    slotId: 1,
    inicio: DateTime.utc(2026, 11, 20, 15),
    fin: DateTime.utc(2026, 11, 20, 15, 30),
    estado: estado,
    prioridad: 'NORMAL',
  );

  /// Simula que las lecturas (recarga de listas) fallan, p. ej. por el límite de peticiones.
  bool fallaLecturas = false;

  @override
  Future<List<Cita>> agenda({String? estado}) async {
    llamadas.add('agenda:$estado');
    if (fallaLecturas) throw Exception('429');
    return citas;
  }

  @override
  Future<Cita> cambiarEstado(int citaId, String estado) async {
    llamadas.add('estado:$citaId:$estado');
    if (falla != null) throw falla!;
    citas = [_c(citaId, estado)];
    return citas.first;
  }

  @override
  Future<Cita> cancelar(int citaId) async => _c(citaId, Cita.cancelada);

  @override
  Future<List<Horario>> publicarHorarios(
    List<DateTime> inicios, {
    int? personalId,
  }) async {
    llamadas.add('publicar:${inicios.length}:$personalId');
    if (falla != null) throw falla!;
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
  Future<RiesgoInasistencia> riesgoInasistencia(int citaId) async =>
      const RiesgoInasistencia(
        probabilidad: 0.25,
        factores: ['anticipacion'],
        modelo: 'rule-based-baseline-v0',
      );

  List<Horario> horarios = [];

  @override
  Future<List<Horario>> horariosLibres() async {
    if (fallaLecturas) throw Exception('429');
    llamadas.add('horarios');
    return horarios;
  }

  @override
  Future<List<Cita>> misCitas() async {
    if (fallaLecturas) throw Exception('429');
    return [];
  }
  @override
  Future<Cita> reprogramar(int citaId, int slotId) async => _c(citaId, 'X');
  @override
  Future<Cita> solicitar({
    required int slotId,
    required String prioridad,
    String? motivo,
  }) async => _c(1, Cita.solicitada);
}

void main() {
  group('rolDeToken', () {
    test('lee el rol del payload', () {
      expect(rolDeToken(_jwt({'userId': 1, 'role': 'PERSONAL_UNAYOE'})),
          'PERSONAL_UNAYOE');
    });
    test('devuelve null con token invalido o sin rol', () {
      expect(rolDeToken(null), isNull);
      expect(rolDeToken('basura'), isNull);
      expect(rolDeToken('a.%%%.c'), isNull);
      expect(rolDeToken(_jwt({'userId': 1})), isNull);
    });
  });

  group('Cita.prioridadPara', () {
    test('solo el riesgo alto marca la solicitud como prioritaria', () {
      expect(Cita.prioridadPara('ALTO'), 'ALTA');
      expect(Cita.prioridadPara('alto'), 'ALTA');
      expect(Cita.prioridadPara('MEDIO'), 'NORMAL');
      expect(Cita.prioridadPara('BAJO'), 'NORMAL');
      expect(Cita.prioridadPara(null), 'NORMAL');
    });
  });

  group('generarInicios', () {
    test('10:00-12:00 da 4 bloques de 30 min', () {
      final r = generarInicios(
        DateTime(2026, 11, 20, 10),
        DateTime(2026, 11, 20, 12),
      );
      expect(r.length, 4);
      expect(r.last, DateTime(2026, 11, 20, 11, 30));
    });
    test('un rango menor a 30 min o invertido no genera nada', () {
      expect(
        generarInicios(DateTime(2026, 11, 20, 10), DateTime(2026, 11, 20, 10, 20)),
        isEmpty,
      );
      expect(
        generarInicios(DateTime(2026, 11, 20, 12), DateTime(2026, 11, 20, 10)),
        isEmpty,
      );
    });
  });

  group('CitaModel', () {
    test('lee estudiante y personal de la cita', () {
      final c = CitaModel.citaFromJson({
        'id': 5,
        'slotId': 2,
        'startAt': '2026-11-20T15:00:00Z',
        'endAt': '2026-11-20T15:30:00Z',
        'status': 'SOLICITADA',
        'studentUserId': 7,
        'staffUserId': 9,
      });
      expect(c.estudianteId, 7);
      expect(c.personalId, 9);
    });
    test('riesgo sin probabilidad es invalido', () {
      expect(
        () => CitaModel.riesgoFromJson({'factors': []}),
        throwsFormatException,
      );
    });
  });

  group('CitasViewModel', () {
    Horario h(int id) => Horario(
      id: id,
      staffUserId: 1,
      inicio: DateTime.utc(2026, 11, 20, 15),
      fin: DateTime.utc(2026, 11, 20, 15, 30),
    );

    test('solicitar aplica la cita y quita el horario sin pedir nada mas', () async {
      final repo = _FakeRepo()..horarios = [h(1), h(2)];
      final vm = CitasViewModel(repo);
      await vm.cargarHorarios();
      final ok = await vm.solicitar(slotId: 1, prioridad: 'NORMAL');
      expect(ok, isTrue);
      expect(vm.horarios.map((x) => x.id), [2]);
      expect(vm.citas.single.estado, Cita.solicitada);
      expect(repo.llamadas, ['horarios'], reason: 'solo la carga inicial, sin recarga');
    });

    test('cancelar reemplaza la cita por la que devuelve el servidor', () async {
      final repo = _FakeRepo()..horarios = [h(1)];
      final vm = CitasViewModel(repo);
      await vm.solicitar(slotId: 1, prioridad: 'NORMAL');
      expect(await vm.cancelar(1), isTrue);
      expect(vm.citas.single.estado, Cita.cancelada);
      expect(vm.citas, hasLength(1));
    });

    test('con las lecturas caidas (429) la escritura sigue siendo exito', () async {
      final repo = _FakeRepo()..fallaLecturas = true;
      final vm = CitasViewModel(repo);
      final ok = await vm.solicitar(slotId: 1, prioridad: 'NORMAL');
      expect(ok, isTrue);
      expect(vm.error, isNull);
      expect(vm.guardando, isFalse);
    });
  });

  group('AgendaUnayoeViewModel', () {
    test('cambiar estado actualiza la lista local sin pedir la agenda otra vez', () async {
      final repo = _FakeRepo()..citas = [repo0()];
      final vm = AgendaUnayoeViewModel(repo);
      await vm.cargarAgenda();
      expect(await vm.cambiarEstado(1, Cita.confirmada), isTrue);
      expect(vm.agenda.single.estado, Cita.confirmada);
      expect(repo.llamadas, ['agenda:null', 'estado:1:CONFIRMADA']);
    });

    test('si la cita deja de cumplir el filtro vigente, sale de la lista', () async {
      final repo = _FakeRepo()..citas = [repo0()];
      final vm = AgendaUnayoeViewModel(repo);
      await vm.cargarAgenda(filtro: Cita.solicitada);
      expect(vm.agenda, hasLength(1));
      await vm.cambiarEstado(1, Cita.confirmada);
      expect(vm.agenda, isEmpty);
    });

    test('un error del servicio se muestra y no refresca', () async {
      final repo = _FakeRepo()..falla = Exception('Transicion invalida');
      final vm = AgendaUnayoeViewModel(repo);
      final ok = await vm.cambiarEstado(3, Cita.atendida);
      expect(ok, isFalse);
      expect(vm.error, 'Transicion invalida');
      expect(repo.llamadas, ['estado:3:ATENDIDA']);
    });

    test('publicar devuelve la cantidad creada y pasa el id del personal', () async {
      final repo = _FakeRepo();
      final vm = AgendaUnayoeViewModel(repo);
      final inicios = generarInicios(
        DateTime(2026, 11, 20, 10),
        DateTime(2026, 11, 20, 11),
      );
      expect(await vm.publicar(inicios, personalId: 9), 2);
      expect(repo.llamadas.single, 'publicar:2:9');
    });

    test('si la escritura se aplica pero la recarga falla, sigue siendo exito', () async {
      final repo = _FakeRepo()..fallaLecturas = true;
      final vm = AgendaUnayoeViewModel(repo);
      final ok = await vm.cambiarEstado(3, Cita.confirmada);
      expect(ok, isTrue);
      expect(vm.error, isNull);
      expect(vm.guardando, isFalse);
      expect(repo.llamadas.first, 'estado:3:CONFIRMADA');
    });

    test('limpiarSesion vacia el estado', () async {
      final repo = _FakeRepo()..citas = [repo0()];
      final vm = AgendaUnayoeViewModel(repo);
      await vm.cargarAgenda();
      expect(vm.agenda, isNotEmpty);
      vm.limpiarSesion();
      expect(vm.agenda, isEmpty);
    });
  });
}

Cita repo0() => Cita(
  id: 1,
  slotId: 1,
  inicio: DateTime.utc(2026, 11, 20, 15),
  fin: DateTime.utc(2026, 11, 20, 15, 30),
  estado: Cita.solicitada,
  prioridad: 'NORMAL',
);
