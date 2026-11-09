import { config } from '../config';
import { SolicitudOrientacion } from '../types/orientacion';

// Endpoint predeterminado si no está en config todavía
const orientacionPath = import.meta.env.VITE_APIM_ORIENTACION_PATH || '/orientacion/solicitudes';

export const obtenerSolicitudes = async (
  estado?: string,
  prioridad?: string
): Promise<SolicitudOrientacion[]> => {
  const params = new URLSearchParams();
  if (estado) params.append('estado', estado);
  if (prioridad) params.append('prioridad', prioridad);

  const query = params.toString() ? `?${params.toString()}` : '';
  const url = `${config.baseUrl}${orientacionPath}${query}`;

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
      'Ocp-Apim-Subscription-Key': config.key,
    },
  });

  if (!response.ok) {
    throw new Error('Error al obtener las solicitudes');
  }
  return response.json();
};

export const atenderSolicitud = async (
  id: number,
  data: {
    respuesta_escrita: string;
    atendido_por: string;
    tema_confirmado?: string;
    prioridad_confirmada?: string;
  }
): Promise<SolicitudOrientacion> => {
  const response = await fetch(`${config.baseUrl}${orientacionPath}/${id}/atender`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'Ocp-Apim-Subscription-Key': config.key,
    },
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    throw new Error('Error al atender la solicitud');
  }
  return response.json();
};
