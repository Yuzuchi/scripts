#!/bin/bash

# Script de instalación de Hyprland para Debian
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
        print_error "Este script debe ejecutarse como root (usar sudo o su -)"
        exit 1
    fi
}

# Actualizar sistema
update_system() {
    print_status "Actualizando sistema..."
    apt update && apt upgrade -y
    print_success "Sistema actualizado"
}

# Instalar dependencias
install_dependencies() {
    print_status "Instalando dependencias..."
    
    # Dependencias básicas
    apt install -y build-essential make cmake git pkg-config \
        libwayland-dev wayland-protocols libdrm-dev libxkbcommon-dev \
        libinput-dev libxcb-ewmh-dev libxcb-icccm4-dev \
        libxcb-render-util0-dev libxcb-xinput-dev libxcb-xkb-dev \
        libxcb-image0-dev libpixman-1-dev libcairo2-dev \
        libpango1.0-dev libegl1-mesa-dev libgles2-mesa-dev \
        libgbm-dev libxcb-dri3-dev libxcb-present-dev \
        libxcb-sync-dev libxcb-xfixes0-dev libxcb-dri2-0-dev \
        libxxf86vm-dev libxrandr-dev meson ninja-build
    
    # Dependencias adicionales
    apt install -y libwlroots-dev libseat-dev libxcb-res0-dev \
        libxcb-errors-dev hwdata libdisplay-info-dev libliftoff-dev || {
        print_warning "Algunas dependencias opcionales no están disponibles, continuando..."
    }
    
    print_success "Dependencias instaladas"
}

# Compilar e instalar Hyprland
compile_hyprland() {
    print_status "Clonando y compilando Hyprland..."
    
    # Obtener usuario real (no root)
    REAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)
    USER_HOME=$(eval echo ~$REAL_USER)
    
    # Crear directorio de trabajo
    WORK_DIR="$USER_HOME/hyprland-build"
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # Limpiar compilación anterior si existe
    if [ -d "Hyprland" ]; then
        print_status "Limpiando compilación anterior..."
        rm -rf Hyprland
    fi
    
    # Clonar repositorio
    print_status "Clonando repositorio..."
    sudo -u $REAL_USER git clone --recursive https://github.com/hyprwm/Hyprland.git
    cd Hyprland
    
    # Intentar compilación con meson/ninja primero
    print_status "Intentando compilación con meson..."
    if sudo -u $REAL_USER meson setup build 2>/dev/null; then
        print_status "Compilando con ninja..."
        sudo -u $REAL_USER ninja -C build
        ninja -C build install
        print_success "Hyprland compilado e instalado con meson/ninja"
    else
        print_warning "Meson falló, intentando con make..."
        
        # Intentar con cmake + make
        if [ -f "CMakeLists.txt" ]; then
            sudo -u $REAL_USER mkdir -p build
            cd build
            sudo -u $REAL_USER cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
            sudo -u $REAL_USER make -j$(nproc)
            make install
            print_success "Hyprland compilado e instalado con cmake/make"
        else
            print_error "No se encontró sistema de compilación compatible"
            exit 1
        fi
    fi
}

# Configurar sesión de escritorio
setup_desktop_session() {
    print_status "Configurando sesión de escritorio..."
    
    # Crear archivo de sesión para display manager
    cat > /usr/share/wayland-sessions/hyprland.desktop << EOF
[Desktop Entry]
Name=Hyprland
Comment=An independent, highly customizable, dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
    
    print_success "Sesión de escritorio configurada"
}

# Crear configuración básica para usuario
create_user_config() {
    print_status "Creando configuración básica..."
    
    REAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)
    USER_HOME=$(eval echo ~$REAL_USER)
    CONFIG_DIR="$USER_HOME/.config/hypr"
    
    # Crear directorio de configuración
    sudo -u $REAL_USER mkdir -p "$CONFIG_DIR"
    
    # Crear configuración básica
    cat > "$CONFIG_DIR/hyprland.conf" << EOF
# Configuración de monitores
monitor=,preferred,auto,auto

# Configuración de entrada
input {
    kb_layout = us
    follow_mouse = 1
    
    touchpad {
        natural_scroll = no
    }
    
    sensitivity = 0 # -1.0 - 1.0, 0 means no modification.
}

# Configuración general
general {
    gaps_in = 5
    gaps_out = 20
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    
    layout = dwindle
    
    allow_tearing = false
}

# Decoraciones
decoration {
    rounding = 10
    
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    
    drop_shadow = yes
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

# Animaciones
animations {
    enabled = yes
    
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Layout dwindle
dwindle {
    pseudotile = yes
    preserve_split = yes
}

# Layout master
master {
    new_is_master = true
}

# Gestures
gestures {
    workspace_swipe = off
}

# Configuración de dispositivos específicos
device:epic-mouse-v1 {
    sensitivity = -0.5
}

# Variables de entorno
env = XCURSOR_SIZE,24

# Keybindings principales
\$mainMod = SUPER

# Aplicaciones básicas
bind = \$mainMod, Q, exec, kitty
bind = \$mainMod, C, killactive,
bind = \$mainMod, M, exit,
bind = \$mainMod, E, exec, dolphin
bind = \$mainMod, V, togglefloating,
bind = \$mainMod, R, exec, wofi --show drun
bind = \$mainMod, P, pseudo, # dwindle
bind = \$mainMod, J, togglesplit, # dwindle

# Movimiento de foco
bind = \$mainMod, left, movefocus, l
bind = \$mainMod, right, movefocus, r
bind = \$mainMod, up, movefocus, u
bind = \$mainMod, down, movefocus, d

# Cambiar entre workspaces
bind = \$mainMod, 1, workspace, 1
bind = \$mainMod, 2, workspace, 2
bind = \$mainMod, 3, workspace, 3
bind = \$mainMod, 4, workspace, 4
bind = \$mainMod, 5, workspace, 5
bind = \$mainMod, 6, workspace, 6
bind = \$mainMod, 7, workspace, 7
bind = \$mainMod, 8, workspace, 8
bind = \$mainMod, 9, workspace, 9
bind = \$mainMod, 0, workspace, 10

# Mover ventana activa a workspace
bind = \$mainMod SHIFT, 1, movetoworkspace, 1
bind = \$mainMod SHIFT, 2, movetoworkspace, 2
bind = \$mainMod SHIFT, 3, movetoworkspace, 3
bind = \$mainMod SHIFT, 4, movetoworkspace, 4
bind = \$mainMod SHIFT, 5, movetoworkspace, 5
bind = \$mainMod SHIFT, 6, movetoworkspace, 6
bind = \$mainMod SHIFT, 7, movetoworkspace, 7
bind = \$mainMod SHIFT, 8, movetoworkspace, 8
bind = \$mainMod SHIFT, 9, movetoworkspace, 9
bind = \$mainMod SHIFT, 0, movetoworkspace, 10

# Workspace especial (scratchpad)
bind = \$mainMod, S, togglespecialworkspace, magic
bind = \$mainMod SHIFT, S, movetoworkspace, special:magic

# Scroll a través de workspaces existentes
bind = \$mainMod, mouse_down, workspace, e+1
bind = \$mainMod, mouse_up, workspace, e-1

# Mover/redimensionar ventanas con mouse
bindm = \$mainMod, mouse:272, movewindow
bindm = \$mainMod, mouse:273, resizewindow
EOF
    
    # Cambiar propietario
    chown -R $REAL_USER:$REAL_USER "$CONFIG_DIR"
    
    print_success "Configuración básica creada en $CONFIG_DIR"
}

# Instalar aplicaciones útiles
install_apps() {
    print_status "Instalando aplicaciones útiles..."
    
    # Terminal y launcher
    apt install -y kitty wofi || {
        print_warning "kitty o wofi no disponibles, instalando alternativas..."
        apt install -y xterm dmenu
    }
    
    # Barra de estado (opcional)
    apt install -y waybar || print_warning "waybar no disponible"
    
    # Gestor de notificaciones
    apt install -y mako-notifier || print_warning "mako-notifier no disponible"
    
    # Gestor de wallpapers
    apt install -y swaybg || print_warning "swaybg no disponible"
    
    # Gestor de archivos
    apt install -y dolphin || apt install -y nautilus || print_warning "No se pudo instalar gestor de archivos"
    
    print_success "Aplicaciones instaladas"
}

# Mostrar información final
show_final_info() {
    print_success "¡Instalación completada!"
    echo ""
    print_status "Para usar Hyprland:"
    echo "  1. Reinicia el sistema"
    echo "  2. En la pantalla de login, selecciona 'Hyprland'"
    echo "  3. O desde TTY ejecuta: Hyprland"
    echo ""
    print_status "Atajos de teclado básicos:"
    echo "  Super + Q: Abrir terminal"
    echo "  Super + R: Abrir launcher"
    echo "  Super + C: Cerrar ventana"
    echo "  Super + M: Salir de Hyprland"
    echo "  Super + V: Alternar ventana flotante"
    echo ""
    print_status "Configuración en: ~/.config/hypr/hyprland.conf"
}

# Función principal
main() {
    echo "======================================"
    echo "  Script de Instalación de Hyprland  "
    echo "======================================"
    echo ""
    
    check_root
    update_system
    install_dependencies
    compile_hyprland
    setup_desktop_session
    create_user_config
    install_apps
    show_final_info
}

# Ejecutar script principal
main "$@"