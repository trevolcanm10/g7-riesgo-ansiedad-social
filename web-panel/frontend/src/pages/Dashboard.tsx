/**
 * Dashboard analitico del panel institucional.
 */
import { useCallback, useEffect, useState } from 'react';
import { Activity, Brain, ClipboardCheck, Users } from 'lucide-react';
import { useSesion } from '../app/AuthContext';
import { AvisoIA, AvisoPrivacidad } from '../components/Avisos';
import { GraficoAnillo, GraficoBarras, TarjetaIndicador } from '../components/Graficos';
import { obtenerEstadisticas } from '../services/panel';
import {
  ETIQUETAS_TIPO,
  formatearConteoProtegido,
  formatearTotalAtenciones,
  mesesDisponibles,
  textoGruposVisibles,
  textoRiesgoMotivo,
} from '../validation';
import type { Estadisticas } from '../types';

export default function PaginaDashboard() {
  const { token } = useSesion();

  const [estadisticas, setEstadisticas] = useState<Estadisticas | null>(null);
  const [periodo, setPeriodo] = useState<string>('');
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  const cargar = useCallback(async () => {
    if (!token) return;

    setCargando(true);
    setError('');

    try {
      setEstadisticas(await obtenerEstadisticas(periodo || null, token));
    } catch (fallo) {
      setError(fallo instanceof Error ? fallo.message : 'No se pudieron cargar las estadísticas.');
    } finally {
      setCargando(false);
    }
  }, [token, periodo]);

  useEffect(() => {
    void cargar();
  }, [cargar]);

  const porTipo = (estadisticas?.por_tipo ?? []).map((grupo) => ({
    etiqueta: ETIQUETAS_TIPO[grupo.etiqueta] ?? grupo.etiqueta,
    n: grupo.n,
  }));

  const porModalidad = estadisticas?.por_modalidad ?? [];
  const total = estadisticas?.total_atenciones ?? 0;

  // Los conteos protegidos por la regla k=5 pueden venir suprimidos: el
  // panel muestra un texto legible en lugar de un numero inventado.
  const totalAtenciones = estadisticas
    ? formatearTotalAtenciones(estadisticas.total_atenciones, estadisticas.total_atenciones_estimado)
    : '—';
  const seguimiento = estadisticas
    ? formatearConteoProtegido(estadisticas.requieren_seguimiento)
    : '—';
  const gruposVisibles =
    (estadisticas?.por_tipo.length ?? 0) +
    (estadisticas?.por_modalidad.length ?? 0) +
    (estadisticas?.por_estado.length ?? 0);
  const detalleGrupos = textoGruposVisibles(
    estadisticas?.grupos_omitidos ?? false,
    estadisticas?.minimo_grupo_publicable ?? 5,
  );
  const motivoRiesgo = estadisticas ? textoRiesgoMotivo(estadisticas.riesgo_motivo) : '';

  return (
    <div className="flex flex-col gap-6">
      {/* El aviso del modelo sintetico encabeza el dashboard: es la primera
          advertencia que debe ver el personal institucional. */}
      <AvisoIA nota={estadisticas?.nota_ia} />

      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-widest text-[var(--color-green)]">
            Analítica institucional
          </p>
          <h2 className="mt-1 text-xl font-bold text-[var(--color-navy)]">
            Indicadores del bienestar estudiantil
          </h2>
          <p className="mt-1 max-w-2xl text-sm">
            Datos agregados de las atenciones registradas. Ningún grupo con menos de cinco
            estudiantes se muestra.
          </p>
        </div>

        <div className="field w-48">
          <label htmlFor="periodo">Periodo</label>
          <select
            id="periodo"
            value={periodo}
            onChange={(evento) => setPeriodo(evento.target.value)}
          >
            <option value="">Todo el histórico</option>
            {mesesDisponibles().map((mes) => (
              <option key={mes} value={mes}>
                {mes}
              </option>
            ))}
          </select>
        </div>
      </div>

      {error && (
        <div className="error-banner" role="alert">
          {error}
        </div>
      )}

      {estadisticas && (
        <AvisoPrivacidad grupos_omitidos={estadisticas.grupos_omitidos} />
      )}

      {estadisticas && !estadisticas.riesgo_disponible && motivoRiesgo && (
        <div className="notice" role="status">
          <p className="text-sm">
            <strong className="font-semibold">Sin correlación con el nivel de riesgo. </strong>
            {motivoRiesgo}
          </p>
        </div>
      )}

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <TarjetaIndicador
          etiqueta="Atenciones registradas"
          valor={totalAtenciones}
          detalle={periodo ? `Periodo ${periodo}` : 'Todo el histórico'}
          icono={<ClipboardCheck size={20} />}
        />
        <TarjetaIndicador
          etiqueta="Requieren seguimiento"
          valor={seguimiento}
          detalle="Atenciones con seguimiento pendiente"
          icono={<Activity size={20} />}
        />
        <TarjetaIndicador
          etiqueta="Grupos visibles"
          valor={gruposVisibles}
          detalle={detalleGrupos}
          icono={<Users size={20} />}
        />
        <TarjetaIndicador
          etiqueta="Perfiles de IA"
          valor={estadisticas?.perfiles_ia.length ?? 0}
          detalle="Perfiles publicables del modelo"
          icono={<Brain size={20} />}
        />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <section className="panel panel-body">
          <h3 className="text-base font-bold text-[var(--color-navy)]">
            Distribución por tipo de atención
          </h3>
          <p className="mb-4 mt-1 text-xs">
            Solo se muestran los tipos con al menos cinco atenciones.
          </p>
          {cargando ? (
            <p className="py-6 text-center text-sm text-[var(--color-muted)]">Cargando…</p>
          ) : (
            <GraficoBarras grupos={porTipo} />
          )}
        </section>

        <section className="panel panel-body">
          <h3 className="text-base font-bold text-[var(--color-navy)]">
            Distribución por modalidad
          </h3>
          <p className="mb-4 mt-1 text-xs">
            Proporción de atenciones sobre el total del periodo.
          </p>
          {cargando ? (
            <p className="py-6 text-center text-sm text-[var(--color-muted)]">Cargando…</p>
          ) : (
            <GraficoAnillo grupos={porModalidad} total={total} />
          )}
        </section>
      </div>

      <section className="panel panel-body">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <h3 className="text-base font-bold text-[var(--color-navy)]">
            Perfiles generados por el modelo de agrupamiento
          </h3>
        </div>

        {cargando ? (
          <p className="py-6 text-center text-sm text-[var(--color-muted)]">Cargando…</p>
        ) : (estadisticas?.perfiles_ia.length ?? 0) === 0 ? (
          <p className="py-6 text-center text-sm text-[var(--color-muted)]">
            No hay perfiles publicables. Se necesitan al menos cinco estudiantes observados en
            un mismo perfil.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="tabla">
              <thead>
                <tr>
                  <th scope="col">Perfil</th>
                  <th scope="col">Nivel</th>
                  <th scope="col">Estudiantes</th>
                  <th scope="col">% del total</th>
                  <th scope="col">Riesgo</th>
                  <th scope="col">PHQ-9 medio</th>
                  <th scope="col">GAD-7 medio</th>
                  <th scope="col">Descripción</th>
                </tr>
              </thead>
              <tbody>
                {estadisticas?.perfiles_ia.map((perfil) => (
                  <tr key={perfil.cluster}>
                    <td className="font-semibold text-[var(--color-navy)]">
                      Perfil {perfil.cluster}
                    </td>
                    <td>
                      <span
                        className={`badge ${
                          perfil.nivel_orientativo === 'elevado'
                            ? 'badge-elevado'
                            : perfil.nivel_orientativo === 'moderado'
                              ? 'badge-moderado'
                              : 'badge-bajo'
                        }`}
                      >
                        {perfil.nivel_orientativo}
                      </span>
                    </td>
                    <td className="tabular-nums">{perfil.n}</td>
                    <td className="tabular-nums font-semibold text-[var(--color-navy)]">
                      {perfil.porcentaje.toFixed(1)}%
                    </td>
                    <td className="text-xs">
                      {perfil.riesgo_disponible ? (
                        <span className="flex flex-wrap items-center gap-1.5">
                          {(['ALTO', 'MEDIO', 'BAJO'] as const).map((nivel) =>
                            perfil.riesgo[nivel] !== undefined ? (
                              <span
                                key={nivel}
                                className={`badge ${
                                  nivel === 'ALTO'
                                    ? 'badge-elevado'
                                    : nivel === 'MEDIO'
                                      ? 'badge-moderado'
                                      : 'badge-bajo'
                                }`}
                              >
                                {nivel} {perfil.riesgo[nivel]}
                              </span>
                            ) : null,
                          )}
                          {perfil.riesgo_omitidos > 0 && (
                            <span className="text-[var(--color-muted)]">
                              (+{perfil.riesgo_omitidos} oculto
                              {perfil.riesgo_omitidos === 1 ? '' : 's'} por k=5)
                            </span>
                          )}
                        </span>
                      ) : (
                        <span className="text-[var(--color-muted)]">
                          {textoRiesgoMotivo(perfil.riesgo_motivo) || 'Sin correlación'}
                        </span>
                      )}
                    </td>
                    <td className="tabular-nums">
                      {perfil.medias?.phq9?.toFixed(1) ?? '—'}
                    </td>
                    <td className="tabular-nums">
                      {perfil.medias?.gad7?.toFixed(1) ?? '—'}
                    </td>
                    <td className="max-w-md text-xs">{perfil.descripcion}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
