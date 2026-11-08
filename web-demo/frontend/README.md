# Bienestar Estudiantil

Frontend React + TypeScript + Vite + Tailwind CSS + React Router + Lucide. Las páginas están en `src/pages`, los componentes en `src/components`, el cliente HTTP en `src/services/api.ts`, los contratos en `src/types.ts` y los rangos/validadores en `src/validation.ts`.

## Ejecutar (PowerShell)

```powershell
cd web-demo/frontend
npm.cmd install
Copy-Item .env.example .env
# Edita .env localmente y completa VITE_APIM_SUBSCRIPTION_KEY.
npm.cmd run dev
```

Abre la URL que indica Vite. Verificación: `npm.cmd run build` y `npm.cmd test`. No se requieren cambios en los microservicios.

## Rutas y servicios

| Vista | Ruta |
| --- | --- |
| Inicio | `/` |
| Registro | `/registro` |
| Evaluación | `/evaluacion` |
| Resultado | `/resultado` |

El cliente envía JSON y `Ocp-Apim-Subscription-Key` exclusivamente a un gateway HTTPS `*.azure-api.net`. Rutas iniciales: POST `/users/users` y POST `/prediction/predict`. Los sufijos son configurables con `VITE_APIM_USERS_PATH` y `VITE_APIM_PREDICTION_PATH`. No hay llamadas directas a los microservicios.

El código local confirma `/users` y `/predict`; no contiene la configuración de los sufijos públicos de APIM. El 9 de octubre de 2026 las rutas públicas GET `/users/health` y `/prediction/health` respondieron 401 por ausencia de clave y reconocieron sus respectivos ámbitos APIM. Esto no verifica los backends, CORS ni los POST. Confirmar los sufijos en Azure y probar registro/predicción con una suscripción válida antes de exponer.

## Datos y límites

No hay login, persistencia de contraseñas, historial ni resultados simulados. La confirmación de contraseña nunca se envía. La evaluación mantiene respuestas entre sus tres pasos en memoria del componente; salir de ella borra las respuestas. El resultado vive en estado React y desaparece al recargar. No se usa localStorage/sessionStorage. Solo se muestra un resultado con nivel BAJO/MEDIO/ALTO y probabilidad numérica 0–1 válidos.

Los 15 rangos y tipos numéricos se verificaron contra `services/prediction-ml/src/presentation/validation.py`; el backend permite decimales. Los campos PHQ-9/GAD-7 solicitan totales conocidos: no administran ni puntúan las escalas. El backend no define anclajes interpretativos para otros indicadores, por lo que no se inventan equivalencias ni preguntas puntuables. Para participantes sin totales clínicos conocidos o sin GPA en escala 0–5, la evaluación no puede completarse fielmente; usar valores de prueba explícitos en la exposición.

La clave Vite es visible en el navegador: solo para demo con una suscripción limitada y revocable. `.env` está ignorado por el repositorio; `.env.example` no incluye secretos. Producción requiere un intermediario backend o autenticación/autorización apropiadas. Reinicia Vite al modificar el entorno. Un despliegue estático debe redirigir las rutas de React Router a `index.html`.

## Fotografías

Fotografías de Unsplash descargadas en `public/images`, bajo https://unsplash.com/license (uso gratuito comercial y no comercial):
- Estudiantes: https://images.unsplash.com/photo-1523240795612-9a054b0db644
- Estudio: https://images.unsplash.com/photo-1434030216411-0b793f4b4173
- Cuaderno: https://images.unsplash.com/photo-1455390582262-044cdead277a

## Comprobación manual remota

Con `.env` configurado: verificar en navegador CORS/preflight y encabezado de suscripción; registro 201; duplicado 409; predicción válida; errores 401/403/429/5xx; comprobar que ningún fallo navega a resultados. Usar datos de prueba. No asumir éxito remoto a partir de compilación o pruebas locales.

## Verificación realizada

- Instalación completada y auditoría npm sin vulnerabilidades tras actualizar Vitest.
- `npm.cmd run build`: TypeScript y bundle de producción correctos.
- `npm.cmd test`: 10 pruebas aprobadas (rangos, campos requeridos, confirmación, respuestas válidas/invalidas, rutas APIM, encabezado, payload, errores HTTP y conexión). Las llamadas POST se prueban con fetch controlado, no con Azure real.
- Servidor Vite iniciado en `http://localhost:5173/`. El script `dev` ya no fija `--host 127.0.0.1`: la política CORS de APIM solo admite el origen `http://localhost:5173` y el origen `http://127.0.0.1:5173` quedaba sin cabeceras `Access-Control-Allow-*` en el preflight.
- Diagnóstico CORS del 9/10 de octubre de 2026: los preflights `OPTIONS` de `/users/users` y `/prediction/predict` responden `Access-Control-Allow-Origin: http://localhost:5173`, `Allow-Methods: POST` y `Allow-Headers: content-type,ocp-apim-subscription-key`; con otro origen responden 200 sin cabeceras CORS. Los health con clave responden 200 en ambos ámbitos.
- La herramienta de navegador falló al iniciar en dos intentos. Quedan pendientes revisión visual, navegación interactiva, foco/accesibilidad y vista móvil en navegador real.
- No se modificaron servicios, Docker, Azure ni modelos; no se hicieron commits ni push.
