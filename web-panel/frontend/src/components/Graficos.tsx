/**
 * Componentes de visualizacion de datos.
 *
 * Los graficos se dibujan con SVG a mano: el proyecto no depende de una
 * libreria de charts, igual que la app movil de Flutter.
 */
import type { GrupoEstadistico } from '../types';

/**
 * Tarjeta de indicador numerico.
 */
export function TarjetaIndicador({
  etiqueta,
  valor,
  detalle,
  icono,
}: {
  etiqueta: string;
  valor: string | number;
  detalle?: string;
  icono?: React.ReactNode;
}) {
  return (
    <div className="panel p-5">
      <div className="flex items-start justify-between gap-3">
        <p className="text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">
          {etiqueta}
        </p>
        {icono && <span className="text-[var(--color-green)]">{icono}</span>}
      </div>
      <p className="mt-2 text-3xl font-bold text-[var(--color-navy)]">{valor}</p>
      {detalle && <p className="mt-1 text-xs text-[var(--color-muted)]">{detalle}</p>}
    </div>
  );
}

/**
 * Grafico de barras horizontales.
 *
 * Las barras se dibujan con divs y anchos proporcionales: no necesita SVG ni
 * librerias, y escala bien con cualquier cantidad de grupos.
 */
export function GraficoBarras({
  grupos,
  etiquetaVacia = 'Sin datos para mostrar.',
}: {
  grupos: GrupoEstadistico[];
  etiquetaVacia?: string;
}) {
  if (grupos.length === 0) {
    return <p className="py-6 text-center text-sm text-[var(--color-muted)]">{etiquetaVacia}</p>;
  }

  const maximo = Math.max(...grupos.map((grupo) => grupo.n), 1);

  return (
    <ul className="flex flex-col gap-3">
      {grupos.map((grupo) => {
        const porcentaje = Math.round((grupo.n / maximo) * 100);
        return (
          <li key={grupo.etiqueta} className="flex flex-col gap-1.5">
            <div className="flex items-baseline justify-between gap-3 text-sm">
              <span className="font-medium text-[var(--color-navy)]">{grupo.etiqueta}</span>
              <span className="tabular-nums text-[var(--color-muted)]">{grupo.n}</span>
            </div>
            <div
              className="h-2.5 w-full overflow-hidden rounded-full bg-slate-200"
              role="img"
              aria-label={`${grupo.etiqueta}: ${grupo.n} atenciones`}
            >
              <div
                className="h-full rounded-full bg-[var(--color-navy)] transition-[width] duration-500"
                style={{ width: `${porcentaje}%` }}
              />
            </div>
          </li>
        );
      })}
    </ul>
  );
}

/**
 * Grafico de anillo (donut) conSVG.
 *
 * Cada segmento se dibuja con `stroke-dasharray` sobre una circunferencia.
 */
export function GraficoAnillo({
  grupos,
  total,
}: {
  grupos: GrupoEstadistico[];
  total: number;
}) {
  if (grupos.length === 0 || total <= 0) {
    return <p className="py-6 text-center text-sm text-[var(--color-muted)]">Sin datos para mostrar.</p>;
  }

  const radio = 54;
  const circunferencia = 2 * Math.PI * radio;
  const paleta = ['#0b456d', '#13765f', '#4c8adc', '#9a6b0c', '#a3322b', '#12618f'];

  let acumulado = 0;

  return (
    <div className="flex flex-wrap items-center justify-center gap-8">
      <svg
        width="140"
        height="140"
        viewBox="0 0 140 140"
        role="img"
        aria-label={`Distribución de ${total} atenciones`}
      >
        <g transform="rotate(-90 70 70)">
          <circle cx="70" cy="70" r={radio} fill="none" stroke="#e2e8ed" strokeWidth="18" />
          {grupos.map((grupo, indice) => {
            const proporcion = grupo.n / total;
            const largo = proporcion * circunferencia;
            const desfase = -acumulado * circunferencia;
            acumulado += proporcion;

            return (
              <circle
                key={grupo.etiqueta}
                cx="70"
                cy="70"
                r={radio}
                fill="none"
                stroke={paleta[indice % paleta.length]}
                strokeWidth="18"
                strokeDasharray={`${largo} ${circunferencia - largo}`}
                strokeDashoffset={desfase}
              />
            );
          })}
        </g>
        <text
          x="70"
          y="70"
          textAnchor="middle"
          dominantBaseline="central"
          className="fill-[var(--color-navy)] text-2xl font-bold"
        >
          {total}
        </text>
      </svg>

      <ul className="flex flex-col gap-2 text-sm">
        {grupos.map((grupo, indice) => (
          <li key={grupo.etiqueta} className="flex items-center gap-2.5">
            <span
              className="h-3 w-3 shrink-0 rounded-sm"
              style={{ background: paleta[indice % paleta.length] }}
              aria-hidden="true"
            />
            <span className="text-[var(--color-muted)]">{grupo.etiqueta}</span>
            <span className="font-semibold tabular-nums text-[var(--color-navy)]">
              {grupo.n}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
