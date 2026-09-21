# ============================================================
# Balance de energía satelital (METRIC) — flujo principal
# ============================================================
# Estima evapotranspiración de cultivos a partir de imágenes
# Landsat 8 y datos de una estación meteorológica en tierra.
#
# Usa el paquete `water` (midraed/water) y un parche propio
# para el módulo de nubes del mismo paquete.
#
# Ver README.md para el contexto completo.
# ============================================================

# Ajustar según tu sistema
setwd("ruta/a/tu/directorio")
source("waterUtilsMod.R")

library(water)
library("R.utils")
library(filesstrings)
library(fs)
library(purrr)
library(stringr)
library(raster)

t <- proc.time()  # se pone al inicio del código
unzipL8()         # Descomprime la carpeta a nivel operativo (hasta llegar a capas)
DN_Rename()       # Renombra los archivos para que calcen con los nombres que tenían antes de que se diera la modificación a las capas de L8

aoi <- createAoi(topleft = c(650000, 1180000),
                 bottomright = c(730000, 1120000), EPSG = 32616)  # Genera un polígono de área de interés, con la esquina sup izq e inf der

csvfile_nombre <- paste(getwd(), list.files(path = getwd(), pattern = ".csv$"), sep = "/")  # Dirección del archivo csv (único en la carpeta, sino colapsa)
csvfile <- read.csv(csvfile_nombre, sep = ";")
summary(csvfile)

MTLfile <- list.files(path = getwd(), pattern = "MTL.txt", full.names = T)  # Dirección del archivo MTL

estacion <- "EstacionA"
# Aquí es o "EstacionB" o "EstacionA" OJO LAS MAYÚSCULAS
# Esto debe de modificarse cada vez que se usa una nueva estación

WeatherStation <- ws(estacion, csvfile, MTLfile)  # Función que carga la estación meteorológica, a partir de la dir, el csv y el MTL (hora)
summary(csvfile$Rad)
print(WeatherStation, hourly = FALSE)  # para ver los datos de la estación

DEM <- paste(getwd(), "/ASTER.tif", sep = "")
DEM <- raster(DEM)
# Carga el DEM

image.DN <- loadImage(sat = "L8", aoi = aoi)  # carga los números digitales de L8 al aoi

DEM <- raster::resample(DEM, image.DN[[1]])  # corta el DEM a la misma extensión del aoi

surface.model <- METRICtopo(DEM)  # Calcula DEM slope y aspect
solar.angles.r <- solarAngles(surface.model = surface.model,
                              WeatherStation = WeatherStation, MTL = MTLfile)  # Calcula el ángulo de inc relativa y otros

Rs.inc <- incSWradiation(surface.model = surface.model,
                         solar.angles = solar.angles.r,
                         WeatherStation = WeatherStation)  # Calcula la radiación solar incidente

image.TOAr <- calcTOAr(image.DN = image.DN, sat = "L8", MTL = MTLfile,
                       incidence.rel = solar.angles.r$incidence.rel)

image.SR <- loadImageSR(path = getwd(), aoi)

albedo <- albedo(image.SR = image.SR, aoi = aoi, coeff = "Olmedo", sat = "L8")  # Calcula albedo
albedo[albedo <= 0] <- NA
print(albedo)

LAI <- LAI(method = "metric2010", image = image.TOAr, L = 0.1)  # Calcula LAI
print(LAI)

Ts <- surfaceTemperature(image.DN = image.DN, sat = "L8", LAI = LAI, aoi = aoi, method = "SW",
                         WeatherStation = WeatherStation)  # Calcula Ts con split window
# pero debe siempre revisarse el valor que se obtiene
print(Ts)

Rl.out <- outLWradiation(LAI = LAI, Ts = Ts)  # Calcula radiación de onda larga emitida por la tierra hacia el espacio

Rl.inc <- incLWradiation(WeatherStation, DEM = surface.model$DEM,
                         solar.angles = solar.angles.r, Ts = Ts)  # Calcula radiación de onda larga emitida por la atmósfera hacia la tierra

Rn <- netRadiation(LAI, albedo, Rs.inc, Rl.inc, Rl.out)  # Hace la suma para calcular la radiación neta por balance

G <- soilHeatFlux(image = image.SR, Ts = Ts, albedo = albedo,
                  Rn = Rn, LAI = LAI, method = "Tasumi")  # Calcula G con eq 27

Z.om <- momentumRoughnessLength(LAI = LAI, mountainous = TRUE,
                                method = "short.crops",
                                surface.model = surface.model)  # Calcula z.om. Ojo a los métodos.
# Ahorita se usa un método poco exacto sin corrección de campo

hot.and.cold <- calcAnchors(image = image.TOAr, Ts = Ts, LAI = LAI, plots = F,
                            albedo = albedo, Z.om = Z.om, n = 5,
                            anchors.method = "best", deltaTemp = 5,  # random, best, flexible
                            WeatherStation = WeatherStation, verbose = FALSE)
# Encuentra una tabla con los mejores candidatos a pixel frío y caliente
print(hot.and.cold)

filasNA <- vector()
for (i in 1:nrow(hot.and.cold)) {
  if (is.na(Rn[hot.and.cold[i, 1]])) {
    filasNA <- c(filasNA, i)
  }
}
if (length(filasNA) != 0) hot.and.cold <- hot.and.cold[-filasNA, ]
# Todo este bloque elimina NA de la tabla de píxeles fríos y calientes

H <- calcH(anchors = hot.and.cold, Ts = Ts, Z.om = Z.om,
           WeatherStation = WeatherStation, ETp.coef = 1.05,
           Z.om.ws = 0.015, DEM = DEM, Rn = Rn, G = G, verbose = T, maxit = 30)  # Calcula H

ET_WS <- dailyET(WeatherStation = WeatherStation, MTL = MTLfile)  # Genera el cálculo de evapotranspiración de referencia con base en datos de WS y penman fao
print(ET_WS)

ET.24 <- ET24h(Rn, G, H$H, Ts, WeatherStation = WeatherStation, ETr.daily = ET_WS, C.rad = 1)  # Calcula la imagen de ET_24
print(ET.24)

LE <- Rn - G - H$H  # Es necesario hacerlo a mano para sacar el Kc. Esto es calor latente

ET.inst <- 3600 * LE / ((2.501 - 0.00236 * (Ts - 273.15)) * (1e+06))  # De calor latente se obtiene evapotranspiración
print(ET.inst)

ET_hWS <- hourlyET(WeatherStation = WeatherStation,
                   ET.instantaneous = FALSE)  # Calcula la ET horaria del día para la estación meteorológica

kc <- ET.inst / ET_hWS
kc[kc < 0] <- 0
print(kc)

L <- 0.1
NDVI <- (image.DN[[4]] - image.DN[[3]]) / (image.DN[[4]] + image.DN[[3]])
SAVI <- (1 + L) * (image.SR[[4]] - image.SR[[3]]) / (image.SR[[4]] + image.SR[[3]] + L)
print(NDVI)

ab <- data.frame(c(H$a, H$b), row.names = c("a", "b"))
colnames(ab) <- "valor"
head(ab)
# Genera tablas y rasters que se necesitan posteriormente, como el NDVI, SAVI, píxeles fríos y calientes y coeficientes de regresión de calor sensible

DOY <- format(WeatherStation$at.sat$datetime, "%j")  # Día de la toma en juliano
y <- format(WeatherStation$at.sat$datetime, "%y")    # Año

writeWater(estacion, ET.24, kc, albedo, Rn, G, H$H, Ts, LAI, SAVI, NDVI, DOY, LE, y)
writeWaterBase(estacion, ET.24, kc, albedo, Rn, G, H$H, Ts, LAI, SAVI, NDVI, hot.and.cold, ab, DOY, LE, y)

########### mueve el archivo bqa a la carpeta de nubes

bqa <- list.files(path = getwd(), pattern = "*bqa.tif", full.names = FALSE)
list.new <- file.path(getwd(), "nubes/bqa")
file.move(bqa, list.new)
cleanFolder()  # Borra los archivos que ya no se necesitan

x <- list.files(file.path(getwd(), "EstacionA"))

for (i in 1:length(x)) {
  lista1 <- file.path(getwd(), "EstacionA", x)
  listaNueva <- file.path(getwd(), "nubes/Recorte")
  current.folder <- list.files(path = lista1, full.names = TRUE)
  new.folder <- list.files(path = listaNueva, full.names = TRUE)
  file_copy(current.folder, new.folder, overwrite = FALSE)
}

file_delete(file.path(getwd(), "EstacionA"))       # borra todos los archivos
dir_create(file.path(getwd(), "EstacionA"))        # crea la primer carpeta de nuevo

for (i in 1:length(x)) {
  lista <- file.path(getwd(), "EstacionA", x)      # crea 11 carpetas, una por variable
  dir_create(lista)
}

setwd(file.path(getwd(), "nubes"))

bqa <- list.files(path = "bqa", pattern = ".tif", full.names = TRUE)                     # toma el archivo bqa de la carpeta seleccionada
recorte <- list.files(path = "Recorte/a b", pattern = ".tif", full.names = TRUE)         # toma el archivo al cual va a eliminar las nubes

resultado <- NULL  # valor nulo para comenzar
for (i in 1:length(recorte)) {

  rasBQA <- raster(bqa)                # transforma el archivo del bqa a un raster
  rasRec <- raster(recorte[i])         # transforma las variables a raster

  csv <- read.csv("reclassify.csv", sep = ";")  # lee el archivo con la información de los píxeles reclasificados. usar NA para los nulos
  print(csv)
  reclas <- reclassify(rasBQA, csv)    # reclasifica el raster del bqa

  RESULTADO <- reclas * rasRec         # multiplica el raster bqa con el raster de la variable, para eliminar las nubes
  file <- as.character(paste(recorte[i], sep = ""))  # toma el nombre de los archivos y se los asigna a los nuevos archivos
  print(file)
  writeRaster(RESULTADO, file, overwrite = TRUE)

}

file_delete(file.path(getwd(), "bqa"))  # borra todos los archivos
dir_create(file.path(getwd(), "bqa"))   # crea la primer carpeta de nuevo
writeRaster(reclas, file.path(getwd(), "reclassify.tif"), overwrite = TRUE)  # imprime el raster del bqa reclasificado

setwd("ruta/a/red")
writeWaterExt(estacion, ET.24, kc, albedo, Rn, G, H$H, Ts, LAI, SAVI, NDVI, hot.and.cold, ab, DOY, LE, y)

xP <- list.files("ruta/a/red")
xP

for (i in 1:length(xP)) {
  list <- list.files(path = file.path(getwd(), "nubes/Recorte/a b"), pattern = "*.tif", full.names = TRUE)
  listaNueva <- file.path("ruta/a/red", xP)
  file_copy(list, listaNueva, overwrite = FALSE)
}

file_delete(file.path(getwd(), "nubes/Recorte/a b"))  # borra todos los archivos
dir_create(file.path(getwd(), "nubes/Recorte/a b"))   # crea la primer carpeta de nuevo

# código dura aproximadamente 32.05 min
# 33.15 min considerando todas las modificaciones
proc.time() - t  # se pone al final del código
