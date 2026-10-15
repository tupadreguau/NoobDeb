#!/bin/bash

# Mensaje de bienvenida inicial
zenity --info --text="Gracias por usar NoobDeb, una aplicación que le facilitará la empaquetación de sus archivos deb. Recomendamos encarecidamente no cerrar la aplicación hasta terminar con el proceso, y seguir cuidadosamente las instrucciones. Hay funciones que se le pediran hacer manualmente, pero las mas importantes y tediosas se harán con la aplicación." --title="Bienvenido"

# Configuraciones iniciales de la aplicacion
resultado=$(zenity --forms --title="Configurar Aplicación Deb" \
    --text="Introduce los datos solicitados:" \
    --add-entry="Nombre de la aplicación:" \
    --add-entry="Versión:" \
    --add-entry="Sección (Se recomienda usar las siguientes, respetando la letra mayuscula: AudioVideo, Development, Education, Game, Graphics, Network, Office, Settings, System o Utility):" \
    --add-entry="Mantenedor:" \
    --add-entry="Descripción corta:")

# Zenity separa los valores devueltos usando el carácter barra vertical (|)
if [ -n "$resultado" ]; then
    # Extraemos los valores dividiendo la respuesta por el orden de los campos
    nombre_carpeta=$(echo "$resultado" | awk -F'|' '{print $1}')
    version=$(echo "$resultado" | awk -F'|' '{print $2}')
    seccion=$(echo "$resultado" | awk -F'|' '{print $3}')
    mantenedor=$(echo "$resultado" | awk -F'|' '{print $4}')
    descripcion=$(echo "$resultado" | awk -F'|' '{print $5}')

    # Verificamos que al menos el nombre de la aplicación no esté vacío
    if [ -n "$nombre_carpeta" ]; then
        ruta_carpeta="$HOME/$nombre_carpeta"
        
        # Creamos la estructura de directorios para el paquete deb
        mkdir -p "$ruta_carpeta/DEBIAN"
        mkdir -p "$ruta_carpeta/usr/bin"
        mkdir -p "$ruta_carpeta/usr/share/applications"
        mkdir -p "$ruta_carpeta/usr/share/pixmaps"
        mkdir -p "$ruta_carpeta/usr/share/$nombre_carpeta"

        # Guardamos la información en el archivo control de DEBIAN
        echo "Package: $nombre_carpeta" > "$ruta_carpeta/DEBIAN/control"
        echo "Version: $version" >> "$ruta_carpeta/DEBIAN/control"
        echo "Section: $seccion" >> "$ruta_carpeta/DEBIAN/control"
        echo "Priority: optional" >> "$ruta_carpeta/DEBIAN/control"
        echo "Architecture: amd64" >> "$ruta_carpeta/DEBIAN/control"
        echo "Depends: xdg-utils" >> "$ruta_carpeta/DEBIAN/control"
        echo "Maintainer: $mantenedor" >> "$ruta_carpeta/DEBIAN/control"
        echo "Description: $descripcion" >> "$ruta_carpeta/DEBIAN/control"
        
        zenity --info --text="¡Estructura de la aplicación '$nombre_carpeta' creada con éxito!" --title="Éxito"
    else
        zenity --warning --text="El nombre de la aplicación no puede estar vacío." --title="Aviso"
        exit 1
    fi
else
    zenity --warning --text="Operación cancelada." --title="Aviso"
    exit 1
fi

# Aviso al usuario para copiar los archivos principales manualmente
zenity --info --text="Ahora vamos a necesitar que copies manualmente los archivos principales de tu aplicación a la carpeta:\n\n$ruta_carpeta/usr/share/$nombre_carpeta. Recuerda que necesitas darle permiso para abrir como programa al archivo que se usará como aplicación, eso se hace en las propiedades del archivo." --title="Siguiente paso"

# Aviso sobre el icono
zenity --info --text="Ahora copia un archivo PNG a la carpeta:\n\n$ruta_carpeta/usr/share/pixmaps/\n\nEl archivo PNG debe llamarse exactamente igual que tu aplicación: '$nombre_carpeta.png' para que el paquete funcione bien. Este archivo servirá  como icono de tu aplicación. Es recomendable que sea de 128x128 o 512x512 pixeles." --title="Creación del icono"

# Siguiente paso: formulario adicional
appdirecta=$(zenity --forms --title="Seleccionar ejecutable" \
    --text="Introduce el nombre del archivo que se ejecutará una vez esté instalada la aplicación. El nombre debe incluir la extensión, por ejemplo: Miapp.AppImage" \
    --add-entry="Nombre del ejecutable:")

if [ -n "$appdirecta" ]; then
    nombreapp=$(echo "$appdirecta" | awk -F'|' '{print $1}')

    if [ -n "$nombreapp" ]; then
        # Ejemplo para crear otro archivo de texto plano adicional si lo requieres
        echo "bash /usr/share/$nombre_carpeta/$nombreapp" > "$ruta_carpeta/usr/bin/$nombre_carpeta"
        zenity --info --text="¡Información adicional guardada con éxito!" --title="Éxito"
    else
        zenity --warning --text="El campo no podía estar vacío." --title="Aviso"
    fi
else
    zenity --warning --text="Operación adicional cancelada." --title="Aviso"
fi

#Esto es para crear el archivo desktop
echo "[Desktop Entry]" > "$ruta_carpeta/usr/share/applications/$nombre_carpeta.desktop"
echo "Version=$version" >> "$ruta_carpeta/usr/share/applications/$nombre_carpeta.desktop"
echo "Type=Application" >> "$ruta_carpeta/usr/share/applications/$nombre_carpeta.desktop"
echo "Name=$nombre_carpeta" >> "$ruta_carpeta/usr/share/applications/$nombre_carpeta.desktop"
echo "Comment=$descripcion" >> "$ruta_carpeta/usr/share/applications/$nombre_carpeta.desktop"
echo "Exec=/usr/bin/$nombre_carpeta" >> "$ruta_carpeta/usr/share/applications/$nombre_carpeta.desktop"
echo "Icon=$nombre_carpeta" >> "$ruta_carpeta/usr/share/applications/$nombre_carpeta.desktop"
echo "Categories=$seccion" >> "$ruta_carpeta/usr/share/applications/$nombre_carpeta.desktop"

#Esto es para darle los permisos de usar como aplicación a los archivos necesarios.
chmod +x $ruta_carpeta/usr/bin/$nombre_carpeta

# Ultimo aviso sobre empaquetación
zenity --info --text="Este es el ultimo paso, si todo ha salido bien y haz seguido correctamente las instrucciones, despues de dar aceptar, se creara tu paquete deb." --title="Ultimo paso"

notify-send "Empaquetado en proceso" "Esto puede tardar varios minutos, tenga paciencia."

chmod 755 $ruta_carpeta/DEBIAN
dpkg-deb --build $ruta_carpeta

zenity --info --text="Listo, tu paquete deb ha sido creado con exito, puedes encontrarlo en $HOME" --title="Paquete deb creado con exito"
