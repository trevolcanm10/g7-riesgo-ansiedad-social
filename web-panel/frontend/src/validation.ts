/**
 * Validadores puros del panel.
 *
 * Siguen el patron de `web-demo`: funciones puras que devuelven un
 * `Record<string, string>` con los errores por campo.
 */
import {
  CLAVES_INDICADORES,
  MODALIDADES,
  ROLES_INSTITUCIONALES,
  TIPOS_ATENCION,
  type DefinicionIndicador,
  type Indicadores,
  type RiesgoMotivo,
  type UsuarioSesion,
} from './types';

/** Definicion de los siete indicadores con sus rangos y etiquetas. */
export const INDICADORES: DefinicionIndicador[] = [
  {
    key: 'phq9',
    label: 'Puntuación total PHQ-9',
    min: 0,
    max: 27,
    hint: 'Total de una aplicación previa del PHQ-9 (0–27).',
  },
  {
    key: 'gad7',
    label: 'Puntuación total GAD-7',
    min: 0,
    max: 21,
    hint: 'Total de una aplicación previa del GAD-7 (0–21).',
  },
  {
    key: 'online_stress',
    label: 'Estrés en línea',
    min: 1,
    max: 10,
    hint: 'Valor del indicador: de 1 a 10.',
  },
  {
    key: 'financial_stress',
    label: 'Estrés financiero',
    min: 1,
    max: 10,
    hint: 'Valor del indicador: de 1 a 10.',
  },
  {
    key: 'exercise_freq',
    label: 'Frecuencia de ejercicio',
    min: 0,
    max: 7,
    hint: 'Frecuencia semanal, de 0 a 7.',
  },
  {
    key: 'social_activity',
    label: 'Actividad social',
    min: 0,
    max: 10,
    hint: 'Valor del indicador: de 0 a 10.',
  },
  {
    key: 'sleep_hours',
    label: 'Horas de sueño',
    min: 3,
    max: 10,
    hint: 'Horas por noche, entre 3 y 10.',
  },
];

/** Etiquetas legibles para las modalidades. */
export const ETIQUETAS_MODALIDAD: Record<string, string> = {
  presencial: 'Presencial',
  virtual: 'Virtual',
  telefonica: 'Telefónica',
  correo: 'Correo',
};

/** Etiquetas legibles para los tipos de atención. */
export const ETIQUETAS_TIPO: Record<string, string> = {
  orientacion: 'Orientación',
  seguimiento: 'Seguimiento',
  derivacion: 'Derivación',
  evaluacion: 'Evaluación',
  emergencia: 'Emergencia',
};

/**
 * Valida las credenciales del inicio de sesión.
 */
export function validarCredenciales(email: string, password: string): Record<string, string> {
  const errores: Record<string, string> = {};

  if (!email.trim()) errores.email = 'Introduce tu correo institucional.';
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim()))
    errores.email = 'Introduce un correo válido.';

  if (!password) errores.password = 'Introduce tu contraseña.';

  return errores;
}

/**
 * Valida el formulario de registro de una atención.
 */
export function validarAtencion(datos: {
  estudiante_codigo: string;
  modalidad: string;
  tipo: string;
  fecha_atencion: string;
  notas: string;
  indicadores: Indicadores;
}): Record<string, string> {
  const errores: Record<string, string> = {};

  if (!datos.estudiante_codigo.trim()) {
    errores.estudiante_codigo = 'Introduce el código del estudiante.';
  }

  if (!MODALIDADES.includes(datos.modalidad as never)) {
    errores.modalidad = 'Selecciona una modalidad.';
  }

  if (!TIPOS_ATENCION.includes(datos.tipo as never)) {
    errores.tipo = 'Selecciona un tipo de atención.';
  }

  if (datos.fecha_atencion && Number.isNaN(Date.parse(datos.fecha_atencion))) {
    errores.fecha_atencion = 'Introduce una fecha válida.';
  }

  if (datos.notas.length > 2000) {
    errores.notas = 'Las notas no pueden superar los 2000 caracteres.';
  }

  for (const definicion of INDICADORES) {
    const valor = datos.indicadores[definicion.key];
    if (valor === undefined) continue;

    if (!Number.isFinite(valor) || valor < definicion.min || valor > definicion.max) {
      errores[definicion.key] = `Introduce un número entre ${definicion.min} y ${definicion.max}.`;
    }
  }

  return errores;
}

/**
 * Indica si los siete indicadores estan completos y en rango.
 */
export function indicadoresCompletos(indicadores: Indicadores): boolean {
  return CLAVES_INDICADORES.every((clave) => {
    const valor = indicadores[clave];
    if (valor === undefined) return false;
    const definicion = INDICADORES.find((item) => item.key === clave);
    if (!definicion) return false;
    return Number.isFinite(valor) && valor >= definicion.min && valor <= definicion.max;
  });
}

/**
 * Verifica que el objeto recibido sea un usuario institucional autorizado.
 */
export function esUsuarioInstitucional(valor: unknown): valor is {
  id: number;
  names: string;
  surnames: string;
  role: (typeof ROLES_INSTITUCIONALES)[number];
} {
  if (!valor || typeof valor !== 'object') return false;

  const usuario = valor as Record<string, unknown>;

  return (
    typeof usuario.id === 'number' &&
    typeof usuario.names === 'string' &&
    typeof usuario.role === 'string' &&
    (ROLES_INSTITUCIONALES as readonly string[]).includes(usuario.role)
  );
}

/**
 * Verifica que un periodo tenga el formato YYYY-MM.
 */
export function esPeriodoValido(periodo: string): boolean {
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(periodo)) return false;
  return true;
}

/**
 * Construye los meses transcurridos de un año, del más reciente al más antiguo.
 */
export function mesesDisponibles(referencia: Date = new Date()): string[] {
  const meses: string[] = [];

  for (let indice = 0; indice < 12; indice += 1) {
    const fecha = new Date(referencia.getFullYear(), referencia.getMonth() - indice, 1);
    const anio = fecha.getFullYear();
    const mes = String(fecha.getMonth() + 1).padStart(2, '0');
    meses.push(`${anio}-${mes}`);
  }

  return meses;
}

/**
 * Verifica que el objeto guardado en la sesion tenga la forma de un usuario.
 *
 * A diferencia de `esUsuarioInstitucional`, aqui el rol puede ser cualquiera:
 * la sesion se conserva para que la ruta protegida pueda explicar que el rol
 * no tiene permiso en lugar de descartar la informacion en silencio.
 */
export function esUsuarioSesion(valor: unknown): valor is UsuarioSesion {
  if (!valor || typeof valor !== 'object') return false;

  const usuario = valor as Record<string, unknown>;

  return (
    typeof usuario.id === 'number' &&
    typeof usuario.names === 'string' &&
    typeof usuario.surnames === 'string' &&
    typeof usuario.role === 'string'
  );
}

/**
 * Decodifica un segmento base64url de un JWT.
 */
function decodificarBase64Url(segmento: string): string | null {
  try {
    const normalizado = segmento.replace(/-/g, '+').replace(/_/g, '/');
    const resto = normalizado.length % 4;
    const relleno = resto === 0 ? '' : '='.repeat(4 - resto);
    const binario = atob(normalizado + relleno);
    const bytes = Uint8Array.from(binario, (caracter) => caracter.charCodeAt(0));
    return new TextDecoder('utf-8').decode(bytes);
  } catch {
    return null;
  }
}

/**
 * Decodifica el contenido de un JWT.
 *
 * Devuelve null cuando el token no es un JWT legible: el panel no falla, solo
 * trata el token como si no declarase informacion.
 */
export function decodificarToken(token: string): Record<string, unknown> | null {
  if (!token) return null;

  const segmentos = token.split('.');
  if (segmentos.length < 2) return null;

  const json = decodificarBase64Url(segmentos[1]);
  if (!json) return null;

  try {
    const datos = JSON.parse(json) as unknown;
    if (!datos || typeof datos !== 'object') return null;
    return datos as Record<string, unknown>;
  } catch {
    return null;
  }
}

/**
 * Instante de expiracion del token en milisegundos desde la epoca.
 *
 * Devuelve null cuando el token no declara un `exp` utilizable.
 */
export function expiracionDeToken(token: string): number | null {
  const exp = decodificarToken(token)?.exp;
  if (typeof exp !== 'number' || !Number.isFinite(exp)) return null;
  return exp * 1000;
}

/**
 * Indica si el token ya expiro.
 *
 * Un token sin `exp` legible no se puede dar por expirado: se trata como
 * vigente y el servicio sigue siendo quien decide.
 */
export function tokenExpirado(token: string, ahora: number = Date.now()): boolean {
  const exp = expiracionDeToken(token);
  if (exp === null) return false;
  return exp <= ahora;
}

/**
 * Rol declarado por el token.
 *
 * Es la fuente mas fiable: el backend firma el JWT y es el unico que puede
 * garantizar el rol real de la persona.
 */
export function rolDelToken(token: string | null): string | null {
  if (!token) return null;
  const rol = decodificarToken(token)?.role;
  return typeof rol === 'string' ? rol : null;
}

/** Motivo por el que se deniega el acceso al panel institucional. */
export type MotivoAcceso = 'sin_sesion' | 'rol_no_autorizado';

/** Decision de acceso al panel institucional. */
export interface DecisionAcceso {
  permitido: boolean;
  motivo: MotivoAcceso | null;
  mensaje: string;
}

/** Mensaje mostrado cuando no hay sesion abierta. */
export const MENSAJE_SESION_REQUERIDA =
  'Debes iniciar sesión para entrar al panel institucional.';

/** Mensaje mostrado cuando el rol no esta autorizado para el panel. */
export const MENSAJE_ROL_SIN_PERMISO =
  'Tu rol no tiene permiso para usar el panel institucional.';

/** Mensaje mostrado cuando el servicio rechaza la sesion vigente. */
export const MENSAJE_SESION_EXPIRADA =
  'Tu sesión expiró o el acceso fue rechazado. Inicia sesión nuevamente.';

/**
 * Decide si la persona puede entrar al panel institucional.
 *
 * El rol se toma del token cuando el token lo declara y, si no, del usuario
 * de la sesion. Es una funcion pura: la ruta protegida solo usa el resultado.
 */
export function evaluarAcceso(token: string | null, rol?: string | null): DecisionAcceso {
  if (!token) {
    return { permitido: false, motivo: 'sin_sesion', mensaje: MENSAJE_SESION_REQUERIDA };
  }

  const rolEfectivo = rolDelToken(token) ?? rol ?? null;

  if (!rolEfectivo || !(ROLES_INSTITUCIONALES as readonly string[]).includes(rolEfectivo)) {
    return {
      permitido: false,
      motivo: 'rol_no_autorizado',
      mensaje: MENSAJE_ROL_SIN_PERMISO,
    };
  }

  return { permitido: true, motivo: null, mensaje: '' };
}

/** Estado de navegacion que la ruta protegida entrega al inicio de sesion. */
export interface EstadoRedireccion {
  /** Ruta del panel que se quiso abrir. */
  desde: string;
  /** Motivo legible del rechazo, que el inicio de sesion muestra. */
  mensaje: string;
}

/**
 * Construye el estado de navegacion del inicio de sesion cuando el acceso al
 * panel institucional queda denegado.
 */
export function estadoRedireccion(decision: DecisionAcceso, ruta: string): EstadoRedireccion {
  return { desde: ruta, mensaje: decision.mensaje };
}

/** Textos legibles para cada motivo de ausencia de correlacion de riesgo. */
export const TEXTOS_RIESGO_MOTIVO: Record<RiesgoMotivo, string> = {
  disponible: '',
  no_configurado: 'El servicio de evaluacion de riesgo no esta configurado en el panel',
  no_autorizado: 'El panel no pudo autorizar la consulta al servicio de evaluacion de riesgo',
  servicio_no_disponible: 'El servicio de evaluacion de riesgo no esta disponible',
  sin_datos: 'No hay datos de riesgo suficientes',
  suprimido_k5: 'Los grupos de riesgo se omitieron por la regla de privacidad k=5',
};

/**
 * Explica por que no hay correlacion con el nivel de riesgo.
 *
 * Devuelve una cadena vacia cuando la correlacion si esta disponible.
 */
export function textoRiesgoMotivo(motivo: RiesgoMotivo): string {
  return TEXTOS_RIESGO_MOTIVO[motivo] ?? '';
}

/** Texto mostrado cuando un conteo quedo oculto por la regla k=5. */
export const TEXTO_MENOS_DE_MINIMO = 'menos de 5';

/**
 * Formatea un conteo que puede quedar oculto por la regla de privacidad.
 */
export function formatearConteoProtegido(valor: number | null, minimo = 5): string {
  if (valor === null || valor === undefined) return `menos de ${minimo}`;
  return String(valor);
}

/**
 * Formatea el total de atenciones.
 *
 * Distingue el total exacto del total redondeado a la baja por la regla de
 * privacidad y del total que quedo oculto por tener menos de cinco.
 */
export function formatearTotalAtenciones(total: number | null, estimado: boolean): string {
  if (total === null || total === undefined) return TEXTO_MENOS_DE_MINIMO;
  if (estimado) return `${total} o mas`;
  return String(total);
}

/**
 * Detalle de la tarjeta de grupos visibles.
 *
 * Cuando la regla de privacidad oculto algun grupo, el conteo de grupos
 * visibles es parcial y el panel lo dice en voz alta.
 */
export function textoGruposVisibles(gruposOmitidos: boolean, minimoGrupo = 5): string {
  const base = `Mínimo ${minimoGrupo} estudiantes por grupo`;
  return gruposOmitidos
    ? `${base}. Hay grupos ocultos por la regla de privacidad.`
    : base;
}
