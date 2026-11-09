export interface SolicitudOrientacion {
  id: number;
  estudiante_id: string;
  mensaje: string;
  comparte_evaluacion_riesgo: boolean;
  evaluacion_riesgo_id?: number | null;
  tema_sugerido?: string | null;
  prioridad_sugerida?: 'alta' | 'media' | 'baja' | null;
  urgencia_detectada: boolean;
  estado: 'pendiente' | 'atendida';
  tema_confirmado?: string | null;
  prioridad_confirmada?: 'alta' | 'media' | 'baja' | null;
  respuesta_escrita?: string | null;
  atendido_por?: string | null;
  fecha_creacion: string;
  fecha_atencion?: string | null;
}
