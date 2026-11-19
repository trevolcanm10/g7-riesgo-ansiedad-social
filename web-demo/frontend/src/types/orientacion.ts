export type TemaOrientacion =
  | 'academico'
  | 'ansiedad_estres'
  | 'economico'
  | 'familiar'
  | 'personal';

export type PrioridadOrientacion = 'alta' | 'media' | 'baja';

export interface SolicitudOrientacion {
  id: number;
  estudiante_id: number;
  mensaje: string;
  comparte_evaluacion_riesgo: boolean;
  evaluacion_riesgo_id?: number | null;
  tema_sugerido?: TemaOrientacion | string | null;
  prioridad_sugerida?: PrioridadOrientacion | null;
  urgencia_detectada: boolean;
  estado: 'pendiente' | 'atendida';
  tema_confirmado?: TemaOrientacion | string | null;
  prioridad_confirmada?: PrioridadOrientacion | null;
  respuesta_escrita?: string | null;
  atendido_por?: number | null;
  fecha_creacion: string;
  fecha_atencion?: string | null;
}

export type StaffRole = 'PERSONAL_UNAYOE' | 'ADMINISTRADOR';

export interface StaffSession {
  token: string;
  userId: number;
  role: StaffRole;
}
