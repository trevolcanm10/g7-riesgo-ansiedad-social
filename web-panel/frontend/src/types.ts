/** Tipos del dominio del Panel Institucional. */

/** Modalidades de atención admitidas por el microservicio. */
export const MODALIDADES = [
  'presencial',
  'virtual',
  'telefonica',
  'correo',
] as const;
export type Modalidad = (typeof MODALIDADES)[number];

/** Tipos de atención admitidos por el microservicio. */
export const TIPOS_ATENCION = [
  'orientacion',
  'seguimiento',
  'derivacion',
  'evaluacion',
  'emergencia',
] as const;
export type TipoAtencion = (typeof TIPOS_ATENCION)[number];

/** Roles autorizados a operar el panel institucional. */
export const ROLES_INSTITUCIONALES = ['PERSONAL_UNAYOE', 'ADMINISTRADOR'] as const;
export type RolInstitucional = (typeof ROLES_INSTITUCIONALES)[number];

/**
 * Motivos por los que la correlacion con el nivel de riesgo puede no estar
 * disponible. El panel nunca falla en silencio: expone el motivo para que el
 * personal distinga entre falta de configuracion, rechazo del servicio y
 * ausencia de datos.
 */
export const RIESGO_MOTIVOS = [
  'disponible',
  'no_configurado',
  'no_autorizado',
  'servicio_no_disponible',
  'sin_datos',
  'suprimido_k5',
] as const;
export type RiesgoMotivo = (typeof RIESGO_MOTIVOS)[number];

/** Claves de los siete indicadores del contrato de evaluación de riesgo. */
export const CLAVES_INDICADORES = [
  'phq9',
  'gad7',
  'online_stress',
  'financial_stress',
  'exercise_freq',
  'social_activity',
  'sleep_hours',
] as const;
export type ClaveIndicador = (typeof CLAVES_INDICADORES)[number];

export type Indicadores = Partial<Record<ClaveIndicador, number>>;

/** Definición de un indicador con su rango válido y su etiqueta. */
export interface DefinicionIndicador {
  key: ClaveIndicador;
  label: string;
  min: number;
  max: number;
  hint: string;
}

/** Usuario institucional autenticado. */
export interface UsuarioInstitucional {
  id: number;
  names: string;
  surnames: string;
  role: RolInstitucional;
}

/**
 * Usuario guardado en la sesion de la pestana.
 *
 * A diferencia de `UsuarioInstitucional`, el rol puede ser cualquiera: la
 * sesion se conserva para que la ruta protegida pueda explicar que el rol no
 * tiene permiso en lugar de descartar la informacion en silencio.
 */
export interface UsuarioSesion {
  id: number;
  names: string;
  surnames: string;
  role: string;
}

/** Atención registrada. */
export interface Atencion {
  id: number;
  estudiante_codigo: string;
  modalidad: Modalidad;
  tipo: TipoAtencion;
  estado: string;
  indicadores: Indicadores;
  cluster_id: number | null;
  seguimiento_requerido: boolean;
  registrado_por: string | null;
  notas: string | null;
  fecha_atencion: string;
  fecha_creacion: string;
}

/** Página de atenciones. */
export interface PaginaAtenciones {
  total: number;
  limite: number;
  offset: number;
  atenciones: Atencion[];
}

/** Agrupado estadistico ya filtrado por la regla de privacidad k=5. */
export interface GrupoEstadistico {
  etiqueta: string;
  n: number;
}

/** Perfil de agrupamiento generado por el modelo de IA. */
export interface PerfilIA {
  cluster: number;
  n: number;
  /** Porcentaje sobre los estudiantes con perfil asignado en el periodo. */
  porcentaje: number;
  descripcion: string;
  medias: Record<string, number>;
  nivel_orientativo: 'bajo' | 'moderado' | 'elevado' | 'no_clasificado';
  /**
   * Conteo por nivel de riesgo dentro del perfil. Viene del microservicio de
   * evaluacion de riesgo, consultado por HTTP. Las celdas con menos de cinco
   * estudiantes se omiten.
   */
  riesgo: Record<'BAJO' | 'MEDIO' | 'ALTO', number>;
  /** Numero de celdas de nivel de riesgo ocultas por la regla k=5. */
  riesgo_omitidos: number;
  /** False cuando el servicio de evaluacion de riesgo no respondio. */
  riesgo_disponible: boolean;
  /** Motivo por el que no hay correlacion de riesgo en este perfil. */
  riesgo_motivo: RiesgoMotivo;
}

/** Estadísticas anonimizadas del panel. */
export interface Estadisticas {
  periodo: string | null;
  /** Numero de atenciones. Es null cuando hay menos de cinco. */
  total_atenciones: number | null;
  /** True cuando el total se redondeo a la baja a multiplo de cinco. */
  total_atenciones_estimado: boolean;
  /** Numero de atenciones con seguimiento pendiente. Null si hay menos de cinco. */
  requieren_seguimiento: number | null;
  /** True cuando el conteo de seguimiento quedo oculto por la regla k=5. */
  requieren_seguimiento_suprimido: boolean;
  por_tipo: GrupoEstadistico[];
  por_modalidad: GrupoEstadistico[];
  por_estado: GrupoEstadistico[];
  por_periodo: GrupoEstadistico[];
  perfiles_ia: PerfilIA[];
  /** True cuando al menos un grupo quedo oculto por la regla de privacidad. */
  grupos_omitidos: boolean;
  minimo_grupo_publicable: number;
  /** True cuando hay correlacion con el nivel de riesgo disponible. */
  riesgo_disponible: boolean;
  /** Motivo por el que la correlacion con el nivel de riesgo no esta disponible. */
  riesgo_motivo: RiesgoMotivo;
  /** Numero de atenciones sin resolver. Null si hay menos de cinco. */
  atenciones_sin_resolver: number | null;
  /** True cuando el conteo de atenciones sin resolver quedo oculto. */
  atenciones_sin_resolver_suprimido: boolean;
  nota_ia: string;
}
