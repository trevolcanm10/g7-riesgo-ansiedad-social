/**
 * Contexto de sesion del panel institucional.
 *
 * El token vive en memoria y en `sessionStorage`: se pierde al cerrar la
 * pestana. La contrasena nunca se guarda. Un token ya expirado no se
 * restaura: se trata como si no hubiera sesion.
 */
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { useNavigate } from 'react-router-dom';
import { registrarManejadorDeSesion } from '../services/api';
import { iniciarSesion } from '../services/panel';
import type { UsuarioSesion } from '../types';
import { esUsuarioSesion, MENSAJE_SESION_EXPIRADA, tokenExpirado } from '../validation';

const CLAVE_SESION = 'panel_sesion_v1';

interface EstadoSesion {
  token: string | null;
  usuario: UsuarioSesion | null;
  cargando: boolean;
  error: string;
  /** Aviso que la pantalla de inicio de sesion debe mostrar al llegar. */
  aviso: string;
}

interface ContextoSesion extends EstadoSesion {
  entrar: (email: string, password: string) => Promise<boolean>;
  salir: (aviso?: string) => void;
}

const Contexto = createContext<ContextoSesion | null>(null);

/**
 * Recupera la sesion guardada en la pestana anterior.
 *
 * Un token ya expirado no se restaura y se borra del almacenamiento de la
 * pestana.
 */
function sesionGuardada(): { token: string; usuario: UsuarioSesion } | null {
  try {
    const crudo = sessionStorage.getItem(CLAVE_SESION);
    if (!crudo) return null;

    const datos = JSON.parse(crudo) as { token?: unknown; usuario?: unknown };
    if (typeof datos.token !== 'string' || !datos.token) return null;
    if (!esUsuarioSesion(datos.usuario)) return null;

    if (tokenExpirado(datos.token)) {
      sessionStorage.removeItem(CLAVE_SESION);
      return null;
    }

    return { token: datos.token, usuario: datos.usuario };
  } catch {
    return null;
  }
}

/**
 * Provee el estado de sesion a toda la aplicacion.
 */
export function ProveedorSesion({ children }: { children: ReactNode }) {
  const guardada = useMemo(sesionGuardada, []);
  const navegar = useNavigate();

  const [token, setToken] = useState<string | null>(guardada?.token ?? null);
  const [usuario, setUsuario] = useState<UsuarioSesion | null>(guardada?.usuario ?? null);
  const [cargando, setCargando] = useState(false);
  const [error, setError] = useState('');
  const [aviso, setAviso] = useState('');

  const entrar = useCallback(async (email: string, password: string) => {
    setCargando(true);
    setError('');
    setAviso('');

    try {
      const resultado = await iniciarSesion(email, password);

      if (tokenExpirado(resultado.token)) {
        setError('La sesión recibida ya expiró. Vuelve a iniciar sesión.');
        return false;
      }

      setToken(resultado.token);
      setUsuario(resultado.usuario);
      sessionStorage.setItem(
        CLAVE_SESION,
        JSON.stringify({ token: resultado.token, usuario: resultado.usuario }),
      );
      return true;
    } catch (fallo) {
      setError(fallo instanceof Error ? fallo.message : 'No se pudo iniciar sesión.');
      // Un 401 del propio inicio de sesion ya se explica con el error.
      setAviso('');
      return false;
    } finally {
      setCargando(false);
    }
  }, []);

  const salir = useCallback((mensaje?: string) => {
    setToken(null);
    setUsuario(null);
    setAviso(mensaje ?? '');
    sessionStorage.removeItem(CLAVE_SESION);
  }, []);

  /**
   * Cierra la sesion cuando el servicio responde 401.
   *
   * El manejador se registra aqui y no en `api.ts` para que el cliente HTTP
   * no dependa de React ni del enrutado.
   */
  useEffect(() => {
    registrarManejadorDeSesion(() => {
      salir(MENSAJE_SESION_EXPIRADA);
      navegar('/login', { replace: true });
    });

    return () => registrarManejadorDeSesion(null);
  }, [salir, navegar]);

  const valor = useMemo<ContextoSesion>(
    () => ({ token, usuario, cargando, error, aviso, entrar, salir }),
    [token, usuario, cargando, error, aviso, entrar, salir],
  );

  return <Contexto.Provider value={valor}>{children}</Contexto.Provider>;
}

/**
 * Devuelve el estado de sesion. Lanza si se usa fuera del proveedor.
 */
export function useSesion(): ContextoSesion {
  const contexto = useContext(Contexto);
  if (!contexto) throw new Error('useSesion debe usarse dentro de ProveedorSesion.');
  return contexto;
}
