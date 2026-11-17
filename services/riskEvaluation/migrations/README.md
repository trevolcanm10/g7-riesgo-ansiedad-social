# Migración de SHAP

Antes de desplegar la versión de Risk Evaluation que escribe `shap_explanation`,
comprueba la base configurada para ese servicio:

```sql
SELECT DATABASE();
SHOW COLUMNS FROM risk_evaluations LIKE 'shap_explanation';
```

Si la segunda consulta no devuelve filas, ejecuta **una vez**
`20261113_add_shap_explanation_single_statement.sql`. El archivo contiene un
único `ALTER TABLE` apto para editores que ejecutan una sentencia por vez.
Después repite `SHOW COLUMNS` y confirma que la columna es `JSON` y admite
`NULL`. Si la columna ya existe, no vuelvas a ejecutar el `ALTER TABLE`.

`20261113_add_shap_explanation.sql` es la variante repetible para clientes
MySQL que admiten varias sentencias y `PREPARE`. Ambas variantes producen la
misma columna; **elige solo una**. Aplica la migración primero en una base de
prueba y luego en la base que administra el responsable de Evaluación, antes
del redespliegue de `/re`. La versión anterior del servicio tolera la columna
extra y las filas antiguas devuelven `shapExplanation: null`.
