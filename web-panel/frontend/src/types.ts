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
}

/** Estadísticas anonimizadas del panel. */
export interface Estadisticas {
  periodo: string | null;
  total_atenciones: number;
  requieren_seguimiento: number;
  por_tipo: GrupoEstadistico[];
  por_modalidad: GrupoEstadistico[];
  por_estado: GrupoEstadistico[];
  por_periodo: GrupoEstadistico[];
  perfiles_ia: PerfilIA[];
  grupos_omitidos_por_privacidad: number;
  minimo_grupo_publicable: number;
  nota_ia: string;
}
