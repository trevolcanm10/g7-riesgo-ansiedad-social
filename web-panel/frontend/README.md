# Panel Institucional (React)

Aplicacion web del **Panel Institucional y Analitica** (Modulo 4) de la
plataforma de prevencion del riesgo de ansiedad social. Es la aplicacion que
usa el personal institucional: registra atenciones, consulta indicadores
agregados y descarga informes.

Esta es la **estructura base del frontend web para el equipo**: el contenedor,
la barra lateral, el enrutado y la proteccion de sesion ya estan listos para
que nuevos modulos conecten sus pantallas.

> **Guia completa de instalacion, ejecucion, verificacion y publicacion:**
> [`README_MODULO_4.md`](../../README_MODULO_4.md) en la raiz del repositorio.
> Este documento describe el frontend en detalle.

---

## Stack

| Elemento | Tecnologia |
|---|---|
| Lenguaje | TypeScript 5.7 (`strict`) |
| Framework | React 19 |
| Bundler | Vite 6 |
| Estilos | Tailwind CSS 4 (`@theme` con tokens) + iconos `lucide-react` |
| Enrutado | react-router-dom 7 |
| Pruebas | Vitest 5 |

No hay libreria de graficos: los indicadores se dibujan con SVG y CSS a mano,
igual que en la app movil de Flutter.

---

## Ejecutar

```powershell
cd web-panel/frontend
npm.cmd install
Copy-Item .env.example .env
# Completa VITE_APIM_SUBSCRIPTION_KEY con la clave entregada por el equipo.
npm.cmd run dev
```

El servidor de Vite escucha en `http://localhost:5174` (configurable en
`vite.config.ts`). Ese origen debe estar permitido en la politica CORS de
Azure API Management y en `CORS_ALLOW_ORIGIN` del microservicio.

Verificacion:

```powershell
npm.cmd run typecheck   # tsc --noEmit
npm.cmd test            # vitest run
npm.cmd run build       # tsc -b && vite build
```

---

## Rutas

| Ruta | Pantalla | Estado |
|---|---|---|
| `/login` | Inicio de sesion | Activa |
| `/` | Dashboard analitico | Activa |
| `/atencion` | Formulario de registro unico | Activa |
| `/informes` | Generacion de informes | Activa |
| `/orientacion` | Bandeja de orientacion | **Preparada** |
| `/citas` | Agenda de citas | **Preparada** |
| `/agenda` | Seguimiento de compromisos | **Preparada** |

Las tres rutas preparadas existen en el enrutado, en la barra lateral y bajo la
proteccion de sesion. Cuando su microservicio este listo, se sustituye
`src/pages/Preparada.tsx` por la pantalla real **sin tocar el enrutado ni la
navegacion**.

---

## Estructura

```text
src/
├── main.tsx                    # Enrutado y punto de entrada
├── config.ts                   # Configuracion leida del entorno de Vite
├── types.ts                    # Tipos del dominio y catalogos
├── validation.ts               # Validadores puros (patron de web-demo)
├── styles.css                  # Tokens @theme y componentes base
├── app/
│   ├── AppShell.tsx            # Contenedor con barra lateral y encabezado
│   ├── AuthContext.tsx         # Sesion institucional
│   ├── RutaProtegida.tsx       # Guard de rutas privadas
│   └── navigation.ts           # Estructura de la navegacion lateral
├── components/
│   ├── Avisos.tsx              # Aviso de IA y aviso de privacidad k=5
│   └── Graficos.tsx            # Tarjetas, barras y anillo en SVG
├── pages/
│   ├── Login.tsx
│   ├── Dashboard.tsx
│   ├── RegistroAtencion.tsx
│   ├── Informes.tsx
│   └── Preparada.tsx
└── services/
    ├── api.ts                   # Cliente HTTP hacia APIM
    └── panel.ts                 # Operaciones del panel
```

---

## Autenticacion

El inicio de sesion llama a `POST {APIM}/users/users/login`, el mismo
microservicio de usuarios que usa la app movil. Devuelve un JWT con rol.

El token se guarda **en memoria y en `sessionStorage`** (se pierde al cerrar
la pestana). La contrasena nunca se guarda.

Solo acceden al panel los roles `PERSONAL_UNAYOE` y `ADMINISTRADOR`. Si la
cuenta tiene otro rol, `src/services/panel.ts` rechaza la respuesta y el
usuario ve un mensaje explicito en vez de una pantalla vacia.

Cada peticion al panel lleva dos cabeceras:

- `Authorization: Bearer <jwt>`: lo exige el microservicio, que verifica la
  firma con el secreto compartido y el rol.
- `Ocp-Apim-Subscription-Key`: la clave de la suscripcion de APIM.

---

## Privacidad k=5 en el cliente

El filtrado de los grupos con menos de cinco estudiantes lo aplica **el
servidor**, en su capa de dominio. El cliente no recalcula ni reinterpreta los
conteos: los muestra tal cual llegan.

Lo que si hace el cliente es **explicitar** el filtrado, para que el personal
no interprete la ausencia de un grupo como un cero. `components/Avisos.tsx`
muestra un aviso cuando `grupos_omitidos_por_privacidad` es mayor que cero:
indica cuantos grupos se ocultaron, nunca su contenido.

---

## IA responsable

`components/Avisos.tsx` exporta `AvisoIA`, que se muestra en toda vista con
resultados del modelo de agrupamiento, y reproduce la nota `nota_ia` que
envia el servicio. El texto es explicito: son estimaciones orientativas, no
diagnosticos clinicos, y provienen de un dataset sintetico.

---

## Configuracion

| Variable | Descripcion |
|---|---|
| `VITE_APIM_BASE_URL` | Base del gateway. Debe ser HTTPS y terminar en `.azure-api.net` |
| `VITE_APIM_SUBSCRIPTION_KEY` | Clave de suscripcion de APIM |
| `VITE_APIM_PANEL_PATH` | Sufijo del microservicio de panel dentro de APIM |
| `VITE_APIM_USERS_PATH` | Sufijo del microservicio de usuarios |

El cliente **rechaza** cualquier base que no sea HTTPS de `*.azure-api.net`, y
no hace la peticion si falta la clave. El host se valida antes de enviar
nada.

> La clave de APIM queda embebida en el bundle del navegador. Es aceptable para
> la demostracion institucional con una suscripcion limitada y revocable. En
> produccion requiere un intermediario backend o autenticacion apropiada.

---

## Pruebas

| Archivo | Verifica |
|---|---|
| `src/validation.test.ts` | Validadores de credenciales y de la atencion, rangos de los siete indicadores, deteccion de usuario institucional, formato de periodo y listado de meses |
| `src/services/api.test.ts` | Cabeceras enviadas (clave y token), rechazo de host no permitido o sin clave sin llamar a `fetch`, traduccion de 401/403, rechazo de respuestas con forma invalida y rechazo del rol `ESTUDIANTE` |

---

## Contrato con el backend

El panel consume el microservicio `services/panel-service`, cuya especificacion
esta en `openapi/panel.yaml`.

| Llamada | Servicio |
|---|---|
| `POST /users/users/login` | Servicio de usuarios (emisor del token) |
| `POST /panel/api/panel/atencion` | Servicio del panel |
| `GET /panel/api/panel/estadisticas` | Servicio del panel |
| `GET /panel/api/panel/informe` | Servicio del panel |
| `GET /panel/api/panel/atenciones` | Servicio del panel |

El prefijo `/panel` corresponde al nombre con el que el microservicio se
publica en Azure API Management; dentro del servicio las rutas ya empiezan por
`/api/panel`.
