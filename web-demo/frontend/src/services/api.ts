import { config } from '../config';
import type { Indicator, Registration } from '../types';
import { isPrediction } from '../validation';
export function httpError(status: number, retry?: string | null) {
  if (status === 400) return 'Revisa los datos enviados. El servicio rechazó la solicitud.';
  if (status === 401 || status === 403) return 'El acceso al servicio fue rechazado. Solicita al responsable que revise la configuración de acceso.';
  if (status === 404) return 'No se encontró la ruta del servicio. Contacta al responsable de la plataforma.';
  if (status === 409) return 'Ya existe un estudiante con ese correo o código.';
  if (status === 429) return `Se alcanzó el límite de solicitudes. Inténtalo más tarde.${retry && /^\d+$/.test(retry) ? ` Espera ${retry} segundos.` : ''}`;
  if (status >= 500) return 'El servicio no está disponible en este momento. Inténtalo más tarde.';
  return 'No se pudo completar la solicitud. Inténtalo de nuevo.';
}
async function post(path: string, body: unknown): Promise<unknown> {
  if (!config.key) throw new Error('El servicio aún no está configurado. Solicita al responsable que configure el acceso para la demostración.');
  const base = new URL(config.baseUrl);
  if (base.protocol !== 'https:' || !base.hostname.endsWith('.azure-api.net') || !path.startsWith('/') || path.startsWith('//')) throw new Error('La configuración de Azure API Management no es válida.');
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 25000);
  try {
    const response = await fetch(`${config.baseUrl}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Ocp-Apim-Subscription-Key': config.key }, body: JSON.stringify(body), signal: controller.signal });
    if (!response.ok) throw new Error(httpError(response.status, response.headers.get('Retry-After')));
    try { return await response.json(); } catch { throw new Error('El servicio devolvió una respuesta inválida. Inténtalo más tarde.'); }
  } catch (error) {
    if (error instanceof TypeError) throw new Error('No se pudo conectar con el servicio. Revisa tu conexión o consulta al responsable de la plataforma.');
    if (error instanceof Error && error.name === 'AbortError') throw new Error('El servicio tardó demasiado en responder. Inténtalo de nuevo.');
    throw error;
  } finally { clearTimeout(timer); }
}
export async function registerStudent(data: Registration) {
  const value = await post(config.usersPath, data);
  if (!value || typeof value !== 'object' || typeof (value as { id?: unknown }).id !== 'number') throw new Error('No se pudo confirmar el registro: respuesta inválida del servicio.');
}
export async function predict(data: Record<Indicator, number>) {
  const value = await post(config.predictionPath, data);
  if (!isPrediction(value)) throw new Error('El servicio devolvió un resultado inválido. No se puede mostrar una estimación.');
  return value;
}
