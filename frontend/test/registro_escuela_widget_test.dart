import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ansiedad_ml_app/data/datasources/local/escuela_local_datasource.dart';
import 'package:ansiedad_ml_app/data/repositories/escuela_repository_impl.dart';
import 'package:ansiedad_ml_app/domain/entities/escuela.dart';
import 'package:ansiedad_ml_app/domain/entities/usuario.dart';
import 'package:ansiedad_ml_app/domain/repositories/auth_repository.dart';
import 'package:ansiedad_ml_app/domain/usecases/login_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/logout_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/obtener_escuelas_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/register_usecase.dart';
import 'package:ansiedad_ml_app/presentation/pages/auth/registro_screen.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/escuela_viewmodel.dart';

/// Repositorio de autenticación falso: no realiza HTTP, contabiliza las
/// llamadas de registro, guarda los parámetros enviados y permite simular
/// errores y envíos lentos.
class _AuthRepositoryPrueba implements AuthRepository {
  @override
  Future<({String token, Usuario usuario})?> restaurarSesion() async => null;
  bool registroLlamado = false;
  int registroLlamas = 0;
  ({
    String nombres,
    String apellidos,
    String codigo,
    String correo,
    String contrasena,
    String escuela,
    int ciclo,
  })? ultimoRegistro;
  Object? errorAInsertar;
  Completer<void>? espera;

  @override
  Future<({String token, Usuario usuario})> login({
    required String correo,
    required String contrasena,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> registrar({
    required String nombres,
    required String apellidos,
    required String codigo,
    required String correo,
    required String contrasena,
    required String escuela,
    required int ciclo,
  }) async {
    registroLlamado = true;
    registroLlamas += 1;
    ultimoRegistro = (
      nombres: nombres,
      apellidos: apellidos,
      codigo: codigo,
      correo: correo,
      contrasena: contrasena,
      escuela: escuela,
      ciclo: ciclo,
    );
    final esperaRegistro = espera;
    if (esperaRegistro != null) {
      await esperaRegistro.future;
    }
    final error = errorAInsertar;
    if (error != null) throw error;
  }

  @override
  Future<void> logout() {
    throw UnimplementedError();
  }
}

/// Monta la pantalla de registro con el catálogo real (asset local), el
/// repositorio falso y la ruta /login, y espera a que la UI quede estable.
Future<_AuthRepositoryPrueba> _pumpRegistro(WidgetTester tester) async {
  final authRepository = _AuthRepositoryPrueba();

  final escuelaViewModel = EscuelaViewModel(
    ObtenerEscuelasUseCase(EscuelaRepositoryImpl(EscuelaLocalDataSource())),
  );
  // La carga del asset se realiza en contexto asíncrono real con runAsync:
  // dentro de testWidgets, flutter test solo entrega la primera lectura de
  // rootBundle por proceso de prueba.
  await tester.runAsync(() => escuelaViewModel.cargarEscuelas());

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<EscuelaViewModel>.value(
          value: escuelaViewModel,
        ),
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(
            LoginUseCase(authRepository),
            RegisterUseCase(authRepository),
            LogoutUseCase(authRepository),
          ),
        ),
      ],
      child: MaterialApp(
        home: const Scaffold(body: RegistroScreen()),
        routes: {
          '/login': (_) => const Scaffold(body: Text('Pantalla de Login')),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return authRepository;
}

/// Ejecuta la validación del formulario completo vía su [FormState].
Future<void> _validarFormulario(WidgetTester tester) async {
  final form = tester.state<FormState>(find.byType(Form));
  form.validate();
  await tester.pump();
}

/// Llena los seis campos de texto con datos válidos.
Future<void> _llenarFormulario(WidgetTester tester) async {
  final campos = find.byType(TextFormField);
  await tester.ensureVisible(campos.at(0));
  await tester.enterText(campos.at(0), 'Ana');
  await tester.enterText(campos.at(1), 'Torres Vargas');
  await tester.enterText(campos.at(2), '0012345');
  await tester.enterText(campos.at(3), 'ana@correo.com');
  await tester.enterText(campos.at(4), 'clave123456');
  await tester.enterText(campos.at(5), 'clave123456');
  await tester.pump();
}

/// Selecciona una escuela en el dropdown del catálogo.
Future<void> _seleccionarEscuela(WidgetTester tester, String nombre) async {
  final dropdown = find.byType(DropdownButtonFormField<Escuela>);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(nombre).last);
  await tester.pumpAndSettle();
}

/// Selecciona un ciclo en su dropdown.
Future<void> _seleccionarCiclo(WidgetTester tester, String ciclo) async {
  final dropdown = find.byType(DropdownButtonFormField<int>);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  final opcion = find.text(ciclo);
  await tester.scrollUntilVisible(
    opcion,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(opcion.last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'muestra las 74 escuelas del catálogo y permite seleccionar una',
    (tester) async {
      final authRepository = await _pumpRegistro(tester);
      expect(authRepository.registroLlamado, isFalse);

      final escuelaVM = Provider.of<EscuelaViewModel>(
        tester.element(find.byType(RegistroScreen)),
        listen: false,
      );
      expect(escuelaVM.error, isNull);
      expect(escuelaVM.escuelas.length, 74);

      final dropdown = find.byType(DropdownButtonFormField<Escuela>);
      expect(dropdown, findsOneWidget);

      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // La primera escuela del orden alfabético está en el menú abierto.
      expect(find.text('Administración'), findsWidgets);

      await tester.tap(find.text('Administración').last);
      await tester.pumpAndSettle();

      // Con el menú cerrado, la selección se conserva en el campo.
      expect(find.text('Administración'), findsOneWidget);
    },
  );

  group('Formulario de registro (campos Users)', () {
    testWidgets(
      'presenta los campos Nombres, Apellidos y Código de estudiante',
      (tester) async {
        await _pumpRegistro(tester);

        expect(find.byType(TextFormField), findsNWidgets(6));
        expect(find.text('Nombres'), findsOneWidget);
        expect(find.text('Apellidos'), findsOneWidget);
        expect(find.text('Código de estudiante'), findsOneWidget);
      },
    );

    testWidgets('valida los campos obligatorios con mensajes en español', (
      tester,
    ) async {
      await _pumpRegistro(tester);

      await _validarFormulario(tester);

      expect(find.text('Por favor, ingresa tus nombres'), findsOneWidget);
      expect(find.text('Por favor, ingresa tus apellidos'), findsOneWidget);
      expect(
        find.text('Por favor, ingresa tu código de estudiante'),
        findsOneWidget,
      );
      expect(find.text('Por favor, ingresa tu correo'), findsOneWidget);
      expect(find.text('Selecciona tu escuela profesional'), findsOneWidget);
    });

    testWidgets(
      'conserva el código de estudiante como texto con ceros iniciales',
      (tester) async {
        await _pumpRegistro(tester);

        final campos = find.byType(TextFormField);
        await tester.ensureVisible(campos.at(2));
        await tester.enterText(campos.at(2), '0012345');
        await tester.pump();

        final editableCodigo = tester.widget<EditableText>(
          find.descendant(
            of: campos.at(2),
            matching: find.byType(EditableText),
          ),
        );
        expect(editableCodigo.controller.text, '0012345');
      },
    );

    testWidgets('las contraseñas deben coincidir', (tester) async {
      await _pumpRegistro(tester);

      final campos = find.byType(TextFormField);
      await tester.ensureVisible(campos.at(4));
      await tester.enterText(campos.at(4), 'clave123456');
      await tester.enterText(campos.at(5), 'claveDISTINTA');
      await tester.pump();

      await _validarFormulario(tester);

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });
  });

  group('Conexión del registro con Users', () {
    testWidgets('envía los siete campos correctos al registrarse', (
      tester,
    ) async {
      final authRepository = await _pumpRegistro(tester);
      await _llenarFormulario(tester);
      await _seleccionarEscuela(tester, 'Administración');
      await _seleccionarCiclo(tester, 'Ciclo 3');

      final boton = find.widgetWithText(ElevatedButton, 'Crear Cuenta');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(authRepository.registroLlamas, 1);
      final registro = authRepository.ultimoRegistro;
      expect(
        registro,
        (
          nombres: 'Ana',
          apellidos: 'Torres Vargas',
          codigo: '0012345',
          correo: 'ana@correo.com',
          contrasena: 'clave123456',
          escuela: 'Administración',
          ciclo: 3,
        ),
      );
      // Escuela viaja únicamente como nombre (sin facultad ni área).
      expect(registro!.escuela, isNot(contains('Facultad')));
      // Código como texto y ciclo como entero.
      expect(registro.codigo, isA<String>());
      expect(registro.ciclo, isA<int>());
      // La confirmación de contraseña no forma parte de la tupla enviada.
      expect(registro.toString(), isNot(contains('confirmation')));

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('el registro exitoso muestra mensaje y navega a login', (
      tester,
    ) async {
      final authRepository = await _pumpRegistro(tester);
      await _llenarFormulario(tester);
      await _seleccionarEscuela(tester, 'Administración');

      final boton = find.widgetWithText(ElevatedButton, 'Crear Cuenta');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(authRepository.registroLlamado, isTrue);
      expect(find.byType(RegistroScreen), findsNothing);
      expect(find.text('Pantalla de Login'), findsOneWidget);
      expect(
        find.text('¡Cuenta creada con éxito! Inicia sesión para continuar.'),
        findsWidgets,
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('un registro válido llama una sola vez al repositorio', (
      tester,
    ) async {
      final authRepository = await _pumpRegistro(tester);
      authRepository.espera = Completer<void>();
      await _llenarFormulario(tester);
      await _seleccionarEscuela(tester, 'Administración');

      final boton = find.widgetWithText(ElevatedButton, 'Crear Cuenta');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pump();
      // Segundo toque durante el envío: el botón ya está deshabilitado.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      authRepository.espera!.complete();
      await tester.pumpAndSettle();

      expect(authRepository.registroLlamas, 1);
      expect(find.text('Pantalla de Login'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('un formulario inválido no llama al repositorio', (
      tester,
    ) async {
      final authRepository = await _pumpRegistro(tester);

      final boton = find.widgetWithText(ElevatedButton, 'Crear Cuenta');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(authRepository.registroLlamas, 0);
      expect(find.byType(RegistroScreen), findsOneWidget);
      expect(find.text('Pantalla de Login'), findsNothing);
      expect(find.text('Por favor, ingresa tus nombres'), findsOneWidget);
    });

    testWidgets('un error 400 muestra el detalle sin navegar ni prefijos', (
      tester,
    ) async {
      final authRepository = await _pumpRegistro(tester);
      authRepository.errorAInsertar =
          Exception('Datos de registro inválidos: Email inválido');
      await _llenarFormulario(tester);
      await _seleccionarEscuela(tester, 'Administración');

      final boton = find.widgetWithText(ElevatedButton, 'Crear Cuenta');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(
        find.text('Datos de registro inválidos: Email inválido'),
        findsOneWidget,
      );
      expect(find.textContaining('Exception:'), findsNothing);
      expect(find.byType(RegistroScreen), findsOneWidget);
      expect(find.text('Pantalla de Login'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('un error 409 muestra el mensaje del backend sin navegar', (
      tester,
    ) async {
      final authRepository = await _pumpRegistro(tester);
      authRepository.errorAInsertar = Exception('El email ya está registrado');
      await _llenarFormulario(tester);
      await _seleccionarEscuela(tester, 'Administración');

      final boton = find.widgetWithText(ElevatedButton, 'Crear Cuenta');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(find.text('El email ya está registrado'), findsOneWidget);
      expect(find.textContaining('Exception:'), findsNothing);
      expect(find.byType(RegistroScreen), findsOneWidget);
      expect(find.text('Pantalla de Login'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('el botón se deshabilita durante el envío', (tester) async {
      final authRepository = await _pumpRegistro(tester);
      authRepository.espera = Completer<void>();
      await _llenarFormulario(tester);
      await _seleccionarEscuela(tester, 'Administración');

      final boton = find.widgetWithText(ElevatedButton, 'Crear Cuenta');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pump();

      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Los datos del formulario se conservan durante el envío.
      final editableNombre = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).at(0),
          matching: find.byType(EditableText),
        ),
      );
      expect(editableNombre.controller.text, 'Ana');

      authRepository.espera!.complete();
      await tester.pumpAndSettle();

      expect(authRepository.registroLlamas, 1);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('la escuela profesional es un campo obligatorio', (
    tester,
  ) async {
    final authRepository = await _pumpRegistro(tester);

    final campos = find.byType(TextFormField);
    expect(campos, findsNWidgets(6));

    await tester.ensureVisible(campos.at(0));
    await tester.enterText(campos.at(0), 'Ana');
    await tester.enterText(campos.at(1), 'Torres Vargas');
    await tester.enterText(campos.at(2), '0012345');
    await tester.enterText(campos.at(3), 'ana@correo.com');
    await tester.enterText(campos.at(4), 'clave123456');
    await tester.enterText(campos.at(5), 'clave123456');
    await tester.pump();

    await _validarFormulario(tester);

    expect(find.text('Selecciona tu escuela profesional'), findsOneWidget);
    expect(authRepository.registroLlamado, isFalse);
  });
}
