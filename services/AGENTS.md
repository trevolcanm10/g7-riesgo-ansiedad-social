# AGENTS.md

## 1. Contexto del backend

Esta carpeta contiene los diferentes microservicios que conforman el backend del proyecto.

Cada microservicio representa una unidad independiente, encargada de una responsabilidad específica del negocio.

Los microservicios pueden utilizar diferentes lenguajes de programación, frameworks, bases de datos y tecnologías, según las necesidades de su implementación.

## 2. Arquitectura de microservicios

1. Cada microservicio debe mantener una responsabilidad de negocio bien definida.
2. Mantener la independencia y el bajo acoplamiento entre microservicios.
3. Evitar compartir directamente entidades, modelos de dominio o estructuras internas entre servicios.
4. Cada microservicio debe gestionar su propia lógica de negocio y sus responsabilidades.
5. Evitar dependencias directas sobre la implementación interna de otros microservicios.
6. Mantener contratos de comunicación claros y definidos entre servicios.
7. Considerar la disponibilidad y los posibles fallos de comunicación de otros microservicios.

## 3. Domain-Driven Design (DDD)

Cuando un microservicio implemente DDD, debe respetar los siguientes principios:

1. Organizar el código alrededor del dominio y sus reglas de negocio.
2. Identificar y mantener las entidades, objetos de valor y agregados correspondientes al dominio.
3. Mantener las reglas de negocio dentro del dominio y evitar ubicarlas en componentes externos.
4. Utilizar repositorios para abstraer la persistencia de las entidades del dominio.
5. Implementar los casos de uso en la capa de aplicación.
6. Evitar que el dominio dependa de frameworks, bases de datos o servicios externos.
7. Mantener un lenguaje ubicuo coherente con el contexto del negocio.

## 4. Arquitectura Hexagonal

Cuando un microservicio implemente Arquitectura Hexagonal, debe respetar las siguientes reglas:

1. Mantener separadas las responsabilidades del dominio, aplicación e infraestructura.
2. Definir puertos mediante interfaces o contratos que representen las necesidades de la aplicación.
3. Implementar los adaptadores necesarios para conectar la aplicación con sistemas externos.
4. Las implementaciones de repositorios y servicios externos deben permanecer en infraestructura.
5. Los casos de uso deben depender de abstracciones y no de implementaciones concretas.
6. Evitar que la lógica de negocio dependa de frameworks, bases de datos o mecanismos de comunicación.
7. Respetar la dirección de las dependencias hacia el núcleo de la aplicación.

## 5. Organización y responsabilidades

Cada microservicio debe mantener una organización que permita identificar claramente las siguientes responsabilidades, cuando corresponda:

- **Domain:** entidades, objetos de valor, agregados, reglas de negocio e interfaces del dominio.
- **Application:** casos de uso y coordinación de las operaciones de la aplicación.
- **Infrastructure:** implementaciones técnicas, persistencia, acceso a bases de datos e integración con servicios externos.
- **Presentation:** controladores, rutas y mecanismos de comunicación con los consumidores del servicio.

La organización física de carpetas puede variar según el lenguaje y las tecnologías utilizadas, pero debe conservar la separación de responsabilidades.

## 6. Persistencia y acceso a datos

1. Cada microservicio debe gestionar sus propias necesidades de persistencia.
2. Evitar acceder directamente a la base de datos de otro microservicio.
3. Utilizar repositorios o mecanismos de abstracción para separar la lógica de negocio del acceso a datos.
4. Utilizar consultas parametrizadas cuando se trabaje con bases de datos SQL.
5. Mantener la integridad y las relaciones de los datos.
6. Evitar modificar el esquema de la base de datos sin justificar previamente los cambios.
7. No incluir credenciales ni configuraciones sensibles directamente en el código fuente.

## 7. Comunicación entre microservicios

1. Utilizar los mecanismos de comunicación definidos por el proyecto, como APIs REST u otros mecanismos de integración.
2. Mantener contratos claros para las solicitudes y respuestas.
3. Validar los datos recibidos de otros microservicios.
4. Manejar adecuadamente los errores y tiempos de espera en las comunicaciones.
5. Evitar acoplar un microservicio a las estructuras internas de otro.
6. No asumir que todos los microservicios utilizan el mismo lenguaje, framework o sistema de persistencia.

## 8. Seguridad

1. Proteger los endpoints mediante los mecanismos de autenticación y autorización establecidos.
2. Validar los datos recibidos desde clientes y otros servicios.
3. Verificar los permisos del usuario antes de permitir operaciones protegidas.
4. No confiar en identificadores, roles o permisos enviados directamente por el cliente sin verificarlos.
5. Evitar exponer información sensible en respuestas HTTP o registros.
6. Gestionar los secretos y credenciales mediante mecanismos seguros de configuración.

## 9. Manejo de errores y respuestas

1. Manejar los errores de manera consistente.
2. Utilizar códigos de estado HTTP apropiados cuando se implementen APIs REST.
3. Evitar exponer detalles internos de infraestructura en las respuestas.
4. Diferenciar errores de validación, negocio, autenticación, autorización e infraestructura.
5. Registrar información suficiente para facilitar el diagnóstico de problemas sin exponer datos sensibles.

## 10. Reglas para trabajar con el código existente

1. Antes de implementar una funcionalidad, analizar la estructura y revisar las implementaciones relacionadas del microservicio.
2. Reutilizar interfaces, abstracciones, repositorios, casos de uso y servicios existentes cuando corresponda.
3. Evitar duplicar lógica de negocio y crear abstracciones innecesarias.
4. No inventar nombres de clases, métodos, interfaces, tablas o atributos sin revisar el código existente.
5. Evitar modificar funcionalidades que no estén relacionadas con el requerimiento.
6. No realizar refactorizaciones generales cuando solamente se solicita una funcionalidad específica.
7. No introducir dependencias nuevas si no son necesarias.
8. Respetar las convenciones y decisiones tecnológicas de cada microservicio.
9. Si se requiere modificar la arquitectura, los contratos de comunicación o la base de datos, explicar previamente el motivo y el impacto.

## 11. Verificación y pruebas

1. Revisar los cambios realizados antes de finalizar.
2. Ejecutar las pruebas existentes relacionadas con la funcionalidad modificada.
3. Verificar que los cambios respeten la arquitectura y las reglas de negocio.
4. Comprobar que las modificaciones no afecten funcionalidades existentes.
5. Verificar la integración con otros microservicios cuando corresponda.
6. No afirmar que una prueba fue ejecutada si realmente no se realizó.
7. Informar los archivos modificados, las pruebas ejecutadas y cualquier limitación encontrada.