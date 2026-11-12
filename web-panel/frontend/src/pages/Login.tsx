/**
 * Pantalla de inicio de sesion del panel institucional.
 */
import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { Leaf, LogIn } from 'lucide-react';
import { useSesion } from '../app/AuthContext';
import { validarCredenciales } from '../validation';

export default function PaginaLogin() {
  const { entrar, cargando, error } = useSesion();
  const navegar = useNavigate();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [errores, setErrores] = useState<Record<string, string>>({});

  async function enviar(evento: FormEvent) {
    evento.preventDefault();
    if (cargando) return;

    const encontrados = validarCredenciales(email, password);
    setErrores(encontrados);

    if (Object.keys(encontrados).length > 0) {
      document.getElementById(
        Object.keys(encontrados)[0] === 'email' ? 'email' : 'password',
      )?.focus();
      return;
    }

    const ok = await entrar(email, password);
    if (ok) navegar('/', { replace: true });
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--color-canvas)] px-4 py-10">
      <div className="w-full max-w-md">
        <div className="mb-6 flex flex-col items-center text-center">
          <span className="flex h-14 w-14 items-center justify-center rounded-full bg-[var(--color-green-tint)] text-[var(--color-green)]">
            <Leaf size={30} strokeWidth={1.5} />
          </span>
          <h1 className="mt-4 text-2xl font-bold text-[var(--color-navy)]">
            Panel Institucional
          </h1>
          <p className="mt-1 text-sm text-[var(--color-muted)]">
            Acceso para el personal de la unidad de bienestar estudiantil.
          </p>
        </div>

        <form className="panel panel-body flex flex-col gap-4" onSubmit={enviar} noValidate>
          <div className="field">
            <label htmlFor="email">
              Correo institucional <span className="required">*</span>
            </label>
            <input
              id="email"
              name="email"
              type="email"
              autoComplete="username"
              disabled={cargando}
              value={email}
              onChange={(evento) => setEmail(evento.target.value)}
              aria-invalid={!!errores.email}
              aria-describedby={errores.email ? 'email-error' : undefined}
            />
            {errores.email && (
              <p className="field-error" id="email-error">
                {errores.email}
              </p>
            )}
          </div>

          <div className="field">
            <label htmlFor="password">
              Contraseña <span className="required">*</span>
            </label>
            <input
              id="password"
              name="password"
              type="password"
              autoComplete="current-password"
              disabled={cargando}
              value={password}
              onChange={(evento) => setPassword(evento.target.value)}
              aria-invalid={!!errores.password}
              aria-describedby={errores.password ? 'password-error' : undefined}
            />
            {errores.password && (
              <p className="field-error" id="password-error">
                {errores.password}
              </p>
            )}
          </div>

          {error && (
            <div className="error-banner" role="alert">
              {error}
            </div>
          )}

          <button className="btn w-full" type="submit" disabled={cargando}>
            <LogIn size={17} />
            {cargando ? 'Verificando acceso.' : 'Iniciar sesión'}
          </button>

          <p className="text-xs leading-relaxed text-[var(--color-muted)]">
            El acceso está reservado a los roles institutionales. Los datos que muestra el
            panel están agregados y omiten los grupos con menos de cinco estudiantes.
          </p>
        </form>
      </div>
    </div>
  );
}
