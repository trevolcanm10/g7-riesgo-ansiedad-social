# Frontend Ansiedad ML App

> Aplicación móvil multiplataforma desarrollada en **Flutter** para la evaluación del riesgo de ansiedad estudiantil mediante Inteligencia Artificial.

---

## Arquitectura del Cliente

La aplicación implementa **Clean Architecture** combinada con **MVVM (Model-View-ViewModel)** en la capa de presentación, utilizando **Provider** como gestor de estado reactivo.

### Capas de Clean Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Capa de Presentación                      │
│  (MVVM: Pages + ViewModels + Widgets)                       │
│  - No conoce detalles de implementación de la API           │
│  - No realiza llamadas HTTP directamente                    │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                    Capa de Dominio                           │
│  (Entities + Repository Interfaces + UseCases)              │
│  - Lógica de negocio pura                                   │
│  - Sin dependencias de frameworks externos                  │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                    Capa de Datos                             │
│  (Models/DTOs + DataSources + Repository Implementations)   │
│  - Encapsula el acceso a datos y llamadas HTTP              │
└─────────────────────────────────────────────────────────────┘
```

### Flujo de Dependencias

```
Presentation (Pages/ViewModels)
    ↓
UseCases (domain/usecases/)
    ↓
Repository Interface (domain/repositories/)
    ↓
Repository Implementation (data/repositories/)
    ↓
DataSource (data/datasources/)
    ↓
API Backend
```

### Componentes por Capa

#### 1. **Domain** (Núcleo del negocio)

- **Entities**: Clases puras sin dependencias de serialización (`Usuario`, `Evaluacion`, `ResultadoMl`, `Recomendacion`, `ReporteIA`)
- **Repository Interfaces**: Contratos que definen las operaciones de datos
- **UseCases**: Una clase por operación de negocio (ej: `LoginUseCase`, `EvaluarRiesgoUseCase`)

#### 2. **Data** (Implementaciones concretas)

- **Models/DTOs**: Clases para serialización/deserialización JSON
- **DataSources**: Encapsulan llamadas HTTP (`ApiService` + DataSources específicos)
- **Repository Implementations**: Implementan las interfaces del domain

#### 3. **Presentation** (Interfaz de usuario - MVVM)

- **Pages** (`lib/presentation/pages/`): Vistas y pantallas de la aplicación
- **ViewModels** (`lib/presentation/viewmodels/`): Lógica de presentación y estado
- **Widgets** (`lib/presentation/widgets/`): Componentes UI reutilizables

#### 4. **Core** (Utilidades compartidas)

- **Constants**: Configuración global, URLs y endpoints
- **AppColors**: Paleta de colores de la aplicación
- **AppIcons**: Iconos personalizados

---

## Estructura de Directorios

```text
frontend/
├── android/                        # Archivos de configuración nativa de Android
├── assets/                         # Fuentes, imágenes y recursos estáticos
├── lib/                            # Código fuente de Dart
│   ├── core/                       # Utilidades compartidas
│   │   ├── app_colors.dart
│   │   ├── app_icons.dart
│   │   └── constants.dart          # Configuración de API y endpoints
│   │
│   ├── domain/                     # Capa de Dominio (lógica de negocio)
│   │   ├── entities/               # Entidades puras del negocio
│   │   │   ├── usuario.dart
│   │   │   ├── evaluacion.dart
│   │   │   ├── resultado_ml.dart
│   │   │   ├── recomendacion.dart
│   │   │   └── reporte_ia.dart
│   │   ├── repositories/           # Interfaces de repositorios
│   │   │   ├── auth_repository.dart
│   │   │   ├── evaluacion_repository.dart
│   │   │   └── medico_repository.dart
│   │   └── usecases/               # Casos de uso
│   │       ├── login_usecase.dart
│   │       ├── register_usecase.dart
│   │       ├── logout_usecase.dart
│   │       ├── evaluar_riesgo_usecase.dart
│   │       ├── obtener_historial_usecase.dart
│   │       ├── obtener_estadisticas_medico_usecase.dart
│   │       ├── obtener_pacientes_usecase.dart
│   │       └── obtener_evaluaciones_recientes_usecase.dart
│   │
│   ├── data/                       # Capa de Datos (implementaciones)
│   │   ├── models/                 # DTOs para serialización JSON
│   │   │   ├── usuario_model.dart
│   │   │   ├── evaluacion_model.dart
│   │   │   ├── resultado_ml_model.dart
│   │   │   ├── recomendacion_model.dart
│   │   │   └── reporte_ia_model.dart
│   │   ├── datasources/remote/     # DataSources para llamadas HTTP
│   │   │   ├── api_service.dart
│   │   │   ├── auth_remote_datasource.dart
│   │   │   ├── evaluacion_remote_datasource.dart
│   │   │   └── medico_remote_datasource.dart
│   │   └── repositories/           # Implementaciones de repositorios
│   │       ├── auth_repository_impl.dart
│   │       ├── evaluacion_repository_impl.dart
│   │       └── medico_repository_impl.dart
│   │
│   └── presentation/               # Capa de Presentación (MVVM)
│       ├── pages/                  # Views (pantallas de la app)
│       │   ├── admin/              # Pantallas de administrador
│       │   ├── auth/               # Login y Registro
│       │   ├── evaluacion/         # Cuestionario y resultados
│       │   ├── home/               # Pantalla principal
│       │   ├── medico/             # Panel médico
│       │   ├── onboarding/         # Pantalla de bienvenida
│       │   └── perfil/             # Perfil de usuario
│       ├── viewmodels/             # ViewModels (lógica de presentación)
│       │   ├── auth_viewmodel.dart
│       │   ├── evaluacion_viewmodel.dart
│       │   ├── medico_viewmodel.dart
│       │   └── theme_viewmodel.dart
│       └── widgets/                # Componentes UI reutilizables
│           ├── animated_bar_chart.dart
│           ├── animated_counter.dart
│           ├── animated_donut_chart.dart
│           ├── custom_button.dart
│           ├── custom_textfield.dart
│           └── risk_indicator.dart
│
└── pubspec.yaml                    # Gestión de paquetes y dependencias
```

---

## Principios Aplicados

### Clean Architecture

- **Independencia de frameworks**: La lógica de negocio no depende de Flutter ni otras librerías externas
- **Testabilidad**: Las entidades y usecases pueden probarse fácilmente sin dependencias externas
- **Independencia de UI**: La interfaz puede cambiar sin afectar la lógica de negocio
- **Independencia de datos**: El origen de datos (API, base de datos local) puede cambiar sin afectar el negocio

### MVVM (Model-View-ViewModel)

- **Model**: Entidades de dominio y DTOs
- **View**: Páginas y widgets declarativos
- **ViewModel**: Lógica de presentación con `ChangeNotifier` para estado reactivo

### Inyección de Dependencias

- Implementada con `Provider` en `main.dart`
- Las dependencias se inyectan desde las capas externas hacia las internas
- Los ViewModels reciben UseCases, nunca acceden directamente a la API

### Responsabilidad Única

- Cada UseCase tiene una sola responsabilidad
- Cada DataSource maneja un solo tipo de operaciones
- Cada ViewModel gestiona un solo aspecto de la UI

---

## Guía de Configuración Local y Arranque (Windows)

### 1. Requisitos Previos

- Tener instalado el SDK de **Flutter** (versión estable).
- Tener instalado **Android Studio** con las herramientas de desarrollo básicas.

### 2. Configurar Variables de Entorno en Windows

Para que las herramientas de Flutter reconozcan tu celular virtual y compilador:

1. En tu buscador de Windows, abre **Variables de entorno del sistema**.
2. Agrega una variable en **Variables de usuario**:
   - **Nombre:** `ANDROID_HOME`
   - **Valor:** `C:\Android` _(Asegúrate de que este sea el path real de tu SDK instalado)_
3. Selecciona la variable **Path** en variables de usuario y agrégale estas tres rutas nuevas:
   - `C:\Android\platform-tools`
   - `C:\Android\emulator`
   - `C:\Android\cmdline-tools\latest\bin`
4. Cierra y vuelve a abrir tu editor VSCode para que aplique los cambios.

### 3. Descargar Paquetes

En tu terminal Git Bash, ubícate en la carpeta `frontend/` y ejecuta:

```bash
flutter pub get
```

### 4. Lanzar el Celular Virtual desde VSCode

1. Presiona `Ctrl + Shift + P` en VSCode.
2. Escribe **`Flutter: Launch Emulator`** y presiona `Enter`.
3. Selecciona tu emulador creado (por ejemplo, `Pixel_5_API_34`). El celular virtual se encenderá en tu pantalla.

### 5. Ejecutar la Aplicación

Una vez que el celular virtual esté completamente encendido en tu pantalla, ejecuta:

```bash
flutter run
```

_La terminal compilará la aplicación y la abrirá de forma interactiva en tu celular de pantalla._

---

## Funcionalidades Clave del Frontend

- **Cuestionario paso a paso:** Un cuestionario interactivo de 15 pantallas individuales con transiciones fluidas y controles adaptados al tipo de respuesta (chips, escalas de botones circulares 1-10 y sliders).
- **Control de Estado Vacío:** Los usuarios nuevos son recibidos por una interfaz limpia con una tarjeta de bienvenida, ocultando las gráficas sin mediciones.
- **Gráfica de Tendencia Activa:** Dibuja una gráfica lineal dinámicamente usando las probabilidades exactas obtenidas en el historial de evaluaciones.

---

## Stack Tecnológico

- **Framework**: Flutter 3.x
- **Lenguaje**: Dart 3.x
- **Gestión de Estado**: Provider + ChangeNotifier
- **Arquitectura**: Clean Architecture + MVVM
- **HTTP**: http package
- **Almacenamiento Local**: shared_preferences
- **Gráficos**: fl_chart

---

## Notas para Desarrolladores

### Agregar una nueva funcionalidad

1. **Domain**: Crear entidad (si es necesaria) en `domain/entities/`
2. **Domain**: Crear interfaz de repositorio en `domain/repositories/`
3. **Domain**: Crear UseCase en `domain/usecases/`
4. **Data**: Crear Model/DTO en `data/models/`
5. **Data**: Crear DataSource en `data/datasources/remote/`
6. **Data**: Implementar repositorio en `data/repositories/`
7. **Presentation**: Crear/actualizar ViewModel en `presentation/viewmodels/`
8. **Presentation**: Crear/actualizar Page en `presentation/pages/`

### Reglas de dependencias

- ✅ **Presentation** puede depender de **Domain** (UseCases)
- ✅ **Data** puede depender de **Domain** (Repository interfaces)
- ❌ **Domain** NO puede depender de **Data** ni **Presentation**
- ❌ **Presentation** NO puede depender de **Data** directamente
- ❌ Los ViewModels NO deben hacer llamadas HTTP directamente
