/**
 * Contexto de sesion del panel institucional.
 *
 * El token vive en memoria y en `sessionStorage`: se pierde al cerrar la
 * pestana. La contrasena nunca se guarda.
 */
import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { iniciarSesion } from '../services/panel';
import type { UsuarioInstitucional } from '../types';

const CLAVE_SESION = 'panel_sesion_v1';

interface EstadoSesion {
  token: string | null;
  usuario: UsuarioInstitucional | null;
  cargando: boolean;
  error: string;
}

interface ContextoSesion extends EstadoSesion {
  entrar: (email: string, password: string) => Promise<boolean>;
  salir: () => void;
}

const Contexto = createContext<ContextoSesion | null>(null);

/**
 * Recupera la sesion guardada en la pestana anterior.
 */
function sesionGuardada(): { token: string; usuario: UsuarioInstitucional } | null {
  try {
    const crudo = sessionStorage.getItem(CLAVE_SESION);
    if (!crudo) return null;

    const datos = JSON.parse(crudo) as { token?: unknown; usuario?: unknown };
    if (typeof datos.token !== 'string' || !datos.usuario) return null;

    return { token: datos.token, usuario: datos.usuario as UsuarioInstitucional };
  } catch {
    return null;
  }
}

/**
 * Provee el estado de sesion a toda la aplicacion.
 */
export function ProveedorSesion({ children }: { children: ReactNode }) {
  const guardada = useMemo(sesionGuardada, []);

  const [token, setToken] = useState<string | null>(guardada?.token ?? null);
  const [usuario, setUsuario] = useState<UsuarioInstitucional | null>(
    guardada?.usuario ?? null,
  );
  const [cargando, setCargando] = useState(false);
  const [error, setError] = useState('');

  const entrar = useCallback(async (email: string, password: string) => {
    setCargando(true);
    setError('');

    try {
      const resultado = await iniciarSesion(email, password);
      setToken(resultado.token);
      setUsuario(resultado.usuario);
      sessionStorage.setItem(
        CLAVE_SESION,
        JSON.stringify({ token: resultado.token, usuario: resultado.usuario }),
      );
      return true;
    } catch (fallo) {
      setError(fallo instanceof Error ? fallo.message : 'No se pudo iniciar sesión.');
      return false;
    } finally {
      setCargando(false);
    }
  }, []);

  const salir = useCallback(() => {
    setToken(null);
    setUsuario(null);
    sessionStorage.removeItem(CLAVE_SESION);
  }, []);

  const valor = useMemo<ContextoSesion>(
    () => ({ token, usuario, cargando, error, entrar, salir }),
    [token, usuario, cargando, error, entrar, salir],
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
