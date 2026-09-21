# ============================================================
# Enmascaramiento de nubes en rasters Landsat 8
# ============================================================
# Reclasifica el archivo BQA (banda de calidad) de Landsat 8
# según una tabla de reclasificación propia, y enmascara los
# píxeles con nube en los rasters de salida del balance de
# energía (Kc, ET, Ts, NDVI, etc.).
#
# Se ejecuta después del pipeline de METRIC (ver 01-metric).
#
# El paquete water incluye un módulo de nubes, pero no funciona
# bien con Landsat 8 reciente. Este script lo reemplaza.
#
# Ver README.md para el contexto completo.
# ============================================================

setwd("ruta/a/tu/directorio/nubes")
library(raster)

bqa <- list.files(path = "bqa", pattern = ".tif", full.names = TRUE)       # archivo BQA de la carpeta
recorte <- list.files(path = "Recorte", pattern = ".tif", full.names = TRUE)  # rasters a los que se les eliminarán las nubes

resultado <- NULL  # valor nulo para comenzar
for (i in 1:length(recorte)) {

  rasBQA <- raster(bqa)                  # transforma el archivo del bqa a un raster
  rasRec <- raster(recorte[i])           # transforma la variable a raster

  csv <- read.csv("reclassify.csv", sep = ";")  # lee el archivo con la información de los píxeles reclasificados
  print(csv)
  reclas <- reclassify(rasBQA, csv)      # reclasifica el raster del bqa

  RESULTADO <- reclas * rasRec           # multiplica el raster bqa con el raster de la variable, para eliminar las nubes
  file <- as.character(paste(recorte[i], sep = ""))  # toma el nombre de los archivos y se los asigna a los nuevos archivos
  print(file)
  writeRaster(RESULTADO, file, overwrite = TRUE)

}

writeRaster(reclas, "reclassify.tif", overwrite = TRUE)  # imprime el raster del bqa reclasificado
