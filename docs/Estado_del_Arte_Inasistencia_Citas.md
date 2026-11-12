# Estado del arte: predicción de inasistencia a citas (módulo Citas, M3)

Borrador v2, **referencias verificadas el 10-nov-2026**. Reemplaza al v1.

**Cómo se verificó:** búsqueda web contra índices y páginas de las revistas (MDPI, PubMed, PMC, Crossref/INFORMS, ISRCTN, repositorios). Se contrastaron autores, título, revista, volumen, páginas y DOI. **No se leyeron los textos completos** de los artículos de pago (Health Policy, Military Medicine, IEEE, INFORMS); de esos solo se confirmaron resúmenes y metadatos. Antes de entregar el informe, abrir cada DOI una vez y revisar la cita en el estilo que exija el curso.

Leyenda: ✔ verificada · ◐ verificada en parte (se indica qué falta) · ✖ no se pudo verificar (no citar así).

## 1. Pregunta

¿Qué se sabe sobre predecir si una persona asistirá a una cita, y cómo debe usarse esa predicción en un servicio de orientación estudiantil donde las personas pueden estar en riesgo de ansiedad?

## 2. Fuentes

### 2.1 Revisiones sistemáticas

| # | Referencia | Qué aporta (lo verificado) | Estado |
|---|---|---|---|
| R1 | Carreras-García, D., Delgado-Gómez, D., Llorente-Fernández, F., y Arribas-Gil, A. (2020). Patient no-show prediction: A systematic literature review. *Entropy, 22*(6), 675. https://doi.org/10.3390/e22060675 | Revisión PRISMA de 50 artículos (enero 1980 a enero 2020). Predictores frecuentes: porcentaje previo de inasistencia, anticipación, diagnóstico y edad. Solo dos estudios superaron la exactitud de la tasa de asistencia y uno alcanzó AUC > 0,9. | ✔ |
| R2 | Dantas, L. F., Fleck, J. L., Cyrino Oliveira, F. L., y Hamacher, S. (2018). No-shows in appointment scheduling – a systematic literature review. *Health Policy, 122*(4), 412–421. https://doi.org/10.1016/j.healthpol.2018.02.002 | 105 artículos seleccionados de 727. Tasa media de inasistencia ≈ 23 % (43 % en África, 13,2 % en Oceanía). Determinantes más reportados: **larga anticipación** e **historial de inasistencias**. Asociados: menor edad, menor nivel socioeconómico, distancia y no tener seguro privado. | ✔ (autores confirmados en Crossref) |
| R3 | Oikonomidi, T., Norman, G., McGarrigle, L., Stokes, J., van der Veer, S. N., y Dowding, D. (2023). Predictive model-based interventions to reduce outpatient no-shows: a rapid systematic review. *Journal of the American Medical Informatics Association, 30*(3), 559–569. https://doi.org/10.1093/jamia/ocac242 (en línea el 12-dic-2022; acceso abierto: [PMC9933067](https://pmc.ncbi.nlm.nih.gov/articles/PMC9933067)) | Recordatorios guiados por el modelo **reducen** la inasistencia: SMS (RR mediana 0,91, certeza alta, 1 ensayo), llamadas (RR 0,61, certeza moderada, 3 ensayos) y navegador de pacientes (RR 0,55, certeza moderada, 1 ensayo). El efecto del **sobreagendamiento** es **incierto**. Poca información sobre costo, aceptabilidad y equidad. | ✔ (autores confirmados en Crossref) |
| R4 | Salazar, L. H. A., Parreira, W. D., Fernandes, A. M. R., y Leithardt, V. R. Q. (2022). No-show in medical appointments with machine learning techniques: A systematic literature review. *Information, 13*(11), 507. https://doi.org/10.3390/info13110507 | Revisión PRISMA de artículos de 2017 a 2022 (≈ 24 analizados). Solo un trabajo incluido (Chong et al.) describe un experimento donde bajó la inasistencia en la práctica: **la mayoría de los modelos no se evalúa en uso real**. | ✔ |
| R5 | Toffaha, K., Simsekler, M. C. E., y Omar, M. (2024). Review of hospital outpatient no-show explainable prediction using machine learning. En *2024 IEEE International Conference on Technology Management, Operations and Decisions (ICTMOD)* (pp. 1–6). https://doi.org/10.1109/ICTMOD63116.2024.10878195 | Revisión centrada en modelos **explicables** para citas ambulatorias hospitalarias (92 estudios potenciales identificados en la búsqueda). | ◐ Solo se vio el resumen. **No se confirmó** la afirmación del v1 sobre «generalización limitada y reticencia de los clínicos»: se elimina. |

### 2.2 Equidad y uso responsable

| # | Referencia | Qué aporta | Estado |
|---|---|---|---|
| E1 | Samorani, M., Harris, S. L., Goler Blount, L., Lu, H., y Santoro, M. A. (2022). Overbooked and overlooked: Machine learning and racial bias in medical appointment scheduling. *Manufacturing & Service Operations Management, 24*(6), 2825–2842. https://doi.org/10.1287/msom.2021.0999 | Sobreagendar según el riesgo predicho traslada la espera al grupo con mayor riesgo estimado: los pacientes negros esperaban ≈ 30 % más. Un objetivo que incluya la equidad la elimina con un costo operativo similar. Una de las autoras atribuye parte de las inasistencias a problemas de transporte, no a falta de compromiso (comunicado de INFORMS). *(Una clínica de EE. UU.: generalización limitada.)* | ✔ |
| E2 | Tuan, W.-J., Yan, Y., Abou Al Ardat, B., Felix, T., y Chen, Q. (2025). Predicting missed appointments in primary care: A personalized machine learning approach. *Annals of Family Medicine, 23*(4), 294–301. https://doi.org/10.1370/afm.240316 | 1,1 millones de citas de 109 mil pacientes (Penn State). Gradient boosting: AUC 0,852 para inasistencia. La **anticipación** fue el predictor más importante. Probaron equidad por sexo y raza/etnia y no hallaron sesgo. Usan también privación del área, distancia y clima (variables que el módulo Citas **no** usa). | ✔ (DOI, autores y páginas confirmados en Crossref) |
| E3 | Informe de *Health Affairs* sobre herramientas de IA integradas en historias clínicas y sobreagendamiento dirigido (referido por Becker's Hospital Review). | Advierte sesgos hacia poblaciones vulnerables. | ✖ **Solo se conoce por una nota periodística.** No citar hasta localizar el artículo original. |

### 2.3 Salud mental y contexto universitario

| # | Referencia | Qué aporta | Estado |
|---|---|---|---|
| M1 | Milicevic, A. S., Mitsantisuk, K., Tjader, A., Vargas, D. L., Hubert, T. L., y Scott, B. (2020). Modeling patient no-show history and predicting future appointment behavior at the Veterans Administration's outpatient mental health clinics: NIRMO-2. *Military Medicine, 185*(7-8), e988–e994. https://doi.org/10.1093/milmed/usaa095 (PubMed 32591833) | ≈ 1,2 millones de citas (2013–2017). Predictores más fuertes: tasa de inasistencia en los 2 años previos, probabilidad de un modelo de Markov y antigüedad de la cita. Datos de 13 centros médicos (según la sección de métodos). | ◐ El «> 60 %» del v1 **no es un hallazgo del estudio**: es una cifra de la literatura que el artículo cita como contexto. |
| M2 | Dechasa, E. (2026). *Targeted outreach to reduce no-show rates* [proyecto DNP]. Oregon Health & Science University. https://digitalcollections.ohsu.edu/record/44931 | Un modelo basado **solo en el historial de inasistencia** marcó pacientes para llamadas: sensibilidad 42–46 %, especificidad 86–88 %. **La tasa de inasistencia subió** de 18,4 % a 35,3 % tras la intervención (p < 0,05). Concluye que una sola variable puede ser insuficiente. | ✔ pero **corrige el v1** (decía «no redujo»; en realidad aumentó). Diseño antes/después sin grupo control y literatura gris: no atribuir causalidad. |
| M3 | Registro ISRCTN28960722, Dimence Groep (Deventer, Países Bajos). https://www.isrctn.com/ISRCTN28960722 | Protocolo: llamar 2 días antes a pacientes de salud mental forense con riesgo predicho ≥ 0,5. Registrado el 04/12/2024 (dd/mm/aaaa); estudio de sep-2022 a dic-2025. Advierte el posible daño de una llamada injustificada. | ✔ Solo protocolo; **no se hallaron resultados**. |
| M4 | Boateng, O. A. (2024). *Assessing and improving student advising efficiency with a probabilistic model to predict no-shows in academic appointments* [material de conferencia]. Grand Valley State University, Indiana University Assessment Institute. https://assessmentinstitute.indianapolis.iu.edu/international/inter-conf_files/2024/handouts/boateng_ps1.pdf | Propone regresión logística con actualización bayesiana para inasistencia a **asesoría académica**. Entradas: datos demográficos, asistencia previa, fechas y tipo de asesoría. El autor reconoce la limitación de acceso a datos para validar. | ✔ Handout sin revisión por pares y **sin resultados**. |

### 2.4 Datos públicos

| # | Referencia | Qué aporta | Estado |
|---|---|---|---|
| D1 | *Medical Appointment No Shows* (Joni Hoppen, Kaggle). 110 527 citas, 14 variables, hospitales públicos de Vitória (Espírito Santo, Brasil), 2016. | Útil para **validar el pipeline** de entrenamiento y evaluación. Contexto distinto (atención médica general, no orientación estudiantil). | ◐ La **licencia no se pudo confirmar**: el v1 decía CC BY-NC-SA 4.0 (de un espejo) y eso tampoco se verificó. Revisar la ficha en Kaggle antes de redistribuir. Se usó la copia del paquete de R `qacData`; el conjunto no se versiona. |

### 2.5 Dato de contexto sobre el desempeño alcanzable (no citar sin leer)

Toffaha, K. M., Simsekler, M. C. E., Alshehhi, A., y Atif Omar, M. (2024). Predicting hospital no-shows: Interpretable machine learning models approach. *IEEE Access, 12*, 166058–166067. https://doi.org/10.1109/ACCESS.2024.3490662 (metadatos confirmados en Crossref). Compara 12 clasificadores interpretables sobre **este mismo conjunto de Kaggle** y reporta AUC ≈ 0,87 (cifra tomada del resumen; el artículo completo no se leyó). Si se cita, aclarar que usa más variables (edad, SMS, enfermedades, barrio) que el modelo de Citas, que **excluye** deliberadamente varias por equidad.

## 3. Brechas encontradas

1. **No se halló ningún estudio revisado por pares** sobre predicción de inasistencia en un **centro de orientación o consejería universitaria** (búsquedas repetidas el 10-nov-2026). Lo más cercano: asesoría académica (M4, sin resultados) y salud mental ambulatoria (M1, M2).
2. Los modelos publicados usan casi siempre historial de asistencia, edad y anticipación. Sin historial (arranque en frío) el desempeño esperado es bajo.
3. **Casi no se evalúan en uso real**: R4 encontró un solo experimento con reducción de inasistencias en la práctica. Poca evidencia sobre equidad y aceptabilidad (R3, E1).

## 4. Qué implica para el diseño de Citas

| Hallazgo | Decisión en el servicio |
|---|---|
| Anticipación e historial son los determinantes más reportados (R1, R2, M1, E2) | El modelo usa exactamente esas variables: anticipación e inasistencias previas. |
| El historial solo puede no bastar (M2) | El score no es una decisión; es apoyo. Se evalúa con recall, precisión, calibración y subgrupos, no solo exactitud. |
| Los recordatorios guiados por modelo funcionan; el sobreagendamiento es incierto y puede dañar la equidad (R3, E1) | **El score solo activa recordatorios.** No se implementa sobreagendamiento ni se niega o retrasa ninguna cita. |
| La inasistencia puede reflejar barreras estructurales, no falta de compromiso (E1) | No usar el score para sancionar. La prioridad `ALTA` no entra al modelo. |
| Una llamada injustificada tiene costo para la persona (M3); la intervención con una sola variable no mejoró nada (M2) | Mantener los recordatorios proporcionales y medir su efecto antes de ampliar su uso. |
| Modelos interpretables facilitan la aceptación (R5, solo por su enfoque) | Regresión logística calibrada con factores visibles (`factors` en la respuesta). |
| No hay datos propios al inicio (brecha 2) | D1 solo valida el pipeline; reentrenar con `appointment_events` cuando haya historial. **No afirmar** que el modelo sirve para estudiantes. |

## 5. Resultados preliminares del módulo

El pipeline está en `services/citas/ml/` (ver su `README.md`). En el tramo de prueba temporal de D1 (26 449 citas, 18,5 % de inasistencia), la regresión logística calibrada obtuvo AUC-ROC 0,699 y AUC-PR 0,287 (azar: 0,185), mejor que las reglas (0,618 y 0,240) e igual a gradient boosting (0,702 y 0,285). Es una mejora **moderada** y la auditoría por subgrupo mostró sobreestimación en mayores de 60 años (0,21 estimado frente a 0,14 real). No hay evidencia de que funcione igual con estudiantes.

## 6. Plan de evaluación propuesto

- Métricas: AUC-PR, recall y precisión de la clase «no asistió», calibración (curva, Brier, ECE) y errores por subgrupo.
- Comparar: reglas v0 → regresión logística calibrada → modelo de árboles.
- Validar en el tiempo (entrenar con citas pasadas, probar con las siguientes), no con mezcla aleatoria.
- Medir en uso real si los recordatorios guiados reducen la inasistencia (la brecha 3), con un grupo de comparación.
- Reportar con honestidad la limitación del arranque en frío.

## 7. Correcciones respecto al v1

1. **M2:** la inasistencia **aumentó** (18,4 % → 35,3 %), no «no se redujo».
2. **M1:** el «> 60 % de inasistencia» era una cifra de contexto citada por el artículo, no un resultado suyo.
3. **R5:** se eliminó la afirmación sobre «reticencia de los clínicos» (no verificada).
4. **R1:** se eliminó «la referencia más citada del área» (no verificada).
5. **R4:** corregidos año (2022) y título.
6. **E2 (v1):** «comentarios en *Annals of Family Medicine* y *Health Affairs*» no se pudo localizar. Se reemplazó por un artículo verificado de *Annals* (Tuan et al., 2025) y el informe de *Health Affairs* quedó como E3, sin verificar.
7. **D1:** la licencia CC BY-NC-SA 4.0 tampoco está confirmada.

## 8. Pendientes

Los autores, volúmenes, páginas y DOI de R1–R5, E1, E2 y M1 quedaron confirmados contra Crossref el 10-nov-2026. Lo que sigue abierto:

1. Localizar el artículo original de *Health Affairs* (E3) o descartarlo.
2. Buscar con acceso institucional (IEEE Xplore, Scopus, ScienceDirect) términos como *college counseling appointment attendance* y *student mental health service no-show*.
3. Confirmar la licencia de D1 en la ficha de Kaggle.
4. Leer los textos completos de lo que se vaya a citar con cifras (R2, M1, E1 y R5 son de pago).
