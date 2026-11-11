#!/bin/bash
# --------------------------------------
#Instalación automática de webmin para 
# ubuntu server 24.04.5 LTS 64 bits
#----------------------------------------
set -e
clear

    # ------------ PALETA DE COLORES -------------
	ROJO='\033[0;31m'
	VERDE='\033[0;32m'
	AMARILLO='\033[1;33m'
	AZUL='\033[0;34m'
	CIAN='\033[0;36m'
	SINCOLOR='\033[0m'

InstalarWebmin() {
if [ $(id -u) -ne 0 ]; then
    echo -e "${ROJO}Este script requiere permisos de sudo${SINCOLOR}"
	exit 1
   
    else

    # ------------ REVISAR INTERNET -------------
	if [ "$(nmcli networking connectivity check)" = "full" ]; then
    	echo -e "${AMARILLO}Hay conexión a internet${SINCOLOR}"
		else
    	exit 1
	fi

    # ------------ VERSIÓN SOPORTADA -------------
	version=$(lsb_release -rs 2>/dev/null | grep -oP '^\d{2}\.\d{2}')
	declare -A version_soportada=(
    	["22.04"]=1
    	["24.04"]=1
    	["26.04"]=1
    	)

	if [[ -z "${version_soportada[$version]}" ]]; then
    	echo -e "Este script requiere Ubuntu 22.04, 24.04 o 26.04"
    	exit 1
	fi

    # ------------ ELIMINAR BLOQUEOS -------------
 	for lock in /var/lib/dpkg/lock-frontend \
            /var/cache/apt/archives/lock \
            /var/lib/apt/lists/lock \
            /var/lib/dpkg/lock; do
        [ -f "$lock" ] && rm "$lock"
	done

    # ---- EWPARACIÓN, ACTUALIZACIÓN Y LIMPIEZA ---
	export DEBIAN_FRONTEND=noninteractive
	export NEEDRESTART_MODE=a

	# Rescate inicial (ignora errores si faltan índices de repositorios)
	dpkg --force-confdef --force-confold --configure -a || true
	apt-get -y -f install || true

	# Sincronización de repositorios y reparación definitiva
	apt-get update
	apt-get -y --fix-broken \
    	-o Dpkg::Options::="--force-confdef" \
    	-o Dpkg::Options::="--force-confold" \
    install

	# Actualización completa y limpieza
	apt-get -y \
    	-o Dpkg::Options::="--force-confdef" \
    	-o Dpkg::Options::="--force-confold" \
    full-upgrade

	apt-get -y autoremove --purge
	apt-get -y clean

    # ---- DEPENDENCIAS PARA WEBMIN ---
	paquetes=(
    curl                    # Descarga archivos desde URL
    gnupg2                  # Gestiona llaves de seguridad GPG
    ca-certificates         # Certificados SSL de confianza
    apt-transport-https     # Permite repositorios por HTTPS
    perl                    # Lenguaje base de Webmin
    libnet-ssleay-perl      # Soporte SSL/HTTPS en Perl
    openssl                 # Herramientas de cifrado SSL/TLS
    libauthen-pam-perl      # Autenticación de usuarios Linux
    libpam-runtime          # Módulos base de autenticación PAM
    libio-pty-perl          # Terminal web interactiva en Webmin
    shared-mime-info        # Detecta tipos de archivos (MIME)
    rar                     # Manejo de archivos RAR
    unrar                   # Extrae archivos RAR
    zip                     # Compresión ZIP
    unzip                   # Extrae archivos ZIP
    p7zip-full              # Soporte para 7z
    arj                     # Soporte para archivos ARJ
    cabextract              # Extrae archivos CAB
    file-roller             # Gestor de archivos comprimidos en GNOME
	)
	apt-get -y install "${paquetes[@]}"

	# ---- AÑADIR REPOSITORIO OFICIAL DE WEBMIN ---
	echo -e "${AMARILLO}Configurando repositorio oficial de Webmin...${SINCOLOR}"
	curl -fsSL -o /tmp/webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
	sh /tmp/webmin-setup-repo.sh
	rm -f /tmp/webmin-setup-repo.sh

	# ---- INSTALAR WEBMIN ---
	echo -e "${AMARILLO}Instalando Webmin...${SINCOLOR}"
	apt-get -y install --install-recommends webmin
fi
}

# ---- FUNCIÓN PARA DESINSTALAR WEBMIN ----
DesinstalarWebmin() {
    echo -e "${AMARILLO}Iniciando la desinstalación de Webmin...${SINCOLOR}"

    # Detener el servicio (ignorar errores si no existe)
    if systemctl is-active --quiet webmin 2>/dev/null; then
        echo -e "${CIAN}Deteniendo el servicio webmin...${SINCOLOR}"
        systemctl stop webmin
    fi

    # Eliminar el paquete y sus configuraciones
    echo -e "${CIAN}Eliminando el paquete webmin...${SINCOLOR}"
    apt-get -y purge webmin || true

    # Eliminar el repositorio y la clave GPG añadidos por el instalador
    echo -e "${CIAN}Eliminando repositorio y clave GPG de Webmin...${SINCOLOR}"
    rm -f /etc/apt/sources.list.d/webmin.list
    rm -f /usr/share/keyrings/webmin.gpg
    # Actualizar la lista de paquetes para reflejar la eliminación
    apt-get update -qq || true

    # Eliminar archivos y directorios residuales
    echo -e "${CIAN}Eliminando archivos residuales...${SINCOLOR}"
    rm -rf /etc/webmin
    rm -rf /var/webmin
    rm -rf /usr/share/webmin
    rm -rf /tmp/.webmin

    # Eliminar el usuario y grupo del sistema (si existen)
    if id "webmin" &>/dev/null; then
        echo -e "${CIAN}Eliminando usuario del sistema webmin...${SINCOLOR}"
        userdel webmin 2>/dev/null || true
        groupdel webmin 2>/dev/null || true
    fi

    # Limpieza final de paquetes huérfanos
    echo -e "${CIAN}Limpiando paquetes huérfanos...${SINCOLOR}"
    apt-get -y autoremove --purge
    apt-get -y clean

    # Verificación final
    if [ ! -d "/etc/webmin" ] && [ ! -d "/usr/share/webmin" ]; then
        echo -e "${VERDE}Webmin ha sido desinstalado y limpiado correctamente.${SINCOLOR}"
    else
        echo -e "${ROJO}La desinstalación terminó, pero aún quedan algunos archivos residuales.${SINCOLOR}"
    fi
}

# ---- FUNCIÓN PARA COMPROBAR SI WEBMIN ESTÁ INSTALADO ----
ComprobarWebmin() {
    dpkg -l webmin 2>/dev/null | grep -q '^ii' || [ -d "/etc/webmin" ]
}

# ---- MENÚ INTERACTIVO ----
MenuWebmin() {
    clear
    echo -e "${CIAN}========================================${SINCOLOR}"
    echo -e "${CIAN}   GESTOR DE WEBMIN - Ubuntu Server    ${SINCOLOR}"
    echo -e "${CIAN}========================================${SINCOLOR}"
    echo

    if ComprobarWebmin; then
        # ---------- WEBMIN INSTALADO ----------
        echo
        echo -e "${AMARILLO}Opciones disponibles:${SINCOLOR}"
        echo -e "  ${VERDE}1)${SINCOLOR} Desinstalar Webmin"
        echo -e "  ${VERDE}2)${SINCOLOR} Desinstalar y reinstalar completamente"
        echo -e "  ${VERDE}3)${SINCOLOR} Salir sin cambios"
        echo
        printf "Selecciona una opción [1-3]: " 
        read -r opcion

        case "$opcion" in
            1)
                echo
                printf "${AMARILLO}¿Seguro que quieres desinstalar Webmin? [s/N]: ${SINCOLOR}" 
                read -r resp
                if [[ "$resp" =~ ^[sS]$ ]]; then
                    DesinstalarWebmin
                else
                    echo -e "${AMARILLO}Operación cancelada.${SINCOLOR}"
                fi
                ;;
            2)
                echo
                printf "${AMARILLO}¿Seguro que quieres desinstalar y reinstalar Webmin? [s/N]: ${SINCOLOR}" 
                read -r resp
                if [[ "$resp" =~ ^[sS]$ ]]; then
                    DesinstalarWebmin
                    echo
                    echo -e "${CIAN}Reiniciando instalación de Webmin...${SINCOLOR}"
                    InstalarWebmin
                else
                    echo -e "${AMARILLO}Operación cancelada.${SINCOLOR}"
                fi
                ;;
            3)
                echo -e "${AMARILLO}Saliendo sin cambios.${SINCOLOR}"
                ;;
            *)
                echo -e "${ROJO}Opción no válida.${SINCOLOR}"
                ;;
        esac

    else
        # ---------- WEBMIN NO INSTALADO ----------
        echo
        echo -e "${AMARILLO}Webmin no está instalado en este sistema.${SINCOLOR}"
        echo
        printf "${AMARILLO}¿Quieres instalarlo ahora? [s/N]: ${SINCOLOR}"
		read -r resp
        if [[ "$resp" =~ ^[sS]$ ]]; then
            InstalarWebmin
        else
            echo -e "${AMARILLO}Instalación cancelada. Saliendo.${SINCOLOR}"
        fi
    fi
}

MenuWebmin





