/**
 * Estructura de navegacion del panel.
 *
 * Las rutas `/orientacion`, `/citas` y `/agenda` quedan preparadas: otros
 * microservicios conectaran sus pantallas ahi.
 */
export interface EntradaNav {
  ruta: string;
  etiqueta: string;
  descripcion: string;
  /** Icono lucide-react. */
  icono: 'panel' | 'registro' | 'informe' | 'orientacion' | 'citas' | 'agenda';
  /** Una ruta preparada todavia no tiene microservicio conectado. */
  preparado?: boolean;
}

export const NAVEGACION: EntradaNav[] = [
  {
    ruta: '/',
    etiqueta: 'Dashboard',
    descripcion: 'Estadísticas anonimizadas e indicadores del modelo.',
    icono: 'panel',
  },
  {
    ruta: '/atencion',
    etiqueta: 'Registro de atención',
    descripcion: 'Registrar una atención a un estudiante.',
    icono: 'registro',
  },
  {
    ruta: '/informes',
    etiqueta: 'Informes',
    descripcion: 'Descargar el informe mensual en CSV.',
    icono: 'informe',
  },
  {
    ruta: '/orientacion',
    etiqueta: 'Orientación',
    descripcion: 'Bandeja de solicitudes de orientación confidencial.',
    icono: 'orientacion',
    preparado: true,
  },
  {
    ruta: '/citas',
    etiqueta: 'Citas',
    descripcion: 'Agenda de citas del personal institucional.',
    icono: 'citas',
    preparado: true,
  },
  {
    ruta: '/agenda',
    etiqueta: 'Agenda',
    descripcion: 'Seguimiento de acciones y compromisos.',
    icono: 'agenda',
    preparado: true,
  },
];

/** Titulo de cada ruta para el encabezado de la pagina. */
export const TITULOS: Record<string, string> = {
  '/': 'Dashboard analítico',
  '/atencion': 'Registro de atención',
  '/informes': 'Informes mensuales',
  '/orientacion': 'Orientación confidencial',
  '/citas': 'Citas',
  '/agenda': 'Agenda',
};
