# 01 — Pipeline METRIC para estimación de evapotranspiración

Pipeline para estimar evapotranspiración real (ET) de cultivos a partir de imágenes Landsat 8 y datos de una estación meteorológica, usando el modelo METRIC (balance de energía satelital).

## Problema

La gestión del riego en un distrito requiere conocer la evapotranspiración real de los cultivos. Los métodos tradicionales son puntuales: miden en una estación meteorológica y extrapolan. No capturan la variabilidad espacial de la ET dentro del distrito, que depende del tipo de cultivo, la humedad del suelo, la topografía y el manejo agronómico.

## Solución

Un pipeline en R que implementa METRIC (Mapping EvapoTranspiration at high Resolution with Internalized Calibration), un modelo de balance de energía que estima ET a partir de:

- **Imágenes satelitales Landsat 8** — resolución 30m, una imagen cada 16 días.
- **Datos meteorológicos de una estación en tierra** — temperatura, viento, radiación, humedad relativa.
- **Modelo digital de elevación** (ASTER) — para corregir por topografía.

El modelo calcula la ET como residuo del balance de energía:

    LE = Rn - G - H

Donde Rn es radiación neta, G es flujo de calor al suelo, H es flujo de calor sensible, y LE es flujo de calor latente (que se convierte en ET).

## Adquisición de las imágenes

Las imágenes Landsat 8 se solicitan a **ESPA** (Earth Surface Processing Architecture), del USGS:

    https://espa.cr.usgs.gov/

**Por qué ESPA y no Earth Explorer** (que es el portal más común del USGS): Earth Explorer no tiene disponibles todos los productos procesados que se necesitan. ESPA es el sistema de procesamiento bajo demanda del USGS, que genera productos adicionales a partir de las imágenes crudas (como reflectancia superficial, índices de vegetación, o productos provisionales).

**Cómo funciona el flujo de solicitud:**

1. Se selecciona la escena y los productos deseados en ESPA.
2. Se envía la orden de procesamiento.
3. ESPA envía un correo de confirmación.
4. En un lapso de uno a dos días (en su momento), llega un correo con el enlace de descarga.
5. Se descarga el archivo `.tar.gz` con las bandas procesadas.

La demora del procesamiento es característica de ESPA: no es descarga inmediata como en Earth Explorer, sino procesamiento por lotes.

**Archivo requerido:**

- El archivo `.tar.gz` de Landsat 8 se coloca en el directorio de trabajo del script.

## Variables requeridas

La estación meteorológica debe proveer al menos estas **7 variables**:

- `Date` — fecha
- `Time` — hora
- `Rad` — radiación solar
- `wind_speed` — velocidad del viento
- `RH` — humedad relativa
- `temp` — temperatura del aire
- `pp` — precipitación

El script **no usa la dirección del viento** (`wind_dir`). Si el CSV incluye esa columna, es ignorada por el paquete `water`.

## Estaciones disponibles

El script está configurado para dos estaciones genéricas:

- **`EstacionA`** — elevación 7 m, altura del anemómetro 10 m, velocidad del viento en m/s.
- **`EstacionB`** — elevación 65 m, altura 10 m, velocidad del viento en km/h (convertida internamente a m/s), hora con formato `HH:MM:SS`.

La estación activa se selecciona con la variable `estacion` al inicio del script (`"EstacionA"` o `"EstacionB"`).

Para agregar otra estación, se debe modificar la función `ws()` en `waterUtilsMod.R` agregando un nuevo caso al `switch`.

## Pipeline

### Etapas del proceso

1. **Preparación de la imagen Landsat 8**
   - Descomprimir el `.tar.gz`.
   - Renombrar bandas según el formato histórico que espera el paquete `water`.

2. **Preparación de datos auxiliares**
   - Definir el área de interés (Aoi).
   - Cargar la estación meteorológica.
   - Remuestrear el DEM a la resolución de la imagen.

3. **Cálculo del balance de energía**
   - Albedo superficial.
   - Índice de área foliar (LAI).
   - Temperatura superficial (Ts) por split-window.
   - Radiación solar incidente.
   - Radiación de onda larga entrante y saliente.
   - Radiación neta (Rn).
   - Flujo de calor al suelo (G).
   - Rugosidad del momento (Z.om).

4. **Calibración de METRIC**
   - Selección automática de píxeles fríos y calientes (extremos del rango Ts/NDVI).
   - Cálculo del flujo de calor sensible (H) con iteración.

5. **Cálculo de ET**
   - ET instantánea a partir de LE.
   - ET de 24 horas.
   - ET horaria de la estación meteorológica.
   - Coeficiente de cultivo (Kc = ET.inst / ET.hora).

6. **Índices de vegetación**
   - NDVI.
   - SAVI.

7. **Enmascaramiento de nubes**
   - El paquete `water` incluye un módulo de nubes, pero no funciona bien con Landsat 8 reciente.
   - El pipeline usa un parche propio basado en el archivo BQA.
   - Se aplica después del balance, para no afectar los cálculos con NA.

8. **Escritura de resultados**
   - 11 rasters por imagen (Kc, ET24, albedo, Rn, G, H, Ts, LAI, SAVI, NDVI, LE).
   - 2 CSV (píxeles fríos/calientes, coeficientes a/b de H).
   - Nombres organizados por año, DOY y estación.

## Organización de carpetas y salidas

El pipeline genera **dos salidas por cada bloque procesado**:

### 1. Salida completa (sin enmascarar)

Incluye todas las variables calculadas por el balance de energía, sin eliminar píxeles con nube. Se escribe a las carpetas configuradas en `writeWater()` y `writeWaterBase()`. Sirve como respaldo de todo el cálculo.

### 2. Salida sin nubes

Los rasters del BQA (banda de calidad de Landsat) se copian primero a una carpeta temporal. Luego se aplica el parche de enmascaramiento, que reclasifica el BQA y multiplica por cada raster. El resultado se escribe a la carpeta final sin nubes.

**Carpetas que se manejan:**

- `nubes/bqa/` — copia del archivo BQA original (sin modificar), como respaldo de la clasificación de calidad de cada imagen.
- `nubes/Recorte/` — copia de los rasters recortados, antes del enmascaramiento. Aquí se guarda una copia de todas las variables, sin modificar.
- `nubes/Recorte/a b/` — subcarpeta donde se procesa el enmascaramiento variable por variable.
- Carpeta final de salida (red o local) — rasters finales ya sin nubes.

**Automatización del manejo de archivos:**

El flujo fue automatizado para que, al procesar cada imagen:

1. Se cree la estructura de carpetas por variable.
2. Se copien los archivos del BQA y de los rasters recortados.
3. Se ejecute el enmascaramiento.
4. Se escriban los resultados finales.
5. Se limpien las carpetas temporales para la siguiente corrida.

Este manejo de archivos llevó bastante trabajo implementarlo, porque requería coordinar las rutas entre las distintas etapas del pipeline (cálculo, recorte, enmascaramiento, escritura final) y entre las dos estaciones.

## Enmascaramiento de nubes

El paquete `water` incluye un módulo de detección de nubes, pero **no funciona bien con las imágenes Landsat 8 recientes**:

- El formato del archivo BQA cambió en versiones nuevas.
- El módulo original fue escrito para una versión anterior del algoritmo.
- El resultado es inconsistente y difícil de verificar.

El pipeline usa un **parche propio** que:

1. Reclasifica el raster BQA según la tabla `reclassify.csv`.
2. Multiplica el BQA reclasificado por cada raster (ET, Ts, NDVI, etc.).
3. Los píxeles con nube quedan con **valor 0** en lugar de NA.

### Decisión de diseño: 0 en lugar de NA

Cuando un píxel de nube se multiplica por 0, queda en 0. Eso es distinto de NA.

- **NA**: el píxel no influye en cálculos estadísticos (medias, sumas, agregaciones). Es la forma estándar de decir "no dato".
- **0**: el píxel sí influye en cálculos, como si fuera un valor real de ET = 0.

La decisión de usar 0 en lugar de NA fue deliberada:

- El **BQA reclasificado** usa NA para los píxeles con nube. Eso es lo correcto: cuando se analiza el BQA solo, esos píxeles quedan marcados como "no dato" y no ensucian estadísticas de calidad.
- La **salida final sin nubes** usa 0 para esos mismos píxeles, porque el flujo posterior requería rasters sin NA (para poder combinarlos, sumarlos o promediarlos sin errores).

Quien use los rasters finales debe saber que **0 = nube enmascarada**, no "cero real de ET".

### La tabla de reclasificación

El `reclassify.csv` no es una copia de las recomendaciones de USGS. Es una tabla de reclasificación propia, calibrada para las condiciones específicas de la zona de estudio.

**Contexto de la decisión:**

El distrito de riego donde se aplica este pipeline tiene **alta presencia de nubes**, especialmente durante la época lluviosa. Aplicar un criterio estricto de eliminación (eliminar también nubes de "confianza media" o cirrus tenues) resultaría en:

- Una fracción muy pequeña de píxeles válidos por imagen.
- Pérdida de imágenes completas por falta de cobertura.
- Series temporales incompletas, inservibles para análisis de ET.

**La decisión fue conservar los píxeles con confianza media o baja de nube, y eliminar únicamente los píxeles con alta confianza de nube, cirrus o sombra de nube.**

El trade-off aceptado es: puede quedar algún píxel con nube tenue, pero se preserva la cobertura espacial y temporal del estudio.

**Estructura de la tabla:**

- `is` — valor original del BQA (combinación de bits).
- `becomes` — valor reclasificado: `0`, `1` o `NA`.
  - `0` — píxel sin dato (fill).
  - `1` — píxel válido (sin nube, o con confianza baja/media).
  - `NA` — píxel con nube, cirrus o sombra (alta confianza).

Los valores del BQA son combinaciones de bits que describen múltiples condiciones simultáneamente. La tabla de USGS documenta qué significa cada combinación, pero la decisión de qué eliminar y qué conservar es del profesional.

## Opciones de configuración

El paquete `water` ofrece múltiples métodos para cada sub-modelo del balance de energía. Las opciones usadas en este código fueron seleccionadas por prueba empírica.

**Calibración de anclas (`calcAnchors`)**

- `anchors.method = "best"` — usado por defecto cuando el algoritmo encuentra suficientes píxeles candidatos.
- `anchors.method = "flexible"` — usado como respaldo cuando `"best"` no encuentra suficientes candidatos. Baja la rigurosidad de los criterios.
- `"random"` — disponible en el paquete pero **no se usa** en este flujo.

**Iteración de calor sensible (`calcH`)**

- `maxit = 30` — número máximo de iteraciones. El valor por defecto es 20, pero se usa 30 para asegurar la estabilización de la ecuación.
- `ETp.coef = 1.05` — coeficiente de ET potencial para el pixel frío.
- `Z.om.ws = 0.015` — rugosidad del momento de la estación meteorológica (césped cortado).

**Métodos de sub-modelos**

- `soilHeatFlux(method = "Tasumi")` — alternativa: `"Bastiaanssen"`.
- `albedo(coeff = "Olmedo")` — alternativa: `"Tasumi"`.
- `surfaceTemperature(method = "SW")` — split window. Alternativa: `"SC"` (single channel).
- `LAI(method = "metric2010")`.
- `momentumRoughnessLength(method = "short.crops")`.

## Archivos

- `waterMod.R` — flujo principal del pipeline.
- `waterUtilsMod.R` — funciones auxiliares (descompresión, renombrado, estaciones, escritura de rasters).
- `reclassify.csv` — tabla de reclasificación del BQA para enmascaramiento de nubes.

## Cómo correrlo

1. Ajustar la ruta de trabajo en `waterMod.R` (`setwd()`).
2. Colocar en el directorio de trabajo:
   - El archivo `.tar.gz` de Landsat 8 (descargado de ESPA).
   - El DEM (`ASTER.tif`).
   - El CSV de la estación meteorológica.
   - El archivo `MTL.txt` (viene dentro del `.tar.gz`).
3. Ajustar la variable `estacion` a `"EstacionA"` o `"EstacionB"`.
4. Ejecutar `waterMod.R`.
5. Los rasters resultantes se escriben en las carpetas de salida configuradas.

**Tiempo estimado de ejecución:** ~10 minutos por imagen, con el flujo automatizado.

## Contexto

Este pipeline fue desarrollado para estimar evapotranspiración real a escala de parcela (30 m) en un distrito de riego en Costa Rica. El objetivo es mejorar la gestión del recurso hídrico en la región mediante la cuantificación distribuida de la demanda hídrica de los cultivos.

## Créditos

El pipeline usa el paquete `water` para R, desarrollado por Guillermo Federico Olmedo, Samuel Ortega-Farías, David Fonseca-Luengo, Daniel de la Fuente-Saiz y Fernando Fuentes-Peñailillo.

- Repositorio: https://github.com/midraed/water
- Artículo: Olmedo, G. F., Ortega-Farías, S., Fonseca-Luengo, D., de la Fuente-Saiz, D., & Fuentes-Peñailillo, F. (2016). *water: Tools and Functions to Estimate Actual Evapotranspiration Using Land Surface Energy Balance Models in R*. The R Journal, 8(2), 382-391.

## Créditos de la tabla BQA

Los valores del BQA utilizados en la tabla de reclasificación provienen de la documentación oficial de USGS para Landsat 8:

- USGS Landsat Quality Assessment (QA) Tools User Guide.
- https://www.usgs.gov/landsat-missions/landsat-collection-2-quality-assessment-bands
