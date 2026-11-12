/**
 * Ruta protegida: exige una sesion institucional valida.
 */
import { Navigate, useLocation } from 'react-router-dom';
import { useSesion } from './AuthContext';

/**
 * Redirige al inicio de sesion si no hay token, o al panel si el rol no
 * tiene permiso.
 */
export function RutaProtegida({ children }: { children: React.ReactNode }) {
  const { token } = useSesion();
  const ubicacion = useLocation();

  if (!token) {
    return <Navigate to="/login" replace state={{ desde: ubicacion.pathname }} />;
  }

  return <>{children}</>;
}
