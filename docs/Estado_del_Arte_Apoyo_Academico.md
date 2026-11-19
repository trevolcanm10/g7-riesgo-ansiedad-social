# Estado del arte: recomendación de apoyo académico

## Alcance

Este módulo recomienda recursos de apoyo académico —tutorías entre pares, talleres y materiales— a partir de intereses, cursos, disponibilidad, modalidad e interacciones con el catálogo. Estos antecedentes respaldan una primera versión híbrida; no demuestran por sí mismos que el sistema mejore resultados académicos.

## Antecedentes relevantes

### Sistemas híbridos de recomendación

Burke (2002) revisa formas de combinar técnicas de recomendación y analiza cómo aprovechar fortalezas complementarias. El módulo adopta esa idea: usa contenido explícito para relacionar recursos con el perfil, popularidad como respaldo inicial y filtrado colaborativo cuando hay interacciones útiles. La referencia respalda explorar la combinación, no los pesos concretos de este proyecto.

Robin Burke, “Hybrid Recommender Systems: Survey and Experiments”, *User Modeling and User-Adapted Interaction*, 12, 331–370 (2002). DOI: [10.1023/A:1021240730564](https://doi.org/10.1023/A:1021240730564).

### Filtrado colaborativo basado en elementos

Sarwar et al. (2001) estudian algoritmos de filtrado colaborativo item-item que calculan similitud entre elementos. Es pertinente a la señal colaborativa del servicio: representa cada recurso mediante interacciones y compara recursos para hallar candidatos relacionados. La implementación usa similitud coseno sobre interacciones implícitas; no reproduce necesariamente todos los algoritmos evaluados en ese trabajo.

Badrul Sarwar, George Karypis, Joseph Konstan y John Riedl, “Item-Based Collaborative Filtering Recommendation Algorithms”, *Proceedings of the 10th International Conference on World Wide Web* (WWW ’01), 285–295 (2001). DOI: [10.1145/371920.372071](https://doi.org/10.1145/371920.372071).

### Arranque en frío

Schein et al. (2002) estudian recomendaciones de arranque en frío que combinan información de contenido y colaborativa. Esto es relevante cuando hay pocos perfiles o interacciones. El servicio puede empezar con coincidencias del perfil y usar popularidad como línea base si el estudiante aún no define preferencias.

Andrew I. Schein, Alexandrin Popescul, Lyle H. Ungar y David M. Pennock, “Methods and Metrics for Cold-Start Recommendations”, *Proceedings of the 25th Annual International ACM SIGIR Conference on Research and Development in Information Retrieval* (SIGIR ’02), 253–260 (2002). DOI: [10.1145/564376.564421](https://doi.org/10.1145/564376.564421).

### Recomendación de compañeros de estudio

Nguyen Thanh et al. (2019) presentan un recomendador de compañeros de estudio que considera características y preferencias para formar parejas de aprendizaje. El objeto recomendado es distinto —personas en ese trabajo, actividades y recursos aquí—, pero es un antecedente de recomendación aplicada al aprendizaje. No es evidencia de eficacia para recomendar talleres.

Tam Nguyen Thanh, Michael Morgan, Matthew Butler y Kim Marriott, “Perfect Match: Facilitating Study Partner Matching”, *Proceedings of the 50th ACM Technical Symposium on Computer Science Education* (SIGCSE ’19), 1102–1108 (2019). DOI: [10.1145/3287324.3287344](https://doi.org/10.1145/3287324.3287344).

## Decisión técnica del módulo

La primera señal está basada en contenido. Compara intereses con etiquetas, cursos con códigos de curso, disponibilidad con horario y preferencias con modalidad. Los pesos iniciales son 45 %, 35 %, 15 % y 5 % respectivamente; los pesos disponibles se renormalizan si faltan campos. La puntuación de contenido se combina con popularidad. Si el historial permite una señal colaborativa item-item útil, el ranking combina la puntuación base con esa señal.

Sin preferencias ni historial útil, usa popularidad como línea base. Sin recursos publicados, responde con el modo NO_CATALOG. Cada recomendación incluye razones legibles; el score ordena resultados y no representa una probabilidad.

Las señales implícitas son vista, clic, inscripción y finalización. La evaluación offline descrita en ml/evaluation_report.md usa perfiles y datos sintéticos: permite reproducir la lógica bajo ese escenario, pero no afirmar rendimiento con estudiantes reales.

## Límites y trabajo futuro

- Los pesos son parámetros iniciales; deben revisarse con el catálogo institucional y una evaluación supervisada.
- El historial puede ser escaso y estar sesgado por la exposición previa del catálogo. Conviene medir cobertura y calidad con usuarios voluntarios.
- Los resultados sintéticos no sustituyen una evaluación con estudiantes ni permiten inferir mejoras en notas, asistencia o bienestar.
- El servicio recomienda actividades y recursos. No usa indicadores de salud, evaluaciones de riesgo ni predicciones clínicas para ordenar resultados.

## Referencias

1. Burke, R. (2002). “Hybrid Recommender Systems: Survey and Experiments”. *User Modeling and User-Adapted Interaction*, 12, 331–370. https://doi.org/10.1023/A:1021240730564
2. Sarwar, B., Karypis, G., Konstan, J., & Riedl, J. (2001). “Item-Based Collaborative Filtering Recommendation Algorithms”. *WWW ’01*, 285–295. https://doi.org/10.1145/371920.372071
3. Schein, A. I., Popescul, A., Ungar, L. H., & Pennock, D. M. (2002). “Methods and Metrics for Cold-Start Recommendations”. *SIGIR ’02*, 253–260. https://doi.org/10.1145/564376.564421
4. Nguyen Thanh, T., Morgan, M., Butler, M., & Marriott, K. (2019). “Perfect Match: Facilitating Study Partner Matching”. *SIGCSE ’19*, 1102–1108. https://doi.org/10.1145/3287324.3287344
