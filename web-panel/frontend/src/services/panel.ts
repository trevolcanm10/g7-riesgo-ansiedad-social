/**
 * Servicios del panel institucional.
 *
 * Cada funcion valida la forma de la respuesta antes de devolverla: una
 * respuesta que no cumple el contrato se rechaza en lugar de propagarse.
 */
import { config } from '../config';
import { descargar, get, post } from './api';
import type {
  Atencion,
  Estadisticas,
  Indicadores,
  Modalidad,
  PaginaAtenciones,
  TipoAtencion,
  UsuarioInstitucional,
} from '../types';
import { esUsuarioInstitucional } from '../validation';

/** Datos de una atención a registrar. */
export interface NuevaAtencion {
  estudiante_codigo: string;
  modalidad: Modalidad;
  tipo: TipoAtencion;
  fecha_atencion?: string;
  indicadores?: Indicadores;
  notas?: string;
  seguimiento_requerido?: boolean;
}

/**
 * Inicia sesión contra el microservicio de usuarios y devuelve el token.
 */
export async function iniciarSesion(
  email: string,
  password: string,
): Promise<{ token: string; usuario: UsuarioInstitucional }> {
  const respuesta = await post<Record<string, unknown>>(`${config.usersPath}/login`, {
    email: email.trim(),
    password,
  });

  const token = respuesta?.accessToken;
  if (typeof token !== 'string' || !token) {
    throw new Error('El servicio no devolvió un token de acceso válido.');
  }

  const usuario = respuesta?.user;
  if (!esUsuarioInstitucional(usuario)) {
    throw new Error('Tu cuenta no tiene acceso al panel institucional.');
  }

  return { token, usuario };
}

/**
 * Registra una atención.
 */
export async function registrarAtencion(
  datos: NuevaAtencion,
  token: string,
): Promise<Atencion> {
  const respuesta = await post<Record<string, unknown>>(
    `${config.panelPath}/atencion`,
    datos,
    token,
  );

  if (!respuesta || typeof respuesta.id !== 'number') {
    throw new Error('No se pudo confirmar el registro: respuesta inválida del servicio.');
  }

  return respuesta as unknown as Atencion;
}

/**
 * Obtiene las estadísticas anonimizadas del panel.
 */
export async function obtenerEstadisticas(
  periodo: string | null,
  token: string,
): Promise<Estadisticas> {
  const consulta = periodo ? `?periodo=${encodeURIComponent(periodo)}` : '';
  const respuesta = await get<Record<string, unknown>>(
    `${config.panelPath}/estadisticas${consulta}`,
    token,
  );

  if (!respuesta || typeof respuesta.total_atenciones !== 'number') {
    throw new Error('El servicio devolvió estadísticas inválidas.');
  }

  return respuesta as unknown as Estadisticas;
}

/**
 * Obtiene una página de atenciones.
 */
export async function obtenerAtenciones(
  filtros: { limite?: number; offset?: number; periodo?: string | null } = {},
  token: string,
): Promise<PaginaAtenciones> {
  const parametros = new URLSearchParams();
  if (filtros.limite !== undefined) parametros.set('limite', String(filtros.limite));
  if (filtros.offset !== undefined) parametros.set('offset', String(filtros.offset));
  if (filtros.periodo) parametros.set('periodo', filtros.periodo);

  const consulta = parametros.toString() ? `?${parametros.toString()}` : '';
  const respuesta = await get<Record<string, unknown>>(
    `${config.panelPath}/atenciones${consulta}`,
    token,
  );

  if (!respuesta || !Array.isArray(respuesta.atenciones)) {
    throw new Error('El servicio devolvió un listado inválido.');
  }

  return respuesta as unknown as PaginaAtenciones;
}

/**
 * Descarga el informe CSV del periodo.
 */
export async function descargarInforme(
  periodo: string | null,
  token: string,
): Promise<{ nombre: string; blob: Blob }> {
  const consulta = periodo ? `?periodo=${encodeURIComponent(periodo)}` : '';
  return descargar(`${config.panelPath}/informe${consulta}`, token);
}
