# 02 — Parche de nubes

Enmascaramiento de píxeles afectados por nubes en rasters Landsat 8, usando el archivo BQA (banda de calidad) como referencia.

## Problema

El paquete `water` incluye un módulo de detección de nubes, pero **no funciona bien con las imágenes Landsat 8 recientes**:

- El formato del archivo BQA cambió en versiones nuevas.
- El módulo original fue escrito para una versión anterior del algoritmo.
- El resultado es inconsistente y difícil de verificar.

Además, incluso cuando funciona, el módulo **asigna NA a los píxeles de nube**, lo cual genera problemas en etapas posteriores: los NA propagan el cómputo de estadísticas y pueden romper operaciones sobre rasters.

## Solución

Script independiente que:

1. **Reclasifica** el raster BQA según una tabla `reclassify.csv` que define qué valores corresponden a nubes, sombras o píxeles válidos.
2. **Multiplica** el BQA reclasificado por el raster que se quiere enmascarar (ET, Ts, NDVI, etc.).
3. Como resultado, los píxeles con nube quedan con **valor 0** en lugar de NA.

Este script se ejecuta **después** del pipeline de ET (`01-metric`), cuando ya se tienen los rasters finales y se quieren limpiar visualmente.

## Decisión de diseño: 0 en lugar de NA

Cuando un píxel de nube se multiplica por 0, queda en 0. Eso es distinto de NA. Las consecuencias:

- **Ventaja**: los rasters se pueden combinar, sumar o promediar sin errores por NA.
- **Desventaja**: alguien que vea el raster sin saberlo va a interpretar 0 como "sin ET" cuando en realidad es "no dato". Eso puede sesgar estadísticas si no se filtra antes.

La decisión de usar 0 en lugar de NA fue deliberada, porque el flujo posterior del proyecto requería rasters "limpios" sin NA. Quien use los rasters debe saber que **0 = nube enmascarada**, no "cero real".

## La tabla de reclasificación

El `reclassify.csv` no es una copia de las recomendaciones de USGS. Es una tabla de reclasificación propia, calibrada para las condiciones específicas de la zona de estudio.

### Contexto de la decisión

El distrito de riego donde se aplica este pipeline tiene **alta presencia de nubes**, especialmente durante la época lluviosa. Aplicar un criterio estricto de eliminación (eliminar también nubes de "confianza media" o cirrus tenues) resultaría en:

- Una fracción muy pequeña de píxeles válidos por imagen.
- Pérdida de imágenes completas por falta de cobertura.
- Series temporales incompletas, inservibles para análisis de ET.

**La decisión fue conservar los píxeles con confianza media o baja de nube, y eliminar únicamente los píxeles con alta confianza de nube, cirrus o sombra de nube.**

El trade-off aceptado es: puede quedar algún píxel con nube tenue, pero se preserva la cobertura espacial y temporal del estudio.

### Estructura de la tabla

El archivo tiene dos columnas:

- `is` — valor original del BQA (combinación de bits).
- `becomes` — valor reclasificado: `0`, `1` o `NA`.

- `0` — píxel sin dato (fill).
- `1` — píxel válido (sin nube, o con confianza baja/media).
- `NA` — píxel con nube, cirrus o sombra (alta confianza).

Los valores del BQA son combinaciones de bits que describen múltiples condiciones simultáneamente. La tabla de USGS documenta qué significa cada combinación, pero la decisión de qué eliminar y qué conservar es del profesional.

## Pipeline

```
Reclasificación                 Multiplicación
─────────────────               ───────────────
BQA.tif                         Raster a enmascarar
   │                                    │
   │  reclassify.csv                    │
   ▼                                    │
Reclasificado  ────────────────────────►│
                                        ▼
                                Raster limpio (0 en nubes)
```

## Entradas

- `bqa/*.tif` — archivos BQA descargados de Landsat 8.
- `Recorte/*.tif` — rasters recortados al área de interés (ET, Ts, etc.).
- `reclassify.csv` — tabla con la reclasificación de valores BQA. Separador `;`.

## Salida

- Un raster enmascarado por cada archivo en `Recorte/`.
- El resultado se escribe sobre el mismo archivo (`overwrite = TRUE`).
- Adicionalmente, se guarda el BQA reclasificado como `reclassify.tif` para inspección.

## Herramientas

- **R**: `raster`.

## Cómo correrlo

1. Ajustar la ruta en `setwd()`.
2. Colocar los archivos BQA en `bqa/` y los rasters a enmascarar en `Recorte/`.
3. Ajustar el `reclassify.csv` según los valores específicos del BQA de la imagen.
4. Ejecutar. Los rasters en `Recorte/` se sobreescriben con la versión enmascarada.

## Notas de diseño

- El script itera sobre todos los archivos en `Recorte/`. Si hay muchos, se procesan en cadena.
- El BQA se lee una vez y se aplica a todos los rasters (mismo día, misma imagen Landsat).
- Si se necesita enmascarar otra imagen Landsat, hay que actualizar el BQA y el `reclassify.csv` correspondiente.

## Relación con otros proyectos

Este script forma parte del pipeline de estimación de evapotranspiración satelital (ver `01-metric`). Se ejecuta después del balance de energía, para limpiar visualmente los rasters finales.

## Créditos

Los valores del BQA utilizados en la tabla de reclasificación provienen de la documentación oficial de USGS para Landsat 8:

- USGS Landsat Quality Assessment (QA) Tools User Guide.
- https://www.usgs.gov/landsat-missions/landsat-collection-2-quality-assessment-bands
