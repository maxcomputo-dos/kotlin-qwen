#!/usr/bin/env bash

# Script limpio y funcional para iniciar Tmate en Codespaces
# Soluciona el problema de indentación del script original
# Autor: Assistant
# Fecha: 12/12/2025

set -e  # Salir si algún comando falla

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Iniciando Tmate en Codespaces con reinicio automático${NC}"

# Ruta al archivo .env donde se guardarán las variables
ENV_FILE="/workspaces/kotlin-qwen/.env"

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para detener procesos anteriores de tmate
stop_tmate_processes() {
    echo -e "${YELLOW}Deteniendo procesos anteriores de tmate...${NC}"

    # Obtener todos los procesos de tmate excepto el actual grep
    TMATE_PIDS=$(pgrep tmate 2>/dev/null)

    if [ -n "$TMATE_PIDS" ]; then
        echo -e "${YELLOW}Terminando procesos de tmate:${NC} $TMATE_PIDS"
        kill $TMATE_PIDS 2>/dev/null || true

        # Esperar un momento para asegurar que los procesos se hayan detenido
        sleep 2

        # Verificar si aún hay procesos de tmate y matarlos forzosamente si es necesario
        TMATE_PIDS=$(pgrep tmate 2>/dev/null)
        if [ -n "$TMATE_PIDS" ]; then
            echo -e "${YELLOW}Matando forzosamente procesos de tmate restantes...${NC}"
            kill -9 $TMATE_PIDS 2>/dev/null || true
        fi
    else
        echo -e "${GREEN}No se encontraron procesos de tmate activos${NC}"
    fi

    # Eliminar sesiones de tmate que puedan estar pendientes
    tmate kill-server 2>/dev/null || true
}

# Verificar e instalar dependencias si no existen
echo -e "${YELLOW}Verificando dependencias...${NC}"

# Verificar e instalar tmate si no existe
if ! command_exists "tmate"; then
    echo -e "${YELLOW}Instalando tmate...${NC}"
    # Verificar si sudo está disponible
    if command_exists "sudo"; then
        sudo apt-get update -y
        sudo apt-get install -y tmate
    else
        apt-get update -y
        apt-get install -y tmate
    fi
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: No se pudo instalar tmate${NC}"
        exit 1
    fi
    echo -e "${GREEN}Tmate instalado correctamente${NC}"
else
    echo -e "${GREEN}Tmate ya está instalado${NC}"
fi

# Verificar e instalar ssh si no existe
if ! command_exists "ssh"; then
    echo -e "${YELLOW}Instalando OpenSSH...${NC}"
    # Verificar si sudo está disponible
    if command_exists "sudo"; then
        sudo apt-get install -y openssh-client openssh-server
    else
        apt-get install -y openssh-client openssh-server
    fi
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: No se pudo instalar openssh${NC}"
        exit 1
    fi
    echo -e "${GREEN}OpenSSH instalado correctamente${NC}"
else
    echo -e "${GREEN}OpenSSH ya está instalado${NC}"
fi

# Verificar si existe una clave SSH, si no, generarla
ssh_dir="$HOME/.ssh"
if [ ! -d "$ssh_dir" ]; then
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
fi

private_key="$ssh_dir/id_rsa"
if [ ! -f "$private_key" ]; then
    echo -e "${YELLOW}Generando clave SSH...${NC}"
    ssh-keygen -t rsa -b 4096 -f "$private_key" -N "" -q
    chmod 600 "$private_key"
    echo -e "${GREEN}Clave SSH generada en $private_key${NC}"
else
    echo -e "${GREEN}Clave SSH ya existe${NC}"
fi

# Asegurarse de que el archivo .env existe
touch "$ENV_FILE"

# Función para capturar la salida de tmate, extraer el enlace y guardarlo en .env
capture_and_save_link() {
    local tmate_socket="/tmp/tmate-socket-$$"

    # Detener procesos anteriores de tmate
    stop_tmate_processes

    echo -e "${GREEN}Iniciando sesión con Tmate...${NC}"
    echo ""
    echo -e "${YELLOW}Instrucciones:${NC}"
    echo -e "${YELLOW}- Tmate generará enlaces SSH para conexión remota${NC}"
    echo -e "${YELLOW}- Comparte la URL de lectura-escritura solo con personas de confianza${NC}"
    echo -e "${YELLOW}- El comando SSH se guardará en $ENV_FILE${NC}"
    echo ""

    # Iniciar sesión de tmate en modo daemon
    if ! tmate -S "$tmate_socket" new-session -d; then
        echo -e "${RED}Error al iniciar la sesión de tmate${NC}"
        return 1
    fi

    # Esperar a que tmate inicialice
    sleep 3

    local max_wait_time=60
    local count=0
    local SSH_RW=""

    echo -e "${YELLOW}Esperando a que tmate genere los enlaces...${NC}"

    while [ $count -lt $max_wait_time ] && [ -z "$SSH_RW" ]; do
        sleep 1
        # Intentar obtener el enlace SSH_RW
        SSH_RW=$(tmate -S "$tmate_socket" display -p '#{tmate_ssh}' 2>/dev/null | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        ((count++))
        # Mostrar contador para seguimiento
        if [ $((count % 10)) -eq 0 ]; then
            echo -e "${YELLOW}Esperando... ($count segundos)${NC}"
        fi
    done

    # Verificar si encontramos el enlace de lectura-escritura
    if [ -n "$SSH_RW" ]; then
        echo -e "${GREEN}Comando SSH generado:${NC}"
        echo -e "${YELLOW}Comando: ${NC}$SSH_RW"

        # Verificar que el enlace sea válido (contiene ssh y @)
        if [[ "$SSH_RW" == ssh* ]] && [[ "$SSH_RW" == *@* ]]; then
            # Guardar o actualizar el comando SSH en el archivo .env sin borrar el resto
            if [ -f "$ENV_FILE" ]; then
                # Eliminar cualquier línea existente de TMATE_SSH_COMMAND y añadir la nueva
                grep -v "^TMATE_SSH_COMMAND=" "$ENV_FILE" > "$ENV_FILE.tmp" 2>/dev/null || true
                echo "TMATE_SSH_COMMAND=\"$SSH_RW\"" >> "$ENV_FILE.tmp"
                mv "$ENV_FILE.tmp" "$ENV_FILE"
            else
                # Si el archivo no existe, crearlo con la variable
                echo "TMATE_SSH_COMMAND=\"$SSH_RW\"" > "$ENV_FILE"
            fi
            echo -e "${GREEN}Comando SSH guardado en $ENV_FILE${NC}"

            # Hacer que el archivo .env sea legible
            chmod 644 "$ENV_FILE"

            echo -e "${GREEN}El comando SSH está disponible como TMATE_SSH_COMMAND en $ENV_FILE${NC}"

            # Mantener la sesión activa de tmate
            echo -e "${GREEN}Manteniendo sesión de tmate activa...${NC}"

            # Verificar continuamente si la sesión sigue activa
            while [ -S "$tmate_socket" ] && [ -n "$(tmate -S "$tmate_socket" list-sessions 2>/dev/null)" ]; do
                sleep 10
                # Verificar periódicamente si el enlace SSH sigue siendo válido
                current_link=$(tmate -S "$tmate_socket" display -p '#{tmate_ssh}' 2>/dev/null | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [ -n "$current_link" ] && [[ "$current_link" == ssh* ]] && [[ "$current_link" == *@* ]]; then
                    # Actualizar el .env si es diferente
                    if [ "$current_link" != "$SSH_RW" ]; then
                        echo -e "${YELLOW}Actualizando enlace SSH en .env${NC}"
                        # Actualizar la variable en el archivo .env sin borrar el resto
                        grep -v "^TMATE_SSH_COMMAND=" "$ENV_FILE" > "$ENV_FILE.tmp" 2>/dev/null || true
                        echo "TMATE_SSH_COMMAND=\"$current_link\"" >> "$ENV_FILE.tmp"
                        mv "$ENV_FILE.tmp" "$ENV_FILE"
                        chmod 644 "$ENV_FILE"
                        SSH_RW="$current_link"
                    fi
                fi
            done
            echo -e "${YELLOW}La sesión de tmate ha terminado${NC}"
        else
            echo -e "${RED}El enlace encontrado no parece válido: $SSH_RW${NC}"
            # Detener la sesión ya que no es válida
            tmate -S "$tmate_socket" kill-server 2>/dev/null || true
        fi
    else
        echo -e "${RED}No se pudo obtener el enlace SSH de lectura-escritura${NC}"
        # Detener la sesión si no se puede obtener el enlace
        tmate -S "$tmate_socket" kill-server 2>/dev/null || true
    fi

    # Eliminar socket temporal si existe
    [ -S "$tmate_socket" ] && rm -f "$tmate_socket" 2>/dev/null || true
}

# Función principal de ejecución con reinicio automático
run_with_auto_restart() {
    echo -e "${GREEN}Iniciando Tmate con reinicio automático...${NC}"

    while true; do
        echo -e "${YELLOW}Iniciando nueva sesión de Tmate...${NC}"
        if capture_and_save_link; then
            echo -e "${YELLOW}Sesión de Tmate terminada exitosamente, reiniciando...${NC}"
        else
            echo -e "${RED}Error en la sesión de Tmate, reiniciando en 5 segundos...${NC}"
        fi

        echo -e "${RED}La sesión de Tmate se detuvo, reiniciando en 5 segundos...${NC}"
        sleep 5
    done
}

# Ejecutar la función principal
trap 'echo -e "${YELLOW}Recibida señal de interrupción. Deteniendo tmate...${NC}"; stop_tmate_processes; exit 0' INT TERM

run_with_auto_restart
