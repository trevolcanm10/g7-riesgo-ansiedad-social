/**
 * Configuracion del panel, leida del entorno de Vite.
 *
 * La clave de suscripcion de APIM queda embebida en el bundle del navegador.
 * Es aceptable para la demostracion institucional con una suscripcion
 * limitada y revocable; en produccion requiere un intermediario backend.
 */
export const config = {
  baseUrl: (
    import.meta.env.VITE_APIM_BASE_URL || 'https://apim-g7-riesgo-ansiedad.azure-api.net'
  ).replace(/\/$/, ''),
  key: import.meta.env.VITE_APIM_SUBSCRIPTION_KEY || '',
  panelPath: import.meta.env.VITE_APIM_PANEL_PATH || '/panel/api/panel',
  // Sufijo del microservicio de usuarios dentro de APIM. La ruta confirmada
  // por el equipo es /u/users (misma convencion que usa la app movil en
  // frontend/APIM.md).
  usersPath: import.meta.env.VITE_APIM_USERS_PATH || '/u/users',
};
