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
 *
 * Solo se publica que se ocultaron grupos: el numero exacto de grupos
 * ocultos permitiria deducir el tamano de lo que se esconde.
 */
export function AvisoPrivacidad({ grupos_omitidos }: { grupos_omitidos: boolean }) {
  if (!grupos_omitidos) return null;

  return (
    <div className="notice-privacidad" role="status">
      <p className="text-sm">
        <strong className="font-semibold">
          Se ocultaron grupos con menos de cinco estudiantes por la regla de privacidad
        </strong>
      </p>
    </div>
  );
}
