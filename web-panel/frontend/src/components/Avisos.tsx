/**
 * Aviso obligatorio de IA responsable.
 *
 * Se muestra en toda vista que exponga resultados del modelo de
 * agrupamiento. Los perfiles son estimaciones orientativas y no
 * constituyen un diagnostico clinico.
 */
import { Brain } from 'lucide-react';

/**
 * Banner de aviso sobre resultados de IA.
 */
export function AvisoIA({ nota }: { nota?: string }) {
  return (
    <div className="notice-ia" role="note">
      <Brain size={20} className="mt-0.5 shrink-0" />
      <p className="text-sm">
        {nota ??
          'Las estimaciones son orientativas y no constituyen un diagnóstico clínico. Los perfiles provienen de un dataset sintético y no describen poblaciones reales.'}
      </p>
    </div>
  );
}

/**
 * Aviso sobre la regla de privacidad k=5.
 */
export function AvisoPrivacidad({ omitidos }: { omitidos: number }) {
  if (omitidos <= 0) return null;

  return (
    <div className="notice-privacidad" role="status">
      <p className="text-sm">
        <strong className="font-semibold">
          {omitidos} {omitidos === 1 ? 'grupo oculto' : 'grupos ocultos'}
        </strong>{' '}
        por la regla de privacidad: los grupos con menos de cinco estudiantes no se muestran.
      </p>
    </div>
  );
}
