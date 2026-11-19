/**
 * Ruta protegida: exige una sesion institucional valida.
 */
import { Navigate, useLocation } from 'react-router-dom';
import { useSesion } from './AuthContext';
import { estadoRedireccion, evaluarAcceso } from '../validation';

/**
 * Redirige al inicio de sesion si no hay token, o al panel si el rol no
 * tiene permiso. El motivo del rechazo viaja en el estado de navegacion para
 * que el inicio de sesion pueda explicarlo.
 */
export function RutaProtegida({ children }: { children: React.ReactNode }) {
  const { token, usuario } = useSesion();
  const ubicacion = useLocation();

  const decision = evaluarAcceso(token, usuario?.role);

  if (!decision.permitido) {
    return (
      <Navigate
        to="/login"
        replace
        state={estadoRedireccion(decision, ubicacion.pathname)}
      />
    );
  }

  return <>{children}</>;
}
