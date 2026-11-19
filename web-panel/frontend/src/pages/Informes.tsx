/**
 * Vista de generacion de informes mensuales.
 */
import { useState } from 'react';
import { Download, FileSpreadsheet } from 'lucide-react';
import { useSesion } from '../app/AuthContext';
import { descargarInforme } from '../services/panel';
import { mesesDisponibles } from '../validation';

export default function PaginaInformes() {
  const { token } = useSesion();

  const [periodo, setPeriodo] = useState<string>(mesesDisponibles()[0] ?? '');
  const [descargando, setDescargando] = useState(false);
  const [error, setError] = useState('');
  const [ultimo, setUltimo] = useState<string>('');

  async function descargar() {
    if (!token || descargando) return;

    setDescargando(true);
    setError('');

    try {
      const { nombre, blob } = await descargarInforme(periodo || null, token);

      const url = URL.createObjectURL(blob);
      const enlace = document.createElement('a');
      enlace.href = url;
      enlace.download = nombre;
      document.body.appendChild(enlace);
      enlace.click();
      document.body.removeChild(enlace);
      URL.revokeObjectURL(url);

      setUltimo(nombre);
    } catch (fallo) {
      setError(fallo instanceof Error ? fallo.message : 'No se pudo generar el informe.');
    } finally {
      setDescargando(false);
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <p className="text-xs font-semibold uppercase tracking-widest text-[var(--color-green)]">
          Informes
        </p>
        <h2 className="mt-1 text-xl font-bold text-[var(--color-navy)]">
          Informe mensual de atenciones
        </h2>
        <p className="mt-1 max-w-2xl text-sm">
          Descarga el agregado de atenciones del periodo en formato CSV, listo para abrir en
          Excel.
        </p>
      </div>

      <section className="panel panel-body flex max-w-2xl flex-col gap-5">
        <div className="flex items-start gap-3">
          <FileSpreadsheet size={22} className="mt-0.5 shrink-0 text-[var(--color-green)]" />
          <div>
            <h3 className="text-base font-bold text-[var(--color-navy)]">Descargar informe</h3>
            <p className="mt-1 text-sm">
              El informe contiene el total de atenciones por tipo y modalidad. No incluye
              identificadores de estudiantes y omite los grupos con menos de cinco atenciones.
            </p>
          </div>
        </div>

        <div className="field max-w-xs">
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

        {error && (
          <div className="error-banner" role="alert">
            {error}
          </div>
        )}

        {ultimo && !error && (
          <div className="notice-privacidad" role="status">
            <p className="text-sm">
              Se descargó <strong className="font-semibold">{ultimo}</strong>.
            </p>
          </div>
        )}

        <div>
          <button className="btn" type="button" onClick={descargar} disabled={descargando}>
            <Download size={17} />
            {descargando ? 'Generando informe.' : 'Descargar informe CSV'}
          </button>
        </div>
      </section>
    </div>
  );
}
