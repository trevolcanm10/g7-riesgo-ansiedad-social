import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'domain/services/session_store.dart';
import 'data/datasources/local/secure_session_store.dart';
import 'domain/usecases/restaurar_sesion_usecase.dart';
import 'presentation/pages/auth/session_gate.dart';

// Core
import 'core/app_colors.dart';
import 'core/constants.dart';

// Data
import 'data/datasources/remote/api_service.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/evaluacion_repository_impl.dart';
import 'data/repositories/medico_repository_impl.dart';
import 'data/datasources/remote/auth_remote_datasource.dart';
import 'data/datasources/remote/evaluacion_remote_datasource.dart';
import 'data/datasources/remote/medico_remote_datasource.dart';
import 'data/datasources/local/escuela_local_datasource.dart';
import 'data/repositories/escuela_repository_impl.dart';

// Domain UseCases
import 'domain/usecases/login_usecase.dart';
import 'domain/usecases/register_usecase.dart';
import 'domain/usecases/logout_usecase.dart';
import 'domain/usecases/evaluar_riesgo_usecase.dart';
import 'domain/usecases/obtener_historial_usecase.dart';
import 'domain/usecases/obtener_estadisticas_medico_usecase.dart';
import 'domain/usecases/obtener_pacientes_usecase.dart';
import 'domain/usecases/obtener_evaluaciones_recientes_usecase.dart';
import 'domain/usecases/obtener_escuelas_usecase.dart';

// Presentation
import 'presentation/viewmodels/auth_viewmodel.dart';
import 'presentation/viewmodels/evaluacion_viewmodel.dart';
import 'presentation/viewmodels/medico_viewmodel.dart';
import 'presentation/viewmodels/theme_viewmodel.dart';
import 'presentation/viewmodels/escuela_viewmodel.dart';
import 'presentation/pages/onboarding/onboarding_screen.dart';
import 'presentation/pages/auth/login_screen.dart';
import 'presentation/pages/home/home_screen.dart';
import 'presentation/pages/admin/admin_home_screen.dart';
import 'presentation/pages/medico/medico_home_screen.dart';
import 'presentation/pages/evaluacion/evaluacion_screen.dart';
import 'presentation/pages/evaluacion/resultado_screen.dart';
import 'presentation/pages/evaluacion/historial_screen.dart';
import 'presentation/pages/perfil/perfil_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar configuración de API (cargar URL guardada)
  await AppConstants.init();
  runApp(const AnsiedadApp());
}

class AnsiedadApp extends StatefulWidget {
  final SessionStore? sessionStore;
  const AnsiedadApp({super.key, this.sessionStore});
  @override
  State<AnsiedadApp> createState() => _AnsiedadAppState();
}

class _AnsiedadAppState extends State<AnsiedadApp> {
  late final List<SingleChildWidget> _providers;

  @override
  void initState() {
    super.initState();
    // ==========================================
    // INYECCIÓN DE DEPENDENCIAS (Clean Architecture)
    // ==========================================

    // Data Layer
    final apiService = ApiService();
    final authRemoteDataSource = AuthRemoteDataSource(apiService);
    final evaluacionRemoteDataSource = EvaluacionRemoteDataSource(apiService);
    final medicoRemoteDataSource = MedicoRemoteDataSource(apiService);
    final escuelaLocalDataSource = EscuelaLocalDataSource();

    // Repository Layer
    final authRepository = AuthRepositoryImpl(
      authRemoteDataSource,
      widget.sessionStore ?? const SecureSessionStore(),
    );
    final evaluacionRepository = EvaluacionRepositoryImpl(
      evaluacionRemoteDataSource,
    );
    final medicoRepository = MedicoRepositoryImpl(medicoRemoteDataSource);
    final escuelaRepository = EscuelaRepositoryImpl(escuelaLocalDataSource);

    // UseCase Layer
    final loginUseCase = LoginUseCase(authRepository);
    final registerUseCase = RegisterUseCase(authRepository);
    final logoutUseCase = LogoutUseCase(authRepository);
    final evaluarRiesgoUseCase = EvaluarRiesgoUseCase(evaluacionRepository);
    final obtenerHistorialUseCase = ObtenerHistorialUseCase(
      evaluacionRepository,
    );
    final obtenerEstadisticasMedicoUseCase = ObtenerEstadisticasMedicoUseCase(
      medicoRepository,
    );
    final obtenerPacientesUseCase = ObtenerPacientesUseCase(medicoRepository);
    final obtenerEvaluacionesRecientesUseCase =
        ObtenerEvaluacionesRecientesUseCase(medicoRepository);
    final obtenerEscuelasUseCase = ObtenerEscuelasUseCase(escuelaRepository);

    final evaluationVM = EvaluacionViewModel(
      evaluarRiesgoUseCase,
      obtenerHistorialUseCase,
    );
    final medicoVM = MedicoViewModel(
      obtenerEstadisticasMedicoUseCase,
      obtenerPacientesUseCase,
      obtenerEvaluacionesRecientesUseCase,
    );
    final authVM = AuthViewModel(
      loginUseCase,
      registerUseCase,
      logoutUseCase,
      RestaurarSesionUseCase(authRepository),
    );
    authVM.onSessionReset = () {
      evaluationVM.limpiarSesion();
      medicoVM.limpiarSesion();
    };
    apiService.onUnauthorized = authVM.invalidarSesion;
    _providers = [
      Provider<ApiService>.value(value: apiService),
      ChangeNotifierProvider(create: (_) => ThemeNotifier()),
      ChangeNotifierProvider(create: (_) => authVM, lazy: false),
      ChangeNotifierProvider(create: (_) => evaluationVM, lazy: false),
      ChangeNotifierProvider(create: (_) => medicoVM, lazy: false),
      ChangeNotifierProvider(
        create: (_) => EscuelaViewModel(obtenerEscuelasUseCase),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: _providers,
    child: Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        return MaterialApp(
          title: 'Evaluación de Riesgo',
          debugShowCheckedModeBanner: false,
          themeMode: themeNotifier.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1),
              secondary: Color(0xFF6366F1),
              surface: Colors.white,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 1,
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF1E293B),
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            extensions: [AppColors.light],
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF818CF8),
              secondary: Color(0xFF818CF8),
              surface: Color(0xFF1E293B),
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Color(0xFF0F172A),
              foregroundColor: Color(0xFFF1F5F9),
            ),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            extensions: [AppColors.dark],
          ),
          initialRoute: '/session',
          routes: {
            '/session': (_) => const SessionGate(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const SessionProtected(child: HomeScreen()),
            '/admin-home': (context) =>
                const SessionProtected(child: AdminHomeScreen()),
            '/medico-home': (context) =>
                const SessionProtected(child: MedicoHomeScreen()),
            '/evaluacion': (context) =>
                const SessionProtected(child: EvaluacionScreen()),
            '/resultado': (context) =>
                const SessionProtected(child: ResultadoScreen()),
            '/historial': (context) =>
                const SessionProtected(child: HistorialScreen()),
            '/perfil': (context) =>
                const SessionProtected(child: PerfilScreen()),
          },
        );
      },
    ),
  );
}
