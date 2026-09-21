# ============================================================
# Funciones auxiliares para waterMod.R
# ============================================================
# Utilidades para el pipeline de balance de energía satelital:
#   - Descompresión de imágenes Landsat 8
#   - Renombrado de bandas
#   - Carga de estaciones meteorológicas
#   - Escritura de rasters de salida
#
# Ver README.md para el contexto completo.
# ============================================================

library(raster)
library("R.utils")
library(water)

# Descomprime las imágenes Landsat 8.
# Debe colocarse el archivo .tar.gz descargado de L8 en el directorio de trabajo.
unzipL8 <- function() {

  targz <- list.files(path = getwd(), pattern = ".tar.gz", full.names = T)
  tarFile <- list.files(path = getwd(), pattern = ".tar", full.names = T)
  tarFile <- tarFile[tarFile != targz]

  if (length(tarFile) != 0) {
    return(print('ya está descomprimido el archivo'))
  }

  gunzip(targz, remove = F)
  tarFile <- list.files(path = getwd(), pattern = ".tar", full.names = T)
  tarFile <- tarFile[tarFile != targz]
  untar(tarFile)
}

# Elimina las imágenes descomprimidas
cleanFolder <- function() {

  targz <- list.files(path = getwd(), pattern = ".tar.gz", full.names = T)
  images <- list.files(path = getwd(), pattern = "LC8", full.names = T)
  images <- images[images != targz]
  unlink(images)
}

# Cambia el nombre de las imágenes de números digitales.
# El algoritmo water usa "...B1.tif" (MAYÚSCULA) y las de ESPA vienen como "...b1.tif" (minúscula).
# Además, cambia el nombre de las imágenes nuevas, porque cuando se creó el algoritmo
# estas venían con nombres con otro formato.
DN_Rename <- function() {

  nombresArch <- list.files(path = getwd(), pattern = "T1")
  tars <- list.files(path = getwd(), pattern = ".tar.gz")
  nombresArch <- nombresArch[!nombresArch %in% tars]

  sepNombres <- strsplit(nombresArch, "T1")
  terminacion <- sapply(sepNombres, `[[`, 2)

  sepGuiones <- strsplit(nombresArch[1], "_")
  codigoPosic <- sepGuiones[[1]][3]
  fecha <- sepGuiones[[1]][4]
  fecha.formato <- as.Date(paste(substring(fecha, c(1, 5, 7), c(4, 6, 8)), collapse = "-"), "%Y-%m-%d")
  año <- format(fecha.formato, "%Y")
  DOY <- format(fecha.formato, "%j")
  inicioNombre <- paste0("LC8", codigoPosic, año, DOY, "LGN00")

  nuevosNombres <- paste0(inicioNombre, terminacion)
  nombresArch <- paste(getwd(), nombresArch, sep = "/")
  nuevosNombres <- paste(getwd(), nuevosNombres, sep = "/")
  file.rename(nombresArch, nuevosNombres)

  for (i in 1:11) {
    a <- list.files(path = getwd(), pattern = paste0("^L[EC]\\d+\\w+\\d+_(b)", i, ".(TIF|tif)$"))
    b <- toupper(a)
    a <- paste(getwd(), a, sep = "/")
    b <- paste(getwd(), b, sep = "/")
    file.rename(a, b)
  }
}

# Asigna las coordenadas a la variable tipo ws según la estación.
# Aquí puede agregarse más estaciones de ser necesario.
ws <- function(nombre, csvfile, MTLfile) {

  switch (nombre,
    EstacionA = {
      ws <- read.WSdata(WSdata = csvfile,
                        date.format = "%d/%m/%Y",
                        lat = 10.34398, long = -85.33857,
                        elev = 7, height = 10,
                        MTL = MTLfile)
    },
    EstacionB = {
      ws <- read.WSdata(WSdata = csvfile,
                        date.format = "%d/%m/%Y", time.format = "%H:%M:%S",
                        lat = 10.464732, long = -85.107920,
                        elev = 65, height = 10,
                        cf = c(1, 0.27777778, 1),  # la estación tiene la velocidad en KM/H, se convierte a m/s
                        MTL = MTLfile)
    }
  )
}

# Escribe las capas en la carpeta correspondiente (salida intermedia por estación)
writeWater <- function(direc, ET.24, kc, albedo, Rn, G, H, Ts, LAI, SAVI, NDVI, DOY, LE, y) {

  switch (direc,
    EstacionA = {
      writeRaster(ET.24, filename = paste(getwd(), "/EstacionA/", "/ET/", "20", y, "_", DOY, "_ET24.tif", sep = ""), overwrite = T)
      writeRaster(kc, filename = paste(getwd(), "/EstacionA/", "/Kcb/", "20", y, "_", DOY, "_KCB.tif", sep = ""), overwrite = T)
      writeRaster(albedo, filename = paste(getwd(), "/EstacionA/", "/albedo/", "20", y, "_", DOY, "_albedo.tif", sep = ""), overwrite = T)
      writeRaster(Rn, filename = paste(getwd(), "/EstacionA/", "/Rn/", "20", y, "_", DOY, "_Rn.tif", sep = ""), overwrite = T)
      writeRaster(G, filename = paste(getwd(), "/EstacionA/", "/G/", "20", y, "_", DOY, "_G.tif", sep = ""), overwrite = T)
      writeRaster(H, filename = paste(getwd(), "/EstacionA/", "/H/", "20", y, "_", DOY, "_H.tif", sep = ""), overwrite = T)
      writeRaster(Ts, filename = paste(getwd(), "/EstacionA/", "/Ts/", "20", y, "_", DOY, "_Ts.tif", sep = ""), overwrite = T)
      writeRaster(LAI, filename = paste(getwd(), "/EstacionA/", "/LAI/", "20", y, "_", DOY, "_LAI.tif", sep = ""), overwrite = T)
      writeRaster(SAVI, filename = paste(getwd(), "/EstacionA/", "/SAVI/", "20", y, "_", DOY, "_SAVI.tif", sep = ""), overwrite = T)
      writeRaster(NDVI, filename = paste(getwd(), "/EstacionA/", "/NDVI/", "20", y, "_", DOY, "_NDVI.tif", sep = ""), overwrite = T)
      writeRaster(LE, filename = paste(getwd(), "/EstacionA/", "/LE/", "20", y, "_", DOY, "_LE.tif", sep = ""), overwrite = T)
    },
    EstacionB = {
      writeRaster(ET.24, filename = paste(getwd(), "/EstacionB/", "/ET/", "20", y, "_", DOY, "_ET24.tif", sep = ""), overwrite = T)
      writeRaster(kc, filename = paste(getwd(), "/EstacionB/", "/Kcb/", "20", y, "_", DOY, "_KCB.tif", sep = ""), overwrite = T)
      writeRaster(albedo, filename = paste(getwd(), "/EstacionB/", "/albedo/", "20", y, "_", DOY, "_albedo.tif", sep = ""), overwrite = T)
      writeRaster(Rn, filename = paste(getwd(), "/EstacionB/", "/Rn/", "20", y, "_", DOY, "_Rn.tif", sep = ""), overwrite = T)
      writeRaster(G, filename = paste(getwd(), "/EstacionB/", "/G/", "20", y, "_", DOY, "_G.tif", sep = ""), overwrite = T)
      writeRaster(H, filename = paste(getwd(), "/EstacionB/", "/H/", "20", y, "_", DOY, "_H.tif", sep = ""), overwrite = T)
      writeRaster(Ts, filename = paste(getwd(), "/EstacionB/", "/Ts/", "20", y, "_", DOY, "_Ts.tif", sep = ""), overwrite = T)
      writeRaster(LAI, filename = paste(getwd(), "/EstacionB/", "/LAI/", "20", y, "_", DOY, "_LAI.tif", sep = ""), overwrite = T)
      writeRaster(SAVI, filename = paste(getwd(), "/EstacionB/", "/SAVI/", "20", y, "_", DOY, "_SAVI.tif", sep = ""), overwrite = T)
      writeRaster(NDVI, filename = paste(getwd(), "/EstacionB/", "/NDVI/", "20", y, "_", DOY, "_NDVI.tif", sep = ""), overwrite = T)
      writeRaster(LE, filename = paste(getwd(), "/EstacionB/", "/LE/", "20", y, "_", DOY, "_LE.tif", sep = ""), overwrite = T)
    }
  )
}

# Escribe las capas en la carpeta BaseDatos (respaldo con datos completos)
writeWaterBase <- function(direc, ET.24, kc, albedo, Rn, G, H, Ts, LAI, SAVI, NDVI, h.c, ab, DOY, LE, y) {

  switch (direc,
    EstacionA = {
      writeRaster(ET.24, filename = paste(getwd(), "/BaseDatos/EstacionA/", "/ET/", "20", y, "_", DOY, "_ET24.tif", sep = ""), overwrite = T)
      writeRaster(kc, filename = paste(getwd(), "/BaseDatos/EstacionA/", "/Kcb/", "20", y, "_", DOY, "_KCB.tif", sep = ""), overwrite = T)
      writeRaster(albedo, filename = paste(getwd(), "/BaseDatos/EstacionA/", "/albedo/", "20", y, "_", DOY, "_albedo.tif", sep = ""), overwrite = T)
      writeRaster(Rn, filename = paste(getwd(), "/BaseDatos/EstacionA/", "/Rn/", "20", y, "_", DOY, "_Rn.tif", sep = ""), overwrite = T)
      writeRaster(G, filename = paste(getwd(), "/BaseDatos/EstacionA/", "/G/", "20", y, "_", DOY, "_G.tif", sep = ""), overwrite = T)
      writeRaster(H, filename = paste(getwd(), "/BaseDatos/EstacionA/", "/H/", "20", y, "_", DOY, "_H.tif", sep = ""), overwrite = T)
      writeRaster(Ts, filename = paste(getwd(), "/BaseDatos/EstacionA/", "/Ts/", "20", y, "_", DOY, "_Ts.tif", sep = ""), overwrite = T)
      writeRaster(LAI, filename = paste(getwd(), "/BaseDatos/EstacionA/", "/LAI/", "20", y, "_", DOY, "_LAI.tif", sep = ""), overwrite = T)
      writeRaster(SAVI, filename = paste(getwd(), "/BaseDatos/EstacionA/", "/SAVI/", "20", y, "_", DOY, "_SAVI.tif", sep = ""), overwrite = T)
      writeRaster(NDVI, filename = paste(getwd(), "/BaseDatos/EstacionA/", "/NDVI/", "20", y, "_", DOY, "_NDVI.tif", sep = ""), overwrite = T)
      writeRaster(LE, filename = paste(getwd(), "/BaseDatos/EstacionA/", "/LE/", "20", y, "_", DOY, "_LE.tif", sep = ""), overwrite = T)
      write.csv(h.c, file = paste(getwd(), "/BaseDatos/EstacionA/", "/hot cold/", "20", y, "_", DOY, "_hotcold.csv", sep = ""))
      write.csv(ab, file = paste(getwd(), "/BaseDatos/EstacionA/", "/a b/", "20", y, "_", DOY, "_ab.csv", sep = ""))
    },
    EstacionB = {
      writeRaster(ET.24, filename = paste(getwd(), "/BaseDatos/EstacionB/", "/ET/", "20", y, "_", DOY, "_ET24.tif", sep = ""), overwrite = T)
      writeRaster(kc, filename = paste(getwd(), "/BaseDatos/EstacionB/", "/Kcb/", "20", y, "_", DOY, "_KCB.tif", sep = ""), overwrite = T)
      writeRaster(albedo, filename = paste(getwd(), "/BaseDatos/EstacionB/", "/albedo/", "20", y, "_", DOY, "_albedo.tif", sep = ""), overwrite = T)
      writeRaster(Rn, filename = paste(getwd(), "/BaseDatos/EstacionB/", "/Rn/", "20", y, "_", DOY, "_Rn.tif", sep = ""), overwrite = T)
      writeRaster(G, filename = paste(getwd(), "/BaseDatos/EstacionB/", "/G/", "20", y, "_", DOY, "_G.tif", sep = ""), overwrite = T)
      writeRaster(H, filename = paste(getwd(), "/BaseDatos/EstacionB/", "/H/", "20", y, "_", DOY, "_H.tif", sep = ""), overwrite = T)
      writeRaster(Ts, filename = paste(getwd(), "/BaseDatos/EstacionB/", "/Ts/", "20", y, "_", DOY, "_Ts.tif", sep = ""), overwrite = T)
      writeRaster(LAI, filename = paste(getwd(), "/BaseDatos/EstacionB/", "/LAI/", "20", y, "_", DOY, "_LAI.tif", sep = ""), overwrite = T)
      writeRaster(SAVI, filename = paste(getwd(), "/BaseDatos/EstacionB/", "/SAVI/", "20", y, "_", DOY, "_SAVI.tif", sep = ""), overwrite = T)
      writeRaster(NDVI, filename = paste(getwd(), "/BaseDatos/EstacionB/", "/NDVI/", "20", y, "_", DOY, "_NDVI.tif", sep = ""), overwrite = T)
      writeRaster(LE, filename = paste(getwd(), "/BaseDatos/EstacionB/", "/LE/", "20", y, "_", DOY, "_LE.tif", sep = ""), overwrite = T)
      write.csv(h.c, file = paste(getwd(), "/BaseDatos/EstacionB/", "/hot cold/", "20", y, "_", DOY, "_hotcold.csv", sep = ""))
      write.csv(ab, file = paste(getwd(), "/BaseDatos/EstacionB/", "/a b/", "20", y, "_", DOY, "_ab.csv", sep = ""))
    }
  )
}

# Escribe las capas en una carpeta externa (salida final a red)
writeWaterExt <- function(direc, ET.24, kc, albedo, Rn, G, H, Ts, LAI, SAVI, NDVI, h.c, ab, DOY, LE, y) {

  switch (direc,
    EstacionA = {
      writeRaster(ET.24, filename = paste(getwd(), "/ET/", "20", y, "_", DOY, "_ET24.tif", sep = ""), overwrite = T)
      writeRaster(kc, filename = paste(getwd(), "/Kcb/", "20", y, "_", DOY, "_KCB.tif", sep = ""), overwrite = T)
      writeRaster(albedo, filename = paste(getwd(), "/albedo/", "20", y, "_", DOY, "_albedo.tif", sep = ""), overwrite = T)
      writeRaster(Rn, filename = paste(getwd(), "/Rn/", "20", y, "_", DOY, "_Rn.tif", sep = ""), overwrite = T)
      writeRaster(G, filename = paste(getwd(), "/G/", "20", y, "_", DOY, "_G.tif", sep = ""), overwrite = T)
      writeRaster(H, filename = paste(getwd(), "/H/", "20", y, "_", DOY, "_H.tif", sep = ""), overwrite = T)
      writeRaster(Ts, filename = paste(getwd(), "/Ts/", "20", y, "_", DOY, "_Ts.tif", sep = ""), overwrite = T)
      writeRaster(LAI, filename = paste(getwd(), "/LAI/", "20", y, "_", DOY, "_LAI.tif", sep = ""), overwrite = T)
      writeRaster(SAVI, filename = paste(getwd(), "/SAVI/", "20", y, "_", DOY, "_SAVI.tif", sep = ""), overwrite = T)
      writeRaster(NDVI, filename = paste(getwd(), "/NDVI/", "20", y, "_", DOY, "_NDVI.tif", sep = ""), overwrite = T)
      writeRaster(LE, filename = paste(getwd(), "/LE/", "20", y, "_", DOY, "_LE.tif", sep = ""), overwrite = T)
      write.csv(h.c, file = paste(getwd(), "/hot cold/", "20", y, "_", DOY, "_hotcold.csv", sep = ""))
      write.csv(ab, file = paste(getwd(), "/a b/", "20", y, "_", DOY, "_ab.csv", sep = ""))
    },
    EstacionB = {
      writeRaster(ET.24, filename = paste(getwd(), "/ET/", "20", y, "_", DOY, "_ET24.tif", sep = ""), overwrite = T)
      writeRaster(kc, filename = paste(getwd(), "/Kcb/", "20", y, "_", DOY, "_KCB.tif", sep = ""), overwrite = T)
      writeRaster(albedo, filename = paste(getwd(), "/albedo/", "20", y, "_", DOY, "_albedo.tif", sep = ""), overwrite = T)
      writeRaster(Rn, filename = paste(getwd(), "/Rn/", "20", y, "_", DOY, "_Rn.tif", sep = ""), overwrite = T)
      writeRaster(G, filename = paste(getwd(), "/G/", "20", y, "_", DOY, "_G.tif", sep = ""), overwrite = T)
      writeRaster(H, filename = paste(getwd(), "/H/", "20", y, "_", DOY, "_H.tif", sep = ""), overwrite = T)
      writeRaster(Ts, filename = paste(getwd(), "/Ts/", "20", y, "_", DOY, "_Ts.tif", sep = ""), overwrite = T)
      writeRaster(LAI, filename = paste(getwd(), "/LAI/", "20", y, "_", DOY, "_LAI.tif", sep = ""), overwrite = T)
      writeRaster(SAVI, filename = paste(getwd(), "/SAVI/", "20", y, "_", DOY, "_SAVI.tif", sep = ""), overwrite = T)
      writeRaster(NDVI, filename = paste(getwd(), "/NDVI/", "20", y, "_", DOY, "_NDVI.tif", sep = ""), overwrite = T)
      writeRaster(LE, filename = paste(getwd(), "/LE/", "20", y, "_", DOY, "_LE.tif", sep = ""), overwrite = T)
      write.csv(h.c, file = paste(getwd(), "/hot cold/", "20", y, "_", DOY, "_hotcold.csv", sep = ""))
      write.csv(ab, file = paste(getwd(), "/a b/", "20", y, "_", DOY, "_ab.csv", sep = ""))
    }
  )
}
