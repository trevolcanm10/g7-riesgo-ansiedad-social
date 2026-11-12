import React, { useState } from 'react';
import type { SolicitudOrientacion } from '../../types/orientacion';

interface DetalleModalProps {
  solicitud: SolicitudOrientacion;
  onClose: () => void;
  onAtender: (
    id: number,
    respuesta: string,
    tema: string,
    prioridad: string
  ) => Promise<void>;
}

const DetalleModal: React.FC<DetalleModalProps> = ({
  solicitud,
  onClose,
  onAtender,
}) => {
  const [tema, setTema] = useState<string>(
    solicitud.tema_confirmado ||
      (solicitud.tema_sugerido && solicitud.tema_sugerido !== 'sin_clasificar'
        ? solicitud.tema_sugerido
        : 'personal')
  );
  const [prioridad, setPrioridad] = useState<string>(
    solicitud.prioridad_confirmada || solicitud.prioridad_sugerida || 'media'
  );
  const [respuesta, setRespuesta] = useState<string>(
    solicitud.respuesta_escrita || ''
  );
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const handleSubmit = async () => {
    const limpia = respuesta.trim();
    if (!limpia) {
      setSubmitError('La respuesta escrita es obligatoria.');
      return;
    }
    setSubmitError(null);
    setIsSubmitting(true);
    try {
      await onAtender(solicitud.id, limpia, tema, prioridad);
    } catch (err) {
      setSubmitError(
        err instanceof Error ? err.message : 'No se pudo guardar la atención.'
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  const esAtendida = solicitud.estado === 'atendida';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
      <div className="bg-white rounded-xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto border border-slate-200">
        {/* Header */}
        <div className="flex justify-between items-center bg-slate-50 px-6 py-4 border-b border-slate-200 rounded-t-xl">
          <h2 className="text-xl font-bold text-slate-800">
            Detalle de Solicitud #{solicitud.id}
          </h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Cerrar detalle"
            className="text-slate-400 hover:text-slate-600 transition"
          >
            <svg
              className="w-6 h-6"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        {/* Body */}
        <div className="p-6 space-y-6">
          <div className="bg-blue-50 p-4 rounded-lg border border-blue-100 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <p className="text-sm text-blue-600 font-semibold mb-1">
                Estudiante ID
              </p>
              <p className="text-lg font-bold text-blue-900">
                #{solicitud.estudiante_id}
              </p>
            </div>
            {solicitud.comparte_evaluacion_riesgo && (
              <span className="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                Evaluación vinculada (ID: {solicitud.evaluacion_riesgo_id})
              </span>
            )}
          </div>

          {esAtendida && solicitud.atendido_por != null && (
            <div className="bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm px-4 py-2.5 rounded-lg">
              Atendida por orientador UNAYOE #{solicitud.atendido_por}
            </div>
          )}

          {/* Mensaje original */}
          <div>
            <h3 className="text-sm font-bold text-slate-700 uppercase tracking-wide mb-2 flex items-center">
              Mensaje del Estudiante
              {solicitud.urgencia_detectada && (
                <span className="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800">
                  Alerta Crítica
                </span>
              )}
            </h3>
            <div className="bg-slate-50 p-4 rounded-lg border border-slate-200 text-slate-800 text-base leading-relaxed whitespace-pre-wrap">
              {solicitud.mensaje}
            </div>
          </div>

          {/* Confirmación de IA (Human-in-the-loop) */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 bg-white p-4 rounded-lg border border-indigo-100 shadow-sm">
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1">
                Tema (Sugerido:{' '}
                {solicitud.tema_sugerido === 'sin_clasificar'
                  ? 'Sin clasificar'
                  : solicitud.tema_sugerido || 'sin definir'}
                )
              </label>
              <select
                disabled={esAtendida}
                value={tema}
                onChange={(e) => setTema(e.target.value)}
                className="w-full border-slate-300 rounded-md shadow-sm p-2 text-sm focus:ring-indigo-500 focus:border-indigo-500 border disabled:bg-slate-100"
              >
                <option value="academico">Académico</option>
                <option value="ansiedad_estres">Ansiedad / Estrés</option>
                <option value="familiar">Familiar</option>
                <option value="personal">Personal</option>
                <option value="economico">Económico</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1">
                Prioridad (Sugerida:{' '}
                {solicitud.prioridad_sugerida || 'sin definir'})
              </label>
              <select
                disabled={esAtendida}
                value={prioridad}
                onChange={(e) => setPrioridad(e.target.value)}
                className="w-full border-slate-300 rounded-md shadow-sm p-2 text-sm focus:ring-indigo-500 focus:border-indigo-500 border disabled:bg-slate-100"
              >
                <option value="alta">Alta</option>
                <option value="media">Media</option>
                <option value="baja">Baja</option>
              </select>
            </div>
            {!esAtendida && (
              <div className="col-span-1 sm:col-span-2 text-xs text-indigo-600 mt-1">
                * Revisa y confirma o corrige la sugerencia local del modelo.
              </div>
            )}
          </div>

          {/* Respuesta Escrita */}
          <div>
            <h3 className="text-sm font-bold text-slate-700 uppercase tracking-wide mb-2">
              Respuesta del Orientador
            </h3>
            <textarea
              disabled={esAtendida}
              maxLength={3000}
              value={respuesta}
              onChange={(e) => setRespuesta(e.target.value)}
              rows={5}
              placeholder="Escribe la orientación o pautas a seguir..."
              className="w-full border-slate-300 rounded-lg shadow-sm p-3 focus:ring-indigo-500 focus:border-indigo-500 border disabled:bg-slate-100 disabled:text-slate-600"
            />
          </div>

          {submitError && (
            <div
              role="alert"
              className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm"
            >
              {submitError}
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="bg-slate-50 px-6 py-4 border-t border-slate-200 rounded-b-xl flex justify-end gap-3">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 border border-slate-300 rounded-lg text-slate-700 bg-white hover:bg-slate-50 font-medium transition-colors"
          >
            Cerrar
          </button>

          {!esAtendida && (
            <button
              type="button"
              onClick={handleSubmit}
              disabled={isSubmitting}
              className="px-6 py-2 border border-transparent rounded-lg shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 font-medium transition-colors flex items-center disabled:opacity-70"
            >
              {isSubmitting ? 'Guardando...' : 'Guardar y Atender'}
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default DetalleModal;
