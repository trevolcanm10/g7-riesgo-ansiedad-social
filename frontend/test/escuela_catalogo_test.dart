import 'package:flutter_test/flutter_test.dart';

import 'package:ansiedad_ml_app/data/datasources/local/escuela_local_datasource.dart';
import 'package:ansiedad_ml_app/data/repositories/escuela_repository_impl.dart';
import 'package:ansiedad_ml_app/domain/entities/escuela.dart';
import 'package:ansiedad_ml_app/domain/usecases/obtener_escuelas_usecase.dart';

/// Normaliza un texto para comparar el orden alfabético en la prueba.
String sinAcentos(String texto) {
  const conAcentos = 'áéíóúüñ';
  const planos = 'aeiouun';
  var resultado = texto.toLowerCase();
  for (var i = 0; i < conAcentos.length; i++) {
    resultado = resultado.replaceAll(conAcentos[i], planos[i]);
  }
  return resultado;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EscuelaLocalDataSource dataSource;
  late ObtenerEscuelasUseCase useCase;
  late List<Escuela> escuelas;

  setUpAll(() async {
    dataSource = EscuelaLocalDataSource();
    final repository = EscuelaRepositoryImpl(dataSource);
    useCase = ObtenerEscuelasUseCase(repository);
    escuelas = await useCase();
  });

  group('Catálogo real (assets/data/escuelas.json)', () {
    test('lee y procesa el JSON del asset', () {
      expect(escuelas, isNotEmpty);
    });

    test('extrae todas las escuelas profesionales', () {
      expect(escuelas.length, 74);
      expect(
        escuelas.map((e) => e.nombre),
        containsAll(<String>[
          'Medicina Humana',
          'Ingeniería de Software',
          'Administración',
          'Trabajo Social',
        ]),
      );
    });

    test('conserva la facultad y el área académica de cada escuela', () {
      final sistemas =
          escuelas.firstWhere((e) => e.nombre == 'Ingeniería de Sistemas');
      expect(sistemas.facultad,
          'Facultad de Ingeniería de Sistemas e Informática');
      expect(sistemas.areaAcademica, 'Área C: Ingenierías');

      final psicologia = escuelas.firstWhere((e) => e.nombre == 'Psicología');
      expect(psicologia.facultad, 'Facultad de Psicología');
      expect(psicologia.areaAcademica, 'Área A: Ciencias de la Salud');

      expect(
        escuelas.every(
          (e) => e.facultad.isNotEmpty && e.areaAcademica.isNotEmpty,
        ),
        isTrue,
      );
    });

    test('ordena las escuelas alfabéticamente', () {
      final nombres = escuelas.map((e) => e.nombre).toList();
      for (var i = 0; i < nombres.length - 1; i++) {
        final actual = sinAcentos(nombres[i]);
        final siguiente = sinAcentos(nombres[i + 1]);
        expect(
          actual.compareTo(siguiente),
          lessThanOrEqualTo(0),
          reason: '"${nombres[i]}" debe ir antes que "${nombres[i + 1]}"',
        );
      }
      expect(nombres.first, 'Administración');
      expect(nombres.last, 'Trabajo Social');
    });

    test('no contiene duplicados exactos', () {
      final claves = escuelas
          .map((e) => '${e.nombre}|${e.facultad}|${e.areaAcademica}')
          .toSet();
      expect(claves.length, escuelas.length);

      final nombres = escuelas.map((e) => e.nombre).toSet();
      expect(nombres.length, escuelas.length);
    });
  });

  group('procesarCatalogo con datos de prueba', () {
    const jsonPrueba = '''
{
  "areas_academicas": [
    {
      "area": "Área Z: Prueba",
      "facultades": [
        {
          "nombre": "Facultad de Prueba",
          "escuelas": ["Zootecnia", "Administración", "Zootecnia"]
        }
      ]
    },
    {
      "area": "Área Y: Otra Prueba",
      "facultades": [
        {
          "nombre": "Facultad Demo",
          "escuelas": ["Agronomía"]
        }
      ]
    }
  ]
}
''';

    test('extrae, relaciona, elimina duplicados exactos y ordena', () {
      final resultado = dataSource.procesarCatalogo(jsonPrueba);

      expect(resultado.length, 3);
      expect(
        resultado.map((e) => e.nombre).toList(),
        <String>['Administración', 'Agronomía', 'Zootecnia'],
      );

      final administracion =
          resultado.firstWhere((e) => e.nombre == 'Administración');
      expect(administracion.facultad, 'Facultad de Prueba');
      expect(administracion.areaAcademica, 'Área Z: Prueba');

      final agronomia = resultado.firstWhere((e) => e.nombre == 'Agronomía');
      expect(agronomia.facultad, 'Facultad Demo');
      expect(agronomia.areaAcademica, 'Área Y: Otra Prueba');
    });

    test('conserva escuelas homónimas de facultades distintas', () {
      const jsonHomonimas = '''
{
  "areas_academicas": [
    {
      "area": "Área X",
      "facultades": [
        {"nombre": "Facultad Uno", "escuelas": ["Derecho"]},
        {"nombre": "Facultad Dos", "escuelas": ["Derecho"]}
      ]
    }
  ]
}
''';

      final resultado = dataSource.procesarCatalogo(jsonHomonimas);

      expect(resultado.length, 2);
      expect(
        resultado.map((e) => e.facultad).toSet(),
        <String>{'Facultad Uno', 'Facultad Dos'},
      );
    });
  });
}
