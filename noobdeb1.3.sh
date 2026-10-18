#!/bin/bash

# 1. Formulario único de datos básicos
datos=$(zenity --forms --title="NoobDeb 1.3 - Datos del Paquete" \
    --text="Ingresa la información de tu aplicación:" \
    --separator="|" \
    --add-entry="Nombre de la aplicación (ej. Mi Juego)" \
    --add-entry="Versión (ej. 1.0.0)" \
    --add-entry="Mantenedor / Autor (ej. Chanok <correo@ejemplo.com>)" \
    --add-entry="Descripción breve") || exit 0

IFS="|" read -r nombre_app version_raw autor descripcion <<< "$datos"

if [ -z "$nombre_app" ]; then
    zenity --error --text="El nombre de la aplicación es obligatorio."
    exit 1
fi

# Limpiar el nombre para que dpkg-deb no marque error (solo minúsculas, números y guiones)
paquete_limpio=$(echo "$nombre_app" | iconv -t ascii//TRANSLIT 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9+.-]/-/g' | sed 's/^-*//;s/-*$//')
[ -z "$paquete_limpio" ] && paquete_limpio="mi-aplicacion"

# Limpiar versión (dpkg exige que empiece con número y sin espacios)
version_limpia=$(echo "$version_raw" | tr -cd '0-9a-zA-Z.+~-' | sed 's/^[^0-9]*//')
[ -z "$version_limpia" ] && version_limpia="1.0.0"

[ -z "$autor" ] && autor="Usuario <usuario@localhost>"
[ -z "$descripcion" ] && descripcion="Aplicación empaquetada con NoobDeb 1.3"

# 2. Selección de Categoría y Arquitectura
categoria=$(zenity --list --radiolist --title="Categoría" \
    --text="Selecciona la categoría en el menú de aplicaciones:" \
    --column="Elegir" --column="Categoría" --column="Descripción" \
    TRUE "Game" "Juegos" \
    FALSE "Utility" "Accesorios / Utilidades" \
    FALSE "Development" "Desarrollo" \
    FALSE "AudioVideo" "Multimedia (Audio y Video)" \
    FALSE "Graphics" "Gráficos" \
    FALSE "Office" "Oficina" \
    FALSE "System" "Sistema") || exit 0

arquitectura=$(zenity --list --radiolist --title="Arquitectura" \
    --text="Selecciona la arquitectura del paquete:" \
    --column="Elegir" --column="Arquitectura" --column="Descripción" \
    TRUE "amd64" "PC 64 bits (Estándar actual)" \
    FALSE "i386" "PC 32 bits" \
    FALSE "arm64" "ARM 64 bits (Raspberry Pi / Consolas ARM)" \
    FALSE "all" "Independiente (Scripts / HTML / Python)") || exit 0

# 3. Seleccionar el ejecutable principal, HTML o AppImage
ruta_ejecutable=$(zenity --file-selection --title="Selecciona el ejecutable principal, script, HTML o AppImage") || exit 0
nombre_ejecutable=$(basename "$ruta_ejecutable")
carpeta_origen=$(dirname "$ruta_ejecutable")

# Preguntar si necesita toda su carpeta o es un binario/AppImage suelto
if zenity --question --title="Modo de empaquetado" \
    --ok-label="Toda la carpeta (Juego con recursos)" \
    --cancel-label="Solo el archivo (AppImage / Binario único)" \
    --text="¿Tu aplicación necesita los demás archivos de la carpeta '$carpeta_origen'?\n\n• Elige 'Toda la carpeta' si tiene sonidos, imágenes o archivos junto al ejecutable.\n• Elige 'Solo el archivo' si es un AppImage o binario independiente."; then
    modo_copia="carpeta"
else
    modo_copia="unico"
fi

# 4. Seleccionar el ícono (.png)
ruta_icono=$(zenity --file-selection --title="Selecciona el ícono (.png) para tu aplicación" \
    --file-filter="Imágenes PNG (*.png) | *.png *.PNG") || exit 0

# 5. Seleccionar carpeta donde se guardará el .deb
ruta_salida=$(zenity --file-selection --directory --title="Selecciona dónde guardar tu paquete .deb terminado") || exit 0

# 6. Construcción de la estructura en carpeta temporal
dir_temporal=$(mktemp -d "/tmp/noobdeb_${paquete_limpio}_XXXXXX")
ruta_paquete="$dir_temporal/${paquete_limpio}_${version_limpia}_${arquitectura}"

mkdir -p "$ruta_paquete/DEBIAN"
mkdir -p "$ruta_paquete/usr/bin"
mkdir -p "$ruta_paquete/usr/share/applications"
mkdir -p "$ruta_paquete/usr/share/pixmaps"
mkdir -p "$ruta_paquete/usr/share/$paquete_limpio"

# Copiar archivos y dar permisos automáticamente
if [ "$modo_copia" = "carpeta" ]; then
    cp -r "$carpeta_origen"/. "$ruta_paquete/usr/share/$paquete_limpio/"
else
    cp "$ruta_ejecutable" "$ruta_paquete/usr/share/$paquete_limpio/"
fi
chmod +x "$ruta_paquete/usr/share/$paquete_limpio/$nombre_ejecutable"

# Copiar y renombrar el ícono automáticamente
cp "$ruta_icono" "$ruta_paquete/usr/share/pixmaps/${paquete_limpio}.png"
chmod 644 "$ruta_paquete/usr/share/pixmaps/${paquete_limpio}.png"

# Crear el script lanzador en /usr/bin (protegido contra expansión prematura)
cat << 'EOF' > "$ruta_paquete/usr/bin/$paquete_limpio"
#!/bin/sh
cd "/usr/share/__PAQUETE_REPLACE__" || exit 1
case "__EJECUTABLE_REPLACE__" in
    *.html|*.htm|*.HTML|*.HTM)
        exec xdg-open "./__EJECUTABLE_REPLACE__"
        ;;
    *)
        exec "./__EJECUTABLE_REPLACE__" "$@"
        ;;
esac
EOF

# Reemplazar las marcas en el lanzador con las variables reales de forma segura
sed -i "s|__PAQUETE_REPLACE__|$paquete_limpio|g" "$ruta_paquete/usr/bin/$paquete_limpio"
sed -i "s|__EJECUTABLE_REPLACE__|$nombre_ejecutable|g" "$ruta_paquete/usr/bin/$paquete_limpio"
chmod 755 "$ruta_paquete/usr/bin/$paquete_limpio"

# Crear archivo .desktop
cat << EOF > "$ruta_paquete/usr/share/applications/${paquete_limpio}.desktop"
[Desktop Entry]
Type=Application
Name=$nombre_app
Version=$version_limpia
Comment=$descripcion
Exec=/usr/bin/$paquete_limpio
Icon=$paquete_limpio
Terminal=false
Categories=$categoria;
EOF
chmod 644 "$ruta_paquete/usr/share/applications/${paquete_limpio}.desktop"

# Calcular peso instalado en KB
peso_kb=$(du -ks "$ruta_paquete/usr" | cut -f1)
seccion_limpia=$(echo "$categoria" | tr '[:upper:]' '[:lower:]')

# Crear archivo DEBIAN/control
cat << EOF > "$ruta_paquete/DEBIAN/control"
Package: $paquete_limpio
Version: $version_limpia
Section: $seccion_limpia
Priority: optional
Architecture: $arquitectura
Installed-Size: $peso_kb
Maintainer: $autor
Description: $descripcion
EOF
chmod 755 "$ruta_paquete/DEBIAN"
chmod 644 "$ruta_paquete/DEBIAN/control"

# 7. Empaquetar con dpkg-deb
archivo_final="$ruta_salida/${paquete_limpio}_${version_limpia}_${arquitectura}.deb"

if dpkg-deb --root-owner-group --build "$ruta_paquete" "$archivo_final" 2>/dev/null || dpkg-deb --build "$ruta_paquete" "$archivo_final"; then
    rm -rf "$dir_temporal"
    zenity --info --title="¡Paquete creado con éxito!" \
        --text="Tu paquete Debian se ha generado correctamente en:\n\n<b>$archivo_final</b>"
else
    zenity --error --title="Error al empaquetar" \
        --text="Hubo un fallo con dpkg-deb. Revisa los archivos temporales en:\n$ruta_paquete"
    exit 1
fi
