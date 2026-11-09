import React, { useState, useEffect } from 'react';
import { SolicitudOrientacion } from '../types/orientacion';
import { obtenerSolicitudes, atenderSolicitud } from '../services/orientacionService';
import DetalleModal from '../components/orientacion/DetalleModal';

const BandejaOrientacion: React.FC = () => {
  const [solicitudes, setSolicitudes] = useState<SolicitudOrientacion[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  // Filtros
  const [filtroEstado, setFiltroEstado] = useState<string>('');
  const [filtroPrioridad, setFiltroPrioridad] = useState<string>('');

  // Modal
  const [selectedSolicitud, setSelectedSolicitud] = useState<SolicitudOrientacion | null>(null);

  const cargarSolicitudes = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const data = await obtenerSolicitudes(filtroEstado, filtroPrioridad);
      setSolicitudes(data);
    } catch (err: any) {
      setError(err.message || 'Error de conexión.');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    cargarSolicitudes();
  }, [filtroEstado, filtroPrioridad]);

  const handleOpenModal = (solicitud: SolicitudOrientacion) => {
    setSelectedSolicitud(solicitud);
  };

  const handleCloseModal = () => {
    setSelectedSolicitud(null);
  };

  const handleAtender = async (
    id: number,
    respuesta: string,
    tema: string,
    prioridad: string
  ) => {
    try {
      // Usamos el nombre quemado del orientador para la demo
      await atenderSolicitud(id, {
        respuesta_escrita: respuesta,
        atendido_por: 'Orientador UNAYOE',
        tema_confirmado: tema,
        prioridad_confirmada: prioridad,
      });
      // Recargar tabla después de actualizar
      cargarSolicitudes();
      handleCloseModal();
    } catch (err: any) {
      alert(err.message || 'Error al guardar');
    }
  };

  const getPrioridadBadge = (prioridad?: string | null) => {
    switch (prioridad) {
      case 'alta':
        return <span className="px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800">Alta</span>;
      case 'media':
        return <span className="px-2 py-1 text-xs font-semibold rounded-full bg-yellow-100 text-yellow-800">Media</span>;
      case 'baja':
        return <span className="px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">Baja</span>;
      default:
        return <span className="px-2 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-800">N/A</span>;
    }
  };

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1 className="text-3xl font-bold text-slate-800">Bandeja de Orientación Confidencial</h1>
          <p className="text-slate-500 mt-1">Gestión de solicitudes de apoyo de estudiantes.</p>
        </div>
      </div>

      {/* Filtros */}
      <div className="bg-white p-4 rounded-lg shadow-sm mb-6 flex gap-4 border border-slate-200">
        <div>
          <label className="block text-sm font-medium text-slate-700 mb-1">Estado</label>
          <select
            value={filtroEstado}
            onChange={(e) => setFiltroEstado(e.target.value)}
            className="border-slate-300 rounded-md shadow-sm p-2 w-40 text-sm focus:ring-indigo-500 focus:border-indigo-500 border"
          >
            <option value="">Todos</option>
            <option value="pendiente">Pendiente</option>
            <option value="atendida">Atendida</option>
          </select>
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700 mb-1">Prioridad</label>
          <select
            value={filtroPrioridad}
            onChange={(e) => setFiltroPrioridad(e.target.value)}
            className="border-slate-300 rounded-md shadow-sm p-2 w-40 text-sm focus:ring-indigo-500 focus:border-indigo-500 border"
          >
            <option value="">Todas</option>
            <option value="alta">Alta</option>
            <option value="media">Media</option>
            <option value="baja">Baja</option>
          </select>
        </div>
      </div>

      {/* Error & Loading */}
      {error && <div className="bg-red-50 text-red-700 p-4 rounded-lg mb-6">{error}</div>}
      {isLoading && !error && <div className="text-slate-500 py-4">Cargando solicitudes...</div>}

      {/* Tabla */}
      {!isLoading && !error && (
        <div className="bg-white rounded-lg shadow-sm border border-slate-200 overflow-hidden">
          <table className="min-w-full divide-y divide-slate-200">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">Fecha</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">Estudiante</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">Mensaje (Resumen)</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">Tema (IA)</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">Prioridad</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">Estado</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-slate-500 uppercase tracking-wider">Acción</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-slate-200">
              {solicitudes.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-6 py-8 text-center text-slate-500">
                    No hay solicitudes que coincidan con los filtros.
                  </td>
                </tr>
              ) : (
                solicitudes.map((sol) => (
                  <tr key={sol.id} className="hover:bg-slate-50 transition-colors">
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-slate-600">
                      {new Date(sol.fecha_creacion).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-slate-900">
                      {sol.estudiante_id}
                    </td>
                    <td className="px-6 py-4 text-sm text-slate-600 max-w-xs truncate">
                      {sol.urgencia_detectada && (
                        <span title="Alerta Crítica" className="inline-block mr-2">
                          <svg className="w-5 h-5 text-red-600 inline -mt-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                          </svg>
                        </span>
                      )}
                      {sol.mensaje}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-slate-600 capitalize">
                      <span className="bg-indigo-50 text-indigo-700 px-2 py-1 rounded-md text-xs font-medium border border-indigo-100">
                        {sol.tema_confirmado || sol.tema_sugerido || 'No clasificado'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {getPrioridadBadge(sol.prioridad_confirmada || sol.prioridad_sugerida)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {sol.estado === 'atendida' ? (
                        <span className="text-emerald-600 text-sm font-semibold">Atendida</span>
                      ) : (
                        <span className="text-orange-500 text-sm font-semibold">Pendiente</span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button
                        onClick={() => handleOpenModal(sol)}
                        className="text-indigo-600 hover:text-indigo-900 bg-indigo-50 hover:bg-indigo-100 px-3 py-1.5 rounded-md transition-colors"
                      >
                        Revisar
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Modal Detalles */}
      {selectedSolicitud && (
        <DetalleModal
          solicitud={selectedSolicitud}
          onClose={handleCloseModal}
          onAtender={handleAtender}
        />
      )}
    </div>
  );
};

export default BandejaOrientacion;
