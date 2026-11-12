/**
 * Formulario de registro unico de atenciones.
 */
import { useState, type FormEvent } from 'react';
import { CheckCircle2, Save } from 'lucide-react';
import { useSesion } from '../app/AuthContext';
import { registrarAtencion } from '../services/panel';
import {
  ETIQUETAS_MODALIDAD,
  ETIQUETAS_TIPO,
  INDICADORES,
  indicadoresCompletos,
  validarAtencion,
} from '../validation';
import { MODALIDADES, TIPOS_ATENCION, type Indicadores } from '../types';

export default function PaginaRegistroAtencion() {
  const { token } = useSesion();

  const [estudianteCodigo, setEstudianteCodigo] = useState('');
  const [modalidad, setModalidad] = useState<string>(MODALIDADES[0]);
  const [tipo, setTipo] = useState<string>(TIPOS_ATENCION[0]);
  const [fechaAtencion, setFechaAtencion] = useState(() =>
    new Date().toISOString().slice(0, 10),
  );
  const [notas, setNotas] = useState('');
  const [seguimiento, setSeguimiento] = useState(false);
  const [indicadores, setIndicadores] = useState<Indicadores>({});

  const [errores, setErrores] = useState<Record<string, string>>({});
  const [error, setError] = useState('');
  const [exito, setExito] = useState(false);
  const [enviando, setEnviando] = useState(false);

  function limpiar() {
    setEstudianteCodigo('');
    setModalidad(MODALIDADES[0]);
    setTipo(TIPOS_ATENCION[0]);
    setFechaAtencion(new Date().toISOString().slice(0, 10));
    setNotas('');
    setSeguimiento(false);
    setIndicadores({});
    setErrores({});
    setError('');
  }

  async function enviar(evento: FormEvent) {
    evento.preventDefault();
    if (enviando) return;

    const encontrados = validarAtencion({
      estudiante_codigo: estudianteCodigo,
      modalidad,
      tipo,
      fecha_atencion: fechaAtencion,
      notas,
      indicadores,
    });

    setErrores(encontrados);
    setError('');

    if (Object.keys(encontrados).length > 0) {
      document.getElementById(Object.keys(encontrados)[0])?.focus();
      return;
    }

    setEnviando(true);

    try {
      await registrarAtencion(
        {
          estudiante_codigo: estudianteCodigo.trim(),
          modalidad: modalidad as (typeof MODALIDADES)[number],
          tipo: tipo as (typeof TIPOS_ATENCION)[number],
          fecha_atencion: fechaAtencion
            ? new Date(fechaAtencion).toISOString()
            : undefined,
          indicadores: Object.keys(indicadores).length > 0 ? indicadores : undefined,
          notas: notas.trim() || undefined,
          seguimiento_requerido: seguimiento,
        },
        token ?? '',
      );

      limpiar();
      setExito(true);
    } catch (fallo) {
      setError(fallo instanceof Error ? fallo.message : 'No se pudo registrar la atención.');
    } finally {
      setEnviando(false);
    }
  }

  const completos = indicadoresCompletos(indicadores);

  return (
    <div className="flex flex-col gap-6">
      <div>
        <p className="text-xs font-semibold uppercase tracking-widest text-[var(--color-green)]">
          Registro único
        </p>
        <h2 className="mt-1 text-xl font-bold text-[var(--color-navy)]">
          Registrar atención a un estudiante
        </h2>
        <p className="mt-1 max-w-2xl text-sm">
          Una sola pantalla para el registro de la atención. Los indicadores son opcionales;
          con los siete completos el servicio asigna un perfil de agrupamiento.
        </p>
      </div>

      {exito ? (
        <div className="panel panel-body flex flex-col items-start gap-4" role="status">
          <CheckCircle2 size={40} className="text-[var(--color-green)]" />
          <div>
            <h3 className="text-lg font-bold text-[var(--color-navy)]">Atención registrada</h3>
            <p className="mt-1 text-sm">
              El servicio confirmó el registro. La atención ya forma parte de las
              estadísticas agregadas del panel.
            </p>
          </div>
          <button type="button" className="btn btn-secondary" onClick={() => setExito(false)}>
            Registrar otra atención
          </button>
        </div>
      ) : (
        <form className="panel panel-body flex flex-col gap-6" onSubmit={enviar} noValidate>
          <section>
            <h3 className="mb-4 text-base font-bold text-[var(--color-navy)]">
              Datos de la atención
            </h3>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="field">
                <label htmlFor="estudiante_codigo">
                  Código del estudiante <span className="required">*</span>
                </label>
                <input
                  id="estudiante_codigo"
                  name="estudiante_codigo"
                  disabled={enviando}
                  value={estudianteCodigo}
                  onChange={(evento) => setEstudianteCodigo(evento.target.value)}
                  aria-invalid={!!errores.estudiante_codigo}
                  aria-describedby={errores.estudiante_codigo ? 'estudiante_codigo-error' : undefined}
                />
                {errores.estudiante_codigo && (
                  <p className="field-error" id="estudiante_codigo-error">
                    {errores.estudiante_codigo}
                  </p>
                )}
              </div>

              <div className="field">
                <label htmlFor="fecha_atencion">Fecha de la atención</label>
                <input
                  id="fecha_atencion"
                  name="fecha_atencion"
                  type="date"
                  disabled={enviando}
                  value={fechaAtencion}
                  onChange={(evento) => setFechaAtencion(evento.target.value)}
                  aria-invalid={!!errores.fecha_atencion}
                />
                {errores.fecha_atencion && (
                  <p className="field-error">{errores.fecha_atencion}</p>
                )}
              </div>

              <div className="field">
                <label htmlFor="modalidad">
                  Modalidad <span className="required">*</span>
                </label>
                <select
                  id="modalidad"
                  name="modalidad"
                  disabled={enviando}
                  value={modalidad}
                  onChange={(evento) => setModalidad(evento.target.value)}
                  aria-invalid={!!errores.modalidad}
                >
                  {MODALIDADES.map((valor) => (
                    <option key={valor} value={valor}>
                      {ETIQUETAS_MODALIDAD[valor]}
                    </option>
                  ))}
                </select>
                {errores.modalidad && <p className="field-error">{errores.modalidad}</p>}
              </div>

              <div className="field">
                <label htmlFor="tipo">
                  Tipo de atención <span className="required">*</span>
                </label>
                <select
                  id="tipo"
                  name="tipo"
                  disabled={enviando}
                  value={tipo}
                  onChange={(evento) => setTipo(evento.target.value)}
                  aria-invalid={!!errores.tipo}
                >
                  {TIPOS_ATENCION.map((valor) => (
                    <option key={valor} value={valor}>
                      {ETIQUETAS_TIPO[valor]}
                    </option>
                  ))}
                </select>
                {errores.tipo && <p className="field-error">{errores.tipo}</p>}
              </div>
            </div>

            <div className="field mt-4">
              <label htmlFor="notas">Notas internas</label>
              <textarea
                id="notas"
                name="notas"
                rows={3}
                maxLength={2000}
                disabled={enviando}
                value={notas}
                onChange={(evento) => setNotas(evento.target.value)}
                aria-invalid={!!errores.notas}
                aria-describedby="notas-help"
              />
              <p className="mt-1 text-xs text-[var(--color-muted)]" id="notas-help">
                {notas.length}/2000 caracteres. No incluyas información clínica: este registro es
                de gestión de la atención.
              </p>
              {errores.notas && <p className="field-error">{errores.notas}</p>}
            </div>

            <label className="mt-4 flex items-center gap-2 text-sm">
              <input
                id="seguimiento_requerido"
                name="seguimiento_requerido"
                type="checkbox"
                disabled={enviando}
                checked={seguimiento}
                onChange={(evento) => setSeguimiento(evento.target.checked)}
              />
              Requiere seguimiento posterior
            </label>
          </section>

          <section>
            <div className="mb-1 flex flex-wrap items-center justify-between gap-3">
              <h3 className="text-base font-bold text-[var(--color-navy)]">
                Indicadores del estudiante
              </h3>
              <span className={`badge ${completos ? 'badge-bajo' : 'badge-neutro'}`}>
                {completos ? 'Perfil asignable' : 'Opcionales'}
              </span>
            </div>
            <p className="mb-4 text-xs">
              Si completas los siete indicadores, el modelo asigna un perfil de agrupamiento.
              Ese perfil es una estimación orientativa y no un diagnóstico clínico.
            </p>

            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {INDICADORES.map((definicion) => (
                <div className="field" key={definicion.key}>
                  <label htmlFor={definicion.key}>
                    {definicion.label} <span className="text-xs font-normal text-[var(--color-muted)]">({definicion.min}–{definicion.max})</span>
                  </label>
                  <input
                    id={definicion.key}
                    name={definicion.key}
                    type="number"
                    inputMode="decimal"
                    min={definicion.min}
                    max={definicion.max}
                    disabled={enviando}
                    value={indicadores[definicion.key] ?? ''}
                    onChange={(evento) => {
                      const bruto = evento.target.value;
                      setIndicadores((anterior) => {
                        const siguiente = { ...anterior };
                        if (bruto === '') delete siguiente[definicion.key];
                        else siguiente[definicion.key] = Number(bruto);
                        return siguiente;
                      });
                    }}
                    aria-invalid={!!errores[definicion.key]}
                    aria-describedby={`${definicion.key}-hint`}
                  />
                  <p className="mt-1 text-xs text-[var(--color-muted)]" id={`${definicion.key}-hint`}>
                    {definicion.hint}
                  </p>
                  {errores[definicion.key] && (
                    <p className="field-error">{errores[definicion.key]}</p>
                  )}
                </div>
              ))}
            </div>
          </section>

          {error && (
            <div className="error-banner" role="alert">
              {error}
            </div>
          )}

          <div className="flex flex-wrap justify-end gap-3 border-t border-[var(--color-border)] pt-5">
            <button className="btn btn-secondary" type="button" disabled={enviando} onClick={limpiar}>
              Limpiar
            </button>
            <button className="btn" type="submit" disabled={enviando}>
              <Save size={17} />
              {enviando ? 'Registrando.' : 'Registrar atención'}
            </button>
          </div>
        </form>
      )}
    </div>
  );
}
