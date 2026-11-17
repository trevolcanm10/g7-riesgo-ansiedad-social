/**
 * Pantalla de reserva para los modulos que conectaran otros microservicios.
 *
 * `/orientacion`, `/citas` y `/agenda` son trabajo futuro: todavia no hay
 * microservicio conectado. Cuando su microservicio este listo, se sustituye
 * este componente por la pantalla real sin tocar el enrutado ni la navegacion
 * lateral.
 */
import { Construction } from 'lucide-react';
import { NAVEGACION } from '../app/navigation';

export default function PaginaPreparada({ ruta }: { ruta: string }) {
  const entrada = NAVEGACION.find((item) => item.ruta === ruta);

  return (
    <div className="panel panel-body flex max-w-2xl flex-col items-start gap-4">
      <span className="flex h-12 w-12 items-center justify-center rounded-full bg-[var(--color-navy-tint)] text-[var(--color-navy)]">
        <Construction size={24} />
      </span>

      <div>
        <h2 className="text-xl font-bold text-[var(--color-navy)]">
          {entrada?.etiqueta ?? 'Modulo en preparacion'}
        </h2>
        <p className="mt-1 text-sm">{entrada?.descripcion ?? ''}</p>
      </div>

      <p className="text-sm">
        Este modulo es trabajo futuro: todavia no esta implementado. La ruta queda reservada
        en el panel, pero todavia no hay ninguna pantalla ni microservicio conectado
        detras.
      </p>

      <div className="notice">
        <p className="text-sm">
          <strong className="font-semibold">Estado: pendiente de implementacion. </strong>
          La estructura de rutas, la barra lateral y la proteccion de sesion ya estan
          preparadas para este modulo. Cuando el microservicio correspondiente este
          disponible, su pantalla se conectara aqui sin modificar la navegacion ni el
          enrutado.
        </p>
      </div>
    </div>
  );
}
