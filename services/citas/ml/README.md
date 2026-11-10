# Modelo de inasistencia (Citas)

Pipeline para entrenar y evaluar la probabilidad de que una cita termine en **inasistencia**.
Sustento y decisiones: `Estado_del_Arte_Inasistencia_Citas.md` (carpeta del proyecto).

> **Uso permitido:** solo para decidir **recordatorios**. Nunca para negar, retrasar ni priorizar
> en contra de una cita. La prioridad `ALTA` no entra al modelo.

## Reproducir

Desde `services/citas`, con el venv activo:

```bash
python -m pip install -r ml/requirements.txt
# Colocar el conjunto en ml/data/appointments.rda (carpeta ignorada por Git; ver "Datos")
python ml/train_no_show.py
```

Genera `ml/artifacts/no_show_logreg_v1.json` (el modelo, evaluable sin scikit-learn) y
`ml/artifacts/metrics_v1.json` (métricas y auditoría por subgrupo).

Para que el servicio lo use:

```bash
# services/citas/.env
NO_SHOW_MODEL_PATH=ml/artifacts/no_show_logreg_v1.json
```

Si la variable está vacía o el archivo no carga, el servicio usa la línea base por reglas.

## Datos

*Medical Appointment No Shows* (Joni Hoppen, Kaggle): 110 527 citas de Vitória (Brasil), 2016.
Kaggle exige iniciar sesión, así que se usó la copia del mismo conjunto que distribuye el paquete
de R `qacData` (`data/appointments.rda`). **No se versiona** en este repositorio: la licencia
original no está confirmada (un espejo la lista como CC BY-NC-SA 4.0). Confirmar antes de redistribuir.

## Diseño

- **Variables:** `log(1 + días de anticipación)`, `agendada el mismo día` e `inasistencias previas`
  (tope 3). Son las que Citas también calcula. Edad, sexo, barrio y beca **no** entran al modelo;
  solo se usan para auditar.
- **Sin fuga de información:** una inasistencia previa solo cuenta si esa cita ocurrió antes de que
  se agendara la actual.
- **Validación temporal:** 60 % más antiguo entrena, 20 % calibra (Platt) y el 20 % más reciente
  prueba. Umbral: se marca el 20 % de citas con mayor riesgo.
- **Comparación:** reglas v0 vs. regresión logística calibrada vs. gradient boosting.

## Resultados en el tramo de prueba (26 449 citas, 18,5 % de inasistencia)

| Modelo | AUC-ROC | AUC-PR | Brier | ECE | Recall | Precisión | Citas marcadas |
|---|---|---|---|---|---|---|---|
| Azar | 0,500 | 0,185 | — | — | 0,20 | 0,185 | 20 % |
| Reglas v0 | 0,618 | 0,240 | 0,152 | 0,053 | 0,59 | 0,261 | 41,6 % (*) |
| **Regresión logística calibrada** | **0,699** | **0,287** | **0,140** | **0,020** | 0,31 | 0,307 | 18,6 % |
| Gradient boosting | 0,702 | 0,285 | 0,139 | 0,035 | 0,32 | 0,307 | 18,9 % |

(*) Las reglas dan pocos valores distintos y se empatan; con el umbral elegido marcan el doble de citas,
por eso su recall no es comparable. Lo comparable son AUC-ROC, AUC-PR, Brier y ECE.

**Lectura honesta:**

- La regresión logística supera a las reglas y **iguala** a gradient boosting con variables tan
  simples; por eso se eligió (es interpretable).
- La mejora sobre el azar es **moderada**: de cada 100 citas marcadas, ~31 faltan (vs. 18,5 de base,
  unas 1,7 veces más). Es útil para priorizar recordatorios, no para predecir con certeza.
- Solo el 16 % de las citas de prueba tiene una inasistencia previa: el conjunto abarca ~6 semanas.
  Con estudiantes **sin historial** (arranque en frío) el modelo se apoya casi solo en la anticipación.
- **Equidad (auditoría):** el modelo sobrestima el riesgo en 60+ años (prob. media 0,21 vs. tasa real
  0,14) y lo subestima en 18–29 (0,20 vs. 0,23), aunque no usa la edad. Esto es una señal para
  vigilar y reentrenar con datos propios, no para ignorar.
- **Validez externa:** entrenado con atención médica general en Brasil. **No** hay evidencia de que
  funcione igual con estudiantes de la UNMSM. Antes de decidir nada, reentrenar y validar con
  `appointment_events` reales.

## Línea siguiente

1. Recolectar historial real en `appointment_events` y reentrenar (validación temporal).
2. Agregar variables propias de Citas (hora, cancelaciones previas, reprogramaciones) cuando haya datos.
3. Medir el efecto en la práctica (¿bajan las inasistencias con recordatorios guiados?) antes de
   considerar cualquier otro uso.
