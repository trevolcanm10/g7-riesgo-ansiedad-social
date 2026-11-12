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
