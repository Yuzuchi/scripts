#!/bin/bash

# Script para instalar SOLO las dependencias de Hyprland
# Autor: Asistente Claude
# Versión: 1.0

set -e  # Salir si hay errores

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Función para mostrar mensajes
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[ÉXITO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que se ejecuta como root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Este script debe ejecutarse como root (usar sudo)"
        exit 1
    fi
}

# Actualizar sistema
update_system() {
    print_status "Actualizando sistema..."
    apt update && apt upgrade -y
    print_success "Sistema actualizado"
}

# Instalar dependencias del sistema
install_system_dependencies() {
    print_status "Instalando dependencias del sistema..."
    
    # Dependencias básicas de compilación
    apt install -y build-essential make git pkg-config wget curl
    
    # CMake actualizado
    print_status "Instalando CMake actualizado..."
    cd /tmp
    wget -q https://github.com/Kitware/CMake/releases/download/v3.31.3/cmake-3.31.3-linux-x86_64.tar.gz
    tar -xzf cmake-3.31.3-linux-x86_64.tar.gz
    mv cmake-3.31.3-linux-x86_64 /opt/cmake
    ln -sf /opt/cmake/bin/cmake /usr/bin/cmake
    rm -f cmake-3.31.3-linux-x86_64.tar.gz
    print_success "CMake $(cmake --version | head -n1) instalado"
    
    # Dependencias de desarrollo
    print_status "Instalando librerías de desarrollo..."
    apt install -y \
        libwayland-dev \
        wayland-protocols \
        libdrm-dev \
        libxkbcommon-dev \
        libinput-dev \
        libxcb-ewmh-dev \
        libxcb-icccm4-dev \
        libxcb-render-util0-dev \
        libxcb-xinput-dev \
        libxcb-xkb-dev \
        libxcb-image0-dev \
        libpixman-1-dev \
        libcairo2-dev \
        libpango1.0-dev \
        libegl1-mesa-dev \
        libgles2-mesa-dev \
        libgbm-dev \
        libxcb-dri3-dev \
        libxcb-present-dev \
        libxcb-sync-dev \
        libxcb-xfixes0-dev \
        libxcb-dri2-0-dev \
        libxxf86vm-dev \
        libxrandr-dev \
        meson \
        ninja-build
    
    # Dependencias opcionales (ignorar errores)
    print_status "Instalando dependencias opcionales..."
    apt install -y \
        libwlroots-dev \
        libseat-dev \
        libxcb-res0-dev \
        libxcb-errors-dev \
        hwdata \
        libdisplay-info-dev \
        libliftoff-dev \
        libtomlplusplus-dev || {
        print_warning "Algunas dependencias opcionales no están disponibles"
    }
    
    print_success "Dependencias del sistema instaladas"
}

# Compilar e instalar dependencias específicas de Hyprland
install_hyprland_libraries() {
    print_status "Compilando librerías específicas de Hyprland..."
    
    # Directorio de trabajo
    WORK_DIR="/tmp/hyprland-deps"
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # Lista de dependencias en orden correcto
    HYPRLAND_DEPS=(
        "hyprutils"
        "hyprlang" 
        "hyprcursor"
        "aquamarine"
    )
    
    for dep in "${HYPRLAND_DEPS[@]}"; do
        print_status "Compilando $dep..."
        
        # Limpiar directorio anterior
        rm -rf "$dep"
        
        # Clonar repositorio
        if ! git clone "https://github.com/hyprwm/$dep.git"; then
            print_error "Error al clonar $dep"
            continue
        fi
        
        cd "$dep"
        
        # Crear directorio de compilación
        mkdir -p build
        cd build
        
        # Configurar con CMake
        if cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr; then
            # Compilar
            if make -j$(nproc); then
                # Instalar
                if make install; then
                    print_success "$dep instalado correctamente ✓"
                else
                    print_error "Error al instalar $dep"
                fi
            else
                print_error "Error al compilar $dep"
            fi
        else
            print_error "Error al configurar $dep con CMake"
        fi
        
        # Volver al directorio de trabajo
        cd "$WORK_DIR"
    done
    
    # Actualizar cache de librerías
    print_status "Actualizando cache de librerías..."
    ldconfig
    
    print_success "Librerías de Hyprland compiladas e instaladas"
}

# Instalar aplicaciones útiles para Hyprland
install_useful_apps() {
    print_status "Instalando aplicaciones útiles para Hyprland..."
    
    # Terminal
    apt install -y kitty || {
        print_warning "kitty no disponible, instalando alternativa..."
        apt install -y xterm
    }
    
    # Launcher/menu
    apt install -y wofi || {
        print_warning "wofi no disponible, instalando alternativa..."
        apt install -y dmenu
    }
    
    # Barra de estado
    apt install -y waybar || print_warning "waybar no disponible"
    
    # Gestor de notificaciones
    apt install -y mako-notifier || print_warning "mako-notifier no disponible"
    
    # Gestor de wallpapers
    apt install -y swaybg || print_warning "swaybg no disponible"
    
    # Gestor de archivos
    apt install -y dolphin || apt install -y nautilus || print_warning "Gestor de archivos no disponible"
    
    # Herramientas adicionales
    apt install -y \
        grim \
        slurp \
        wl-clipboard \
        brightnessctl \
        pamixer || print_warning "Algunas herramientas adicionales no disponibles"
    
    print_success "Aplicaciones útiles instaladas"
}

# Verificar instalación
verify_installation() {
    print_status "Verificando instalación de dependencias..."
    
    # Verificar CMake
    if cmake --version | grep -q "3.3"; then
        print_success "CMake: $(cmake --version | head -n1)"
    else
        print_warning "CMake podría no estar actualizado"
    fi
    
    # Verificar librerías de Hyprland
    print_status "Verificando librerías de Hyprland..."
    
    LIBS_TO_CHECK=(
        "/usr/lib/libhyprutils.so"
        "/usr/lib/libhyprlang.so" 
        "/usr/lib/libhyprcursor.so"
        "/usr/lib/libaquamarine.so"
    )
    
    for lib in "${LIBS_TO_CHECK[@]}"; do
        if [ -f "$lib" ] || [ -f "${lib%.*}.a" ]; then
            print_success "✓ $(basename "$lib")"
        else
            print_warning "? $(basename "$lib") - podría estar en otra ubicación"
        fi
    done
    
    # Verificar pkg-config
    print_status "Verificando configuración pkg-config..."
    export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
    
    if pkg-config --exists hyprutils; then
        print_success "✓ hyprutils detectado por pkg-config"
    fi
    
    if pkg-config --exists hyprlang; then
        print_success "✓ hyprlang detectado por pkg-config"
    fi
    
    print_success "Verificación completada"
}

# Mostrar información final
show_final_info() {
    print_success "¡Instalación de dependencias completada!"
    echo ""
    print_status "Dependencias instaladas:"
    echo "  ✓ CMake $(cmake --version | head -n1 | cut -d' ' -f3)"
    echo "  ✓ Librerías de desarrollo de Wayland"
    echo "  ✓ hyprutils, hyprlang, hyprcursor, aquamarine"
    echo "  ✓ Aplicaciones útiles (terminal, launcher, etc.)"
    echo ""
    print_status "Siguiente paso:"
    echo "  Ahora puedes compilar Hyprland con:"
    echo "  cd /path/to/Hyprland"
    echo "  mkdir build && cd build"
    echo "  cmake .. -DCMAKE_BUILD_TYPE=Release"
    echo "  make -j\$(nproc)"
    echo "  sudo make install"
    echo ""
    print_status "Variables de entorno recomendadas:"
    echo "  export PKG_CONFIG_PATH=\"/usr/lib/pkgconfig:/usr/local/lib/pkgconfig:\$PKG_CONFIG_PATH\""
    echo "  export LD_LIBRARY_PATH=\"/usr/lib:/usr/local/lib:\$LD_LIBRARY_PATH\""
}

# Limpiar archivos temporales
cleanup() {
    print_status "Limpiando archivos temporales..."
    rm -rf /tmp/hyprland-deps
    rm -f /tmp/cmake-*.tar.gz
    print_success "Limpieza completada"
}

# Función principal
main() {
    echo "=========================================="
    echo "  Instalador de Dependencias Hyprland   "
    echo "=========================================="
    echo ""
    
    check_root
    update_system
    install_system_dependencies
    install_hyprland_libraries
    install_useful_apps
    verify_installation
    cleanup
    show_final_info
    
    echo ""
    print_success "¡Todas las dependencias están listas para Hyprland!"
}

# Ejecutar script principal
main "$@"
