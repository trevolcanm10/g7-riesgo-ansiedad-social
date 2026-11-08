import { ArrowRight, Home, Info, Leaf } from 'lucide-react';
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom';
import { useEffect } from 'react';
export const disclaimer = 'Este resultado es una estimación orientativa y no constituye un diagnóstico médico ni psicológico.';
export function Notice() { return <div className="notice"><Info size={22}/><p>Esta plataforma ofrece una estimación orientativa y no reemplaza una evaluación profesional.</p></div>; }
export function Breadcrumb({ current }: { current: string }) { return <nav className="breadcrumb" aria-label="Ruta de navegación"><Link to="/"><Home size={17}/> Inicio</Link><span>›</span><span aria-current="page">{current}</span></nav>; }
export function ActionLink({ to, children, secondary = false }: { to: string; children: React.ReactNode; secondary?: boolean }) { return <Link className={`button ${secondary ? 'secondary' : ''}`} to={to}>{children}{!secondary && <ArrowRight size={18}/>}</Link>; }
export function Layout() {
  const location = useLocation();
  useEffect(() => { window.scrollTo(0, 0); document.title = `${location.pathname === '/' ? 'Inicio' : location.pathname === '/registro' ? 'Registro' : location.pathname === '/resultado' ? 'Resultado' : 'Evaluación'} · Bienestar Estudiantil`; document.getElementById('main')?.focus(); }, [location.pathname]);
  return <><a className="skip" href="#main">Saltar al contenido</a><header className="site-header"><div className="header-inner"><Link to="/" className="brand"><span className="brand-icon"><Leaf size={42} strokeWidth={1.5}/></span><span><strong>Bienestar Estudiantil</strong><small>Prevención del Riesgo de Ansiedad</small></span></Link><nav aria-label="Navegación principal"><NavLink to="/" end>Inicio</NavLink><NavLink to="/registro">Registro</NavLink><NavLink to="/evaluacion" className={({ isActive }) => isActive || location.pathname === '/resultado' ? 'active' : ''}>Evaluación</NavLink></nav></div></header><main id="main" tabIndex={-1}><Outlet/></main><footer><div className="container footer-inner"><span><Leaf size={17}/> Bienestar Estudiantil</span><span>Demostración académica · Una herramienta orientativa</span></div></footer></>;
}
