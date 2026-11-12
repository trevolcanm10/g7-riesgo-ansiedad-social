/**
 * Cliente HTTP del panel institucional.
 *
 * Todas las peticiones pasan por Azure API Management: el panel nunca llama
 * directamente a un microservicio. El host se valida antes de enviar nada
 * (debe ser HTTPS y *.azure-api.net) y la clave de suscripcion solo se
 * adjunta a ese host.
 */
import { config } from '../config';

/** Milisegundos de espera maxima antes de abandonar una peticion. */
export const TIMEOUT_MS = 25000;

/**
 * Traduce un codigo HTTP a un mensaje comprensible para el personal.
 */
export function httpError(status: number, retry?: string | null): string {
  if (status === 400) return 'Revisa los datos enviados. El servicio rechazó la solicitud.';
  if (status === 401) return 'Tu sesión expiró o el acceso fue rechazado. Inicia sesión nuevamente.';
  if (status === 403) return 'Tu rol no tiene permiso para usar el panel institucional.';
  if (status === 404) return 'No se encontró la ruta del servicio. Contacta al responsable de la plataforma.';
  if (status === 409) return 'Ya existe un registro con esos datos.';
  if (status === 429) {
    return `Se alcanzó el límite de solicitudes. Inténtalo más tarde.${
      retry && /^\d+$/.test(retry) ? ` Espera ${retry} segundos.` : ''
    }`;
  }
  if (status >= 500) return 'El servicio no está disponible en este momento. Inténtalo más tarde.';
  return 'No se pudo completar la solicitud. Inténtalo de nuevo.';
}

/** Error de API con el mensaje ya traducido al español. */
export class ApiError extends Error {
  readonly status: number;

  constructor(mensaje: string, status: number) {
    super(mensaje);
    this.name = 'ApiError';
    this.status = status;
  }
}

/**
 * Valida la configuracion del gateway antes de enviar una peticion.
 */
function validarConfiguracion(): URL {
  if (!config.key) {
    throw new ApiError(
      'El servicio aún no está configurado. Solicita al responsable que configure el acceso para el panel.',
      0,
    );
  }

  let base: URL;
  try {
    base = new URL(config.baseUrl);
  } catch {
    throw new ApiError('La configuración de Azure API Management no es válida.', 0);
  }

  if (base.protocol !== 'https:' || !base.hostname.endsWith('.azure-api.net')) {
    throw new ApiError('La configuración de Azure API Management no es válida.', 0);
  }

  return base;
}

/**
 * Construye las cabeceras comunes de una peticion.
 */
function cabeceras(conToken?: string | null): Record<string, string> {
  const cabeceras: Record<string, string> = {
    'Content-Type': 'application/json',
    'Ocp-Apim-Subscription-Key': config.key,
  };

  if (conToken) cabeceras.Authorization = `Bearer ${conToken}`;

  return cabeceras;
}

/**
 * Ejecuta una peticion contra el gateway y devuelve el cuerpo parseado.
 */
async function peticion<T>(
  metodo: 'GET' | 'POST',
  ruta: string,
  opciones: { cuerpo?: unknown; token?: string | null } = {},
): Promise<T> {
  validarConfiguracion();

  if (!ruta.startsWith('/') || ruta.startsWith('//')) {
    throw new ApiError('La ruta del servicio no es válida.', 0);
  }

  const controlador = new AbortController();
  const temporizador = setTimeout(() => controlador.abort(), TIMEOUT_MS);

  try {
    const respuesta = await fetch(`${config.baseUrl}${ruta}`, {
      method: metodo,
      headers: cabeceras(opciones.token),
      body: opciones.cuerpo === undefined ? undefined : JSON.stringify(opciones.cuerpo),
      signal: controlador.signal,
    });

    if (!respuesta.ok) {
      throw new ApiError(
        httpError(respuesta.status, respuesta.headers.get('Retry-After')),
        respuesta.status,
      );
    }

    if (respuesta.status === 204) return undefined as T;

    try {
      return (await respuesta.json()) as T;
    } catch {
      throw new ApiError('El servicio devolvió una respuesta inválida.', respuesta.status);
    }
  } catch (error) {
    if (error instanceof ApiError) throw error;
    if (error instanceof TypeError) {
      throw new ApiError(
        'No se pudo conectar con el servicio. Revisa tu conexión o consulta al responsable de la plataforma.',
        0,
      );
    }
    if (error instanceof Error && error.name === 'AbortError') {
      throw new ApiError('El servicio tardó demasiado en responder. Inténtalo de nuevo.', 0);
    }
    throw error;
  } finally {
    clearTimeout(temporizador);
  }
}

/** Ejecuta una peticion GET. */
export function get<T>(ruta: string, token?: string | null): Promise<T> {
  return peticion<T>('GET', ruta, { token });
}

/** Ejecuta una peticion POST. */
export function post<T>(ruta: string, cuerpo: unknown, token?: string | null): Promise<T> {
  return peticion<T>('POST', ruta, { cuerpo, token });
}

/**
 * Descarga un archivo binario del servicio.
 */
export async function descargar(ruta: string, token: string): Promise<{ nombre: string; blob: Blob }> {
  validarConfiguracion();

  const controlador = new AbortController();
  const temporizador = setTimeout(() => controlador.abort(), TIMEOUT_MS);

  try {
    const respuesta = await fetch(`${config.baseUrl}${ruta}`, {
      method: 'GET',
      headers: cabeceras(token),
      signal: controlador.signal,
    });

    if (!respuesta.ok) {
      throw new ApiError(
        httpError(respuesta.status, respuesta.headers.get('Retry-After')),
        respuesta.status,
      );
    }

    const disposicion = respuesta.headers.get('Content-Disposition') ?? '';
    const coincidencia = /filename="?([^";]+)"?/.exec(disposicion);
    const nombre = coincidencia ? coincidencia[1] : 'informe.csv';

    return { nombre, blob: await respuesta.blob() };
  } catch (error) {
    if (error instanceof ApiError) throw error;
    if (error instanceof TypeError) {
      throw new ApiError('No se pudo conectar con el servicio.', 0);
    }
    if (error instanceof Error && error.name === 'AbortError') {
      throw new ApiError('El servicio tardó demasiado en responder. Inténtalo de nuevo.', 0);
    }
    throw error;
  } finally {
    clearTimeout(temporizador);
  }
}
