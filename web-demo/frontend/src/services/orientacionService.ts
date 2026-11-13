import { config } from '../config';
import type { SolicitudOrientacion, StaffRole, StaffSession } from '../types/orientacion';

const STAFF_ROLES: ReadonlySet<string> = new Set<StaffRole>([
  'PERSONAL_UNAYOE',
  'ADMINISTRADOR',
]);

const DEFAULT_APIM_BASE_URL = 'https://apim-g7-riesgo-ansiedad.azure-api.net';

const getApimBaseUrl = (): string =>
  (import.meta.env.VITE_APIM_BASE_URL || DEFAULT_APIM_BASE_URL).replace(/\/$/, '');

const getOrientacionPath = (): string =>
  (import.meta.env.VITE_APIM_ORIENTACION_PATH || '/o/api/v1/orientacion/solicitudes').replace(/\/$/, '');

const getLoginPath = (): string => {
  if (import.meta.env.VITE_APIM_LOGIN_PATH) {
    return import.meta.env.VITE_APIM_LOGIN_PATH;
  }
  const usersPath = (import.meta.env.VITE_APIM_USERS_PATH || '/u/users').replace(/\/$/, '');
  return `${usersPath}/login`;
};

function assertGatewayReady(baseUrl: string, path: string): void {
  if (!config.key) {
    throw new Error(
      'El acceso al gateway APIM no está configurado. Solicita al responsable habilitar la clave.'
    );
  }
  const base = new URL(baseUrl);
  const isLocalDev =
    base.hostname === 'localhost' || base.hostname === '127.0.0.1';
  const isValidApim =
    base.protocol === 'https:' && base.hostname.endsWith('.azure-api.net');
  if ((!isValidApim && !isLocalDev) || !path.startsWith('/') || path.startsWith('//')) {
    throw new Error('La configuración de Azure API Management no es válida.');
  }
}

function resolveOrientacionTarget(): {
  baseUrl: string;
  path: string;
  includeApimKey: boolean;
} {
  const directBase = import.meta.env.VITE_ORIENTACION_BASE_URL?.trim();
  if (directBase) {
    const baseUrl = directBase.replace(/\/$/, '');
    const path = (
      import.meta.env.VITE_ORIENTACION_PATH || '/api/v1/orientacion/solicitudes'
    ).replace(/\/$/, '');
    let parsed: URL;
    try {
      parsed = new URL(baseUrl);
    } catch {
      throw new Error(
        'La configuración de VITE_ORIENTACION_BASE_URL no es una URL válida.'
      );
    }
    const isLocalHttp =
      parsed.protocol === 'http:' &&
      (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1');
    const isHttps = parsed.protocol === 'https:';
    if ((!isHttps && !isLocalHttp) || !path.startsWith('/') || path.startsWith('//')) {
      throw new Error(
        'La configuración de VITE_ORIENTACION_BASE_URL o su ruta no es válida.'
      );
    }
    return {
      baseUrl,
      path,
      includeApimKey: parsed.hostname.endsWith('.azure-api.net'),
    };
  }

  const baseUrl = getApimBaseUrl();
  const path = getOrientacionPath();
  assertGatewayReady(baseUrl, path);
  return { baseUrl, path, includeApimKey: true };
}

function decodeBase64Url(segment: string): string {
  const padded = segment.replace(/-/g, '+').replace(/_/g, '/');
  const mod = padded.length % 4;
  const normalized = mod === 0 ? padded : padded + '='.repeat(4 - mod);
  return atob(normalized);
}

export function parseJwtStaffClaims(token: string): { userId: number; role: StaffRole } {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Token JWT inválido.');
  }
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(decodeBase64Url(parts[1])) as Record<string, unknown>;
  } catch {
    throw new Error('No se pudieron leer los datos de sesión.');
  }

  const userId = payload.userId;
  const role = payload.role;
  const exp = payload.exp;

  if (typeof exp === 'number' && exp * 1000 <= Date.now()) {
    throw new Error('Tu sesión ha expirado. Inicia sesión nuevamente.');
  }
  if (typeof userId !== 'number' || !Number.isInteger(userId) || userId <= 0) {
    throw new Error('El token no contiene un identificador de usuario válido.');
  }
  if (typeof role !== 'string' || !STAFF_ROLES.has(role)) {
    throw new Error(
      'Acceso restringido únicamente a personal de UNAYOE o administradores.'
    );
  }
  return { userId, role: role as StaffRole };
}

function mapHttpError(status: number, fallback: string): string {
  if (status === 400) return 'Los datos enviados no son válidos.';
  if (status === 401) return 'Tu sesión expiró o las credenciales son incorrectas.';
  if (status === 403) return 'No tienes permisos de personal UNAYOE para acceder.';
  if (status === 404) return 'No se encontró la solicitud o ruta indicada.';
  if (status === 409) return 'La solicitud ya fue atendida previamente.';
  if (status === 429) return 'Demasiadas peticiones. Intenta nuevamente en un momento.';
  if (status >= 500) return 'El servicio no está disponible temporalmente.';
  return fallback;
}

export async function loginPersonalUnayoe(
  email: string,
  password: string
): Promise<StaffSession> {
  const baseUrl = getApimBaseUrl();
  const path = getLoginPath();
  assertGatewayReady(baseUrl, path);

  const response = await fetch(`${baseUrl}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Ocp-Apim-Subscription-Key': config.key,
    },
    body: JSON.stringify({ email: email.trim(), password }),
  });

  if (!response.ok) {
    throw new Error(mapHttpError(response.status, 'Error al iniciar sesión.'));
  }

  const data = (await response.json()) as {
    accessToken?: unknown;
    token?: unknown;
  };
  const jwt =
    typeof data.accessToken === 'string' && data.accessToken
      ? data.accessToken
      : typeof data.token === 'string' && data.token
        ? data.token
        : '';
  if (!jwt) {
    throw new Error('El servidor de autenticación no devolvió un token válido.');
  }

  const claims = parseJwtStaffClaims(jwt);
  return {
    token: jwt,
    userId: claims.userId,
    role: claims.role,
  };
}

export async function obtenerSolicitudes(
  token: string,
  estado?: string,
  prioridad?: string
): Promise<SolicitudOrientacion[]> {
  if (!token) {
    throw new Error('Debes iniciar sesión como personal UNAYOE.');
  }
  const { baseUrl, path: orientacionPath, includeApimKey } = resolveOrientacionTarget();

  const params = new URLSearchParams();
  if (estado) params.append('estado', estado);
  if (prioridad) params.append('prioridad', prioridad);

  const query = params.toString() ? `?${params.toString()}` : '';
  const url = `${baseUrl}${orientacionPath}${query}`;

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };
  if (includeApimKey && config.key) {
    headers['Ocp-Apim-Subscription-Key'] = config.key;
  }

  const response = await fetch(url, {
    method: 'GET',
    headers,
  });

  if (!response.ok) {
    throw new Error(
      mapHttpError(response.status, 'Error al obtener las solicitudes.')
    );
  }
  return response.json();
}

export async function atenderSolicitud(
  token: string,
  id: number,
  data: {
    respuesta_escrita: string;
    tema_confirmado?: string;
    prioridad_confirmada?: string;
  }
): Promise<SolicitudOrientacion> {
  if (!token) {
    throw new Error('Debes iniciar sesión como personal UNAYOE.');
  }
  const { baseUrl, path: orientacionPath, includeApimKey } = resolveOrientacionTarget();

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };
  if (includeApimKey && config.key) {
    headers['Ocp-Apim-Subscription-Key'] = config.key;
  }

  const response = await fetch(`${baseUrl}${orientacionPath}/${id}/atender`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    throw new Error(
      mapHttpError(response.status, 'Error al atender la solicitud.')
    );
  }
  return response.json();
}
