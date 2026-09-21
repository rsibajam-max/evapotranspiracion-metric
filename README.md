# Evapotranspiracion-metric

Balance de energía satelital (METRIC) para estimación de evapotranspiración de cultivos a partir de imágenes Landsat 8.

## Proyectos

- **[01 — Pipeline METRIC](01-metric/README.md)**: flujo completo del balance de energía, desde la imagen Landsat hasta la ET, con enmascaramiento de nubes integrado.

## Herramientas

- **R**: `raster`, `water`, `R.utils`, `fs`, `purrr`, `stringr`, `filesstrings`.
- **Imágenes satelitales**: Landsat 8, solicitadas vía USGS ESPA.
- **Modelo digital de elevación**: ASTER.
- **Estación meteorológica**: datos de campo (CSV).

## Contexto

Pipeline para estimar evapotranspiración real a escala de parcela (30 m) en un distrito de riego, para mejorar la gestión del recurso hídrico mediante la cuantificación distribuida de la demanda hídrica de los cultivos.

Ver `01-metric` para el detalle del pipeline.
