/**
 * Contenedor principal del panel: barra lateral de navegacion, encabezado
 * con la identidad del usuario y area de contenido.
 */
import { useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import {
  CalendarDays,
  ClipboardList,
  FileBarChart,
  LayoutDashboard,
  LogOut,
  Menu,
  MessageSquareHeart,
  X,
} from 'lucide-react';
import { useSesion } from './AuthContext';
import { NAVEGACION, TITULOS } from './navigation';

/** Iconos de la navegacion lateral. */
const ICONOS = {
  panel: LayoutDashboard,
  registro: ClipboardList,
  informe: FileBarChart,
  orientacion: MessageSquareHeart,
  citas: CalendarDays,
  agenda: ClipboardList,
};

/**
 * Devuelve el nombre completo del usuario institucional.
 */
function nombreCompleto(usuario: { names: string; surnames: string }): string {
  return `${usuario.names} ${usuario.surnames}`.trim();
}

/**
 * Barra lateral de navegacion del panel.
 */
export function Sidebar({ abierto, alCerrar }: { abierto: boolean; alCerrar: () => void }) {
  return (
    <>
      {abierto && (
        <div
          className="fixed inset-0 z-30 bg-slate-900/40 lg:hidden"
          onClick={alCerrar}
          aria-hidden="true"
        />
      )}

      <aside
        className={`fixed inset-y-0 left-0 z-40 flex w-64 flex-col border-r border-[var(--color-border)] bg-[var(--color-surface)] transition-transform lg:static lg:translate-x-0 ${
          abierto ? 'translate-x-0' : '-translate-x-full'
        }`}
        aria-label="Navegación del panel"
      >
        <div className="flex items-center justify-between gap-3 border-b border-[var(--color-border)] px-5 py-4">
          <div>
            <p className="text-sm font-bold text-[var(--color-navy)]">Bienestar Estudiantil</p>
            <p className="text-xs text-[var(--color-muted)]">Panel institucional</p>
          </div>
          <button
            type="button"
            className="rounded p-1 text-[var(--color-muted)] lg:hidden"
            onClick={alCerrar}
            aria-label="Cerrar navegación"
          >
            <X size={20} />
          </button>
        </div>

        <nav className="flex-1 overflow-y-auto p-3">
          <ul className="flex flex-col gap-1">
            {NAVEGACION.map((entrada) => {
              const Icono = ICONOS[entrada.icono];
              return (
                <li key={entrada.ruta}>
                  <NavLink
                    to={entrada.ruta}
                    end={entrada.ruta === '/'}
                    onClick={alCerrar}
                    className={({ isActive }) =>
                      `flex items-start gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors ${
                        isActive
                          ? 'bg-[var(--color-navy-tint)] font-semibold text-[var(--color-navy)]'
                          : 'text-[var(--color-muted)] hover:bg-slate-100 hover:text-[var(--color-navy)]'
                      }`
                    }
                  >
                    <Icono size={18} className="mt-0.5 shrink-0" />
                    <span className="flex flex-col gap-0.5">
                      <span className="flex items-center gap-2">
                        {entrada.etiqueta}
                        {entrada.preparado && (
                          <span className="badge badge-neutro text-[0.65rem]">Próximamente</span>
                        )}
                      </span>
                      <span className="text-xs leading-snug opacity-80">{entrada.descripcion}</span>
                    </span>
                  </NavLink>
                </li>
              );
            })}
          </ul>
        </nav>

        <div className="border-t border-[var(--color-border)] px-5 py-4">
          <p className="text-xs leading-relaxed text-[var(--color-muted)]">
            Las estimaciones son orientativas y no constituyen un diagnóstico clínico.
          </p>
        </div>
      </aside>
    </>
  );
}

/**
 * Encabezado con la identidad de la persona y el cierre de sesion.
 */
export function TopBar({ alAbrirMenu }: { alAbrirMenu: () => void }) {
  const { usuario, salir } = useSesion();
  const ubicacion = useLocation();

  useEffect(() => {
    document.title = `${TITULOS[ubicacion.pathname] ?? 'Panel'} · Panel Institucional`;
    window.scrollTo(0, 0);
  }, [ubicacion.pathname]);

  return (
    <header className="sticky top-0 z-20 flex items-center gap-4 border-b border-[var(--color-border)] bg-[var(--color-surface)] px-4 py-3 lg:px-7">
      <button
        type="button"
        className="rounded p-1.5 text-[var(--color-muted)] lg:hidden"
        onClick={alAbrirMenu}
        aria-label="Abrir navegación"
      >
        <Menu size={22} />
      </button>

      <div className="min-w-0 flex-1">
        <h1 className="truncate text-lg font-bold text-[var(--color-navy)]">
          {TITULOS[ubicacion.pathname] ?? 'Panel institucional'}
        </h1>
      </div>

      {usuario && (
        <div className="flex items-center gap-3">
          <div className="hidden text-right sm:block">
            <p className="text-sm font-semibold text-[var(--color-navy)]">
              {nombreCompleto(usuario)}
            </p>
            <p className="text-xs text-[var(--color-muted)]">{usuario.role}</p>
          </div>
          <button
            type="button"
            className="btn btn-secondary btn-sm"
            onClick={salir}
            aria-label="Cerrar sesión"
          >
            <LogOut size={16} />
            <span className="hidden sm:inline">Salir</span>
          </button>
        </div>
      )}
    </header>
  );
}

/**
 * Contenedor principal: barra lateral, encabezado y area de contenido.
 */
export function AppShell() {
  const [menuAbierto, setMenuAbierto] = useState(false);

  return (
    <div className="min-h-screen lg:flex">
      <a className="skip" href="#contenido">
        Saltar al contenido
      </a>

      <Sidebar abierto={menuAbierto} alCerrar={() => setMenuAbierto(false)} />

      <div className="flex min-w-0 flex-1 flex-col">
        <TopBar alAbrirMenu={() => setMenuAbierto(true)} />
        <main id="contenido" tabIndex={-1} className="flex-1 p-4 lg:p-7">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
