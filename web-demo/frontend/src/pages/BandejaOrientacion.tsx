import React, { useCallback, useEffect, useState } from 'react';
import DetalleModal from '../components/orientacion/DetalleModal';
import {
  atenderSolicitud,
  loginPersonalUnayoe,
  obtenerSolicitudes,
} from '../services/orientacionService';
import type { SolicitudOrientacion, StaffSession } from '../types/orientacion';

const TEMA_LABELS: Record<string, string> = {
  academico: 'Académico',
  ansiedad_estres: 'Ansiedad y estrés',
  economico: 'Económico',
  familiar: 'Familiar',
  personal: 'Personal',
  sin_clasificar: 'Sin clasificar',
};

function solicitudTemaLabel(tema?: string | null): string {
  if (!tema) return 'Sin clasificar';
  return TEMA_LABELS[tema] ?? tema.replace(/_/g, ' ');
}

const BandejaOrientacion: React.FC = () => {
  // La sesión JWT del orientador se conserva solo en memoria React (nunca en storage persistente)
  const [session, setSession] = useState<StaffSession | null>(null);
  const [email, setEmail] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [loginError, setLoginError] = useState<string | null>(null);
  const [isLoggingIn, setIsLoggingIn] = useState<boolean>(false);

  const [solicitudes, setSolicitudes] = useState<SolicitudOrientacion[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  const [filtroEstado, setFiltroEstado] = useState<string>('');
  const [filtroPrioridad, setFiltroPrioridad] = useState<string>('');
  const [selectedSolicitud, setSelectedSolicitud] =
    useState<SolicitudOrientacion | null>(null);

  const cerrarSesion = useCallback(() => {
    setSession(null);
    setSolicitudes([]);
    setSelectedSolicitud(null);
    setPassword('');
    setError(null);
  }, []);

  const cargarSolicitudes = useCallback(async () => {
    if (!session) return;
    setIsLoading(true);
    setError(null);
    try {
      const data = await obtenerSolicitudes(
        session.token,
        filtroEstado,
        filtroPrioridad
      );
      setSolicitudes(data);
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Error de conexión.';
      setError(msg);
      if (msg.includes('expiró') || msg.includes('permisos')) {
        setSession(null);
        setSolicitudes([]);
      }
    } finally {
      setIsLoading(false);
    }
  }, [session, filtroEstado, filtroPrioridad]);

  useEffect(() => {
    if (session) {
      void cargarSolicitudes();
    }
  }, [session, cargarSolicitudes]);

  const handleLoginSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !password) {
      setLoginError('Ingresa tu correo institucional y contraseña.');
      return;
    }
    setIsLoggingIn(true);
    setLoginError(null);
    try {
      const staffSession = await loginPersonalUnayoe(email, password);
      setPassword('');
      setSession(staffSession);
    } catch (err) {
      setLoginError(
        err instanceof Error ? err.message : 'No se pudo iniciar sesión.'
      );
    } finally {
      setIsLoggingIn(false);
    }
  };

  const handleAtender = async (
    id: number,
    respuesta: string,
    tema: string,
    prioridad: string
  ) => {
    if (!session) {
      throw new Error('Tu sesión ha expirado. Vuelve a iniciar sesión.');
    }
    await atenderSolicitud(session.token, id, {
      respuesta_escrita: respuesta,
      tema_confirmado: tema,
      prioridad_confirmada: prioridad,
    });
    setSelectedSolicitud(null);
    await cargarSolicitudes();
  };

  const getPrioridadBadge = (prioridad?: string | null) => {
    switch (prioridad) {
      case 'alta':
        return (
          <span className="px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800">
            Alta
          </span>
        );
      case 'media':
        return (
          <span className="px-2 py-1 text-xs font-semibold rounded-full bg-yellow-100 text-yellow-800">
            Media
          </span>
        );
      case 'baja':
        return (
          <span className="px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">
            Baja
          </span>
        );
      default:
        return (
          <span className="px-2 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-800">
            N/A
          </span>
        );
    }
  };

  if (!session) {
    return (
      <div className="max-w-md mx-auto mt-10 bg-white p-8 rounded-xl shadow-sm border border-slate-200">
        <h1 className="text-2xl font-bold text-slate-800 mb-2">
          Bandeja UNAYOE — Acceso Restringido
        </h1>
        <p className="text-sm text-slate-600 mb-6">
          Inicia sesión con una cuenta autorizada (
          <code>PERSONAL_UNAYOE</code> o <code>ADMINISTRADOR</code>) para revisar
          solicitudes confidenciales.
        </p>

        <form onSubmit={handleLoginSubmit} className="space-y-4">
          <div>
            <label
              htmlFor="staff-email"
              className="block text-sm font-medium text-slate-700 mb-1"
            >
              Correo institucional
            </label>
            <input
              id="staff-email"
              type="email"
              required
              autoComplete="username"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="orientador@unmsm.edu.pe"
              className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>

          <div>
            <label
              htmlFor="staff-password"
              className="block text-sm font-medium text-slate-700 mb-1"
            >
              Contraseña
            </label>
            <input
              id="staff-password"
              type="password"
              required
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>

          {(loginError || error) && (
            <div
              role="alert"
              className="bg-red-50 border border-red-200 text-red-700 px-3 py-2.5 rounded-lg text-sm"
            >
              {loginError || error}
            </div>
          )}

          <button
            type="submit"
            disabled={isLoggingIn}
            className="w-full py-2.5 px-4 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white font-medium text-sm transition-colors disabled:opacity-70"
          >
            {isLoggingIn ? 'Verificando acceso...' : 'Ingresar a Bandeja UNAYOE'}
          </button>
        </form>
      </div>
    );
  }

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-4 mb-6">
        <div>
          <h1 className="text-3xl font-bold text-slate-800">
            Bandeja de Orientación Confidencial
          </h1>
          <p className="text-slate-500 mt-1">
            Sesión activa: {session.role} (ID #{session.userId})
          </p>
        </div>
        <button
          type="button"
          onClick={cerrarSesion}
          className="self-start sm:self-auto px-4 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-lg hover:bg-slate-50"
        >
          Cerrar sesión
        </button>
      </div>

      {/* Filtros */}
      <div className="bg-white p-4 rounded-lg shadow-sm mb-6 flex gap-4 border border-slate-200">
        <div>
          <label className="block text-sm font-medium text-slate-700 mb-1">
            Estado
          </label>
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
          <label className="block text-sm font-medium text-slate-700 mb-1">
            Prioridad
          </label>
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

      {error && (
        <div role="alert" className="bg-red-50 text-red-700 p-4 rounded-lg mb-6">
          {error}
        </div>
      )}
      {isLoading && !error && (
        <div className="text-slate-500 py-4">Cargando solicitudes...</div>
      )}

      {!isLoading && !error && (
        <div className="bg-white rounded-lg shadow-sm border border-slate-200 overflow-hidden">
          <table className="min-w-full divide-y divide-slate-200">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                  Fecha
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                  Estudiante
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                  Mensaje (Resumen)
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                  Tema (IA)
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                  Prioridad
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                  Estado
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-slate-500 uppercase tracking-wider">
                  Acción
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-slate-200">
              {solicitudes.length === 0 ? (
                <tr>
                  <td
                    colSpan={7}
                    className="px-6 py-8 text-center text-slate-500"
                  >
                    No hay solicitudes que coincidan con los filtros.
                  </td>
                </tr>
              ) : (
                solicitudes.map((sol) => (
                  <tr
                    key={sol.id}
                    className="hover:bg-slate-50 transition-colors"
                  >
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-slate-600">
                      {new Date(sol.fecha_creacion).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-slate-900">
                      #{sol.estudiante_id}
                    </td>
                    <td className="px-6 py-4 text-sm text-slate-600 max-w-xs truncate">
                      {sol.urgencia_detectada && (
                        <span
                          title="Alerta Crítica"
                          className="inline-block mr-2 text-red-600 font-semibold"
                        >
                          [Urgente]
                        </span>
                      )}
                      {sol.mensaje}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-slate-600">
                      <span className="bg-indigo-50 text-indigo-700 px-2 py-1 rounded-md text-xs font-medium border border-indigo-100">
                        {solicitudTemaLabel(
                          sol.tema_confirmado || sol.tema_sugerido
                        )}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {getPrioridadBadge(
                        sol.prioridad_confirmada || sol.prioridad_sugerida
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {sol.estado === 'atendida' ? (
                        <span className="text-emerald-600 text-sm font-semibold">
                          Atendida
                        </span>
                      ) : (
                        <span className="text-orange-500 text-sm font-semibold">
                          Pendiente
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button
                        type="button"
                        onClick={() => setSelectedSolicitud(sol)}
                        className="text-indigo-600 hover:text-indigo-900 bg-indigo-50 hover:bg-indigo-100 px-3 py-1.5 rounded-md transition-colors"
                      >
                        {sol.estado === 'atendida' ? 'Ver Detalle' : 'Atender'}
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {selectedSolicitud && (
        <DetalleModal
          solicitud={selectedSolicitud}
          onClose={() => setSelectedSolicitud(null)}
          onAtender={handleAtender}
        />
      )}
    </div>
  );
};

export default BandejaOrientacion;
