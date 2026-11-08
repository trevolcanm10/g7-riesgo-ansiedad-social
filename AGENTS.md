# AGENTS.md

## 1. Contexto del proyecto

Este repositorio contiene una aplicación de software compuesta por diferentes componentes:

- **Frontend:** interfaz de usuario de la aplicación.
- **Services:** backend basado en una arquitectura de microservicios.
- **OpenAPI:** archivos YAML que documentan las especificaciones de las APIs.
- **Web-demo:** aplicación web de demostración.

Cada componente puede utilizar diferentes lenguajes de programación, frameworks y tecnologías según sus necesidades.

El objetivo de estas instrucciones es establecer reglas generales para que el asistente de IA trabaje respetando la organización, arquitectura y convenciones del proyecto.

## 2. Principios generales de arquitectura

1. Mantener una separación clara de responsabilidades entre los diferentes componentes.
2. Aplicar los principios SOLID cuando corresponda.
3. Respetar los principios de Domain-Driven Design (DDD) y Arquitectura Hexagonal en los microservicios que los implementen.
4. Mantener un bajo acoplamiento entre los diferentes componentes.
5. Evitar dependencias innecesarias entre módulos y servicios.
6. Respetar la independencia tecnológica de cada componente.
7. Evitar duplicar código y lógica innecesariamente.
8. Reutilizar las abstracciones, interfaces y componentes existentes cuando corresponda.

## 3. Comunicación e integración

1. Mantener contratos de comunicación claros entre los diferentes componentes.
2. Los archivos OpenAPI deben documentar las rutas, métodos HTTP, parámetros, esquemas y respuestas realmente implementados en los microservicios.
3. Cuando se implementen o modifiquen endpoints, verificar si corresponde actualizar los archivos YAML de OpenAPI para mantener la documentación sincronizada con el código.
4. Evitar modificar contratos de API sin analizar previamente su impacto en los consumidores.
5. Mantener la compatibilidad entre frontend y backend.
6. Manejar adecuadamente los errores de comunicación entre componentes.
7. No asumir que todos los componentes utilizan el mismo lenguaje o framework.

## 4. Seguridad

1. Validar los datos recibidos desde fuentes externas.
2. Aplicar mecanismos de autenticación y autorización según las necesidades de cada componente.
3. No confiar en identificadores, roles o permisos enviados directamente por el cliente sin verificarlos.
4. Evitar exponer información sensible en respuestas o registros.
5. No almacenar credenciales ni secretos directamente en el código fuente.
6. Utilizar mecanismos seguros para gestionar variables de entorno y configuraciones sensibles.

## 5. Reglas para trabajar con el código existente

1. Antes de implementar una funcionalidad, analizar la estructura del componente involucrado y revisar las implementaciones relacionadas.
2. Reutilizar las abstracciones, interfaces, servicios y componentes existentes cuando corresponda.
3. Evitar crear abstracciones innecesarias o duplicar funcionalidades.
4. No inventar nombres de clases, métodos, interfaces, tablas o atributos sin revisar el código existente.
5. Evitar modificar funcionalidades que no estén relacionadas con el requerimiento.
6. No realizar refactorizaciones generales cuando solamente se solicita una funcionalidad específica.
7. No introducir dependencias nuevas si no son necesarias.
8. Respetar las convenciones y decisiones tecnológicas de cada componente.
9. Si se requiere modificar contratos, estructuras de datos o decisiones arquitectónicas, explicar previamente el motivo y el impacto.
10. No modificar archivos de otros componentes sin que sea necesario para cumplir el requerimiento.

## 6. Verificación y pruebas

1. Revisar los cambios realizados antes de finalizar.
2. Ejecutar las pruebas existentes relacionadas con la funcionalidad modificada.
3. Verificar que los cambios respeten la arquitectura y convenciones del componente.
4. Comprobar que las modificaciones no afecten funcionalidades existentes.
5. No afirmar que una prueba fue ejecutada si realmente no se realizó.
6. Informar los archivos modificados, las pruebas ejecutadas y cualquier limitación encontrada.

## 7. Instrucciones específicas

Cada componente puede tener su propio archivo `AGENTS.md` para definir instrucciones particulares sobre su arquitectura, tecnologías, estructura de carpetas y convenciones de desarrollo.

Estas instrucciones deben complementar las reglas generales de este documento, evitando duplicaciones innecesarias.

Antes de realizar modificaciones, revisar los archivos `AGENTS.md` aplicables al componente involucrado y respetar sus instrucciones.