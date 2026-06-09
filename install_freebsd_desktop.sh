#!/bin/sh
#https://forums.freebsd.org/threads/how-to-install-standard-ttf-microsoft-fonts.95009/
#/usr/local/share/lxqt/themes/ dodne se almacenan los themas generales
#/usr/local/share/icons/ lugar de los iconos generales

#pkg install x11-fonts/plex-ttf fuente ibm

#amdgpu, i915, and radeon DRM drivers modules.
#Currently corresponding to Linux 6.6 DRM.
#This version is for FreeBSD 15 1500031
#and above.

#pkg install gpu-firmware-kmod
#gpu-firmware-intel-kmod 
#gpu-firmware-amd-kmod 
#pkg install gpu-firmware-radeon-kmod-aruba
# echo "exec mate-session" > /usr/share/skel/dot.xinitrc
# echo "exec cinnamon-session" > /usr/share/skel/dot.xinitrc
# echo "exec startxfce4" > /usr/share/skel/dopkg install pavucontrol-qt freedesktop-sound-themet.xinitrc
# echo "exec startplasma-x11" > /usr/share/skel/dot.xinitrc


log_info() {
	local msg="$1" 
	printf "[INFO] %s\n" "$msg"
	}


configure_cpu_microcode() {
    log_info "Configurando microcódigo del procesador..."
    local cpu_model
    cpu_model=$(sysctl -n hw.model 2>/dev/null)
    case "$cpu_model" in
        *AMD*|*amd*)
            log_info "CPU AMD. Instalando cpu-microcode-amd..."
            install_pkg "cpu-microcode-amd"
            ;;
        *Intel*|*intel*)
            log_info "CPU Intel. Instalando cpu-microcode-intel..."
            install_pkg "cpu-microcode-intel"
            ;;
        *)
            log_warn "CPU no identificado ($cpu_model). Omitiendo microcódigo."
            return 0
            ;;
    esac
    sysrc microcode_update_enable="YES"
    if pkg info -e "cpu-microcode-amd" || pkg info -e "cpu-microcode-intel"; then
        
        service microcode_update start 2>/dev/null || \
            log_warn "No se pudo iniciar microcode_update de forma interactiva."
    fi
    
}


install_xlibre{
	
	#pkg install -y xlibre-xf86-video-vmware open-vm-tools 
	#pkg install -y graphics/drm-kmod
	#
	#
	#
	#
	pkg install -y xlibre-server
    pkg install -y xlibre-drivers
    #pkg install -y xlibre-xf86-input-libinput	
	
	sysrc dbus_enable="YES"
	log_info "Configurando teclado y mouse para X11..."

XORG_DIR="/usr/local/etc/X11/xorg.conf.d"
    mkdir -p "$XORG_DIR"

    # ====================== FUNCIÓN DE DRIVERS ======================
    get_driver_pkg() {
        vendor="$1"
        device="$2"

        case "$vendor" in
            # NVIDIA
            0x10de)
                pkg="nvidia-driver"
                kld="nvidia"
                ;;

            # AMD
            0x1002)
                pkg="graphics/drm-kmod"
                kld="amdgpu"
                ;;

            # Intel
            0x8086)
                pkg="graphics/drm-kmod"
                kld="i915kms"
                ;;

            # VMware
            0x15ad)
                pkg="xlibre-xf86-video-vmware"
                kld="vmwgfx"
                ;;

            # QEMU / QXL
            0x1234)
                pkg="xf86-video-qxl"
                kld=""
                ;;

            # VirtualBox
            0x80ee)
                pkg="emulators/virtualbox-ose-additions"
                kld="vboxvideo"
                ;;

            # Fallback
            *)
                pkg=""
                kld=""
                ;;
        esac

        printf '%s|%s\n' "$pkg" "$kld"
    }

    # ====================== DETECCIÓN DE GPUs ======================
    echo ""
    echo "Detectando GPUs instaladas..."
    echo "══════════════════════════════════════════════"

    tmpfile=$(mktemp /tmp/gpulist.XXXXXX)

    pciconf -l 2>/dev/null | grep 'class=0x03' | grep '^vgapci' | \
    while IFS= read -r line; do
        devname=$(echo "$line" | sed 's/@.*//')
        bus=$(echo "$line" | sed 's/.*pci0:\([0-9]*\):\([0-9]*\):\([0-9]*\):.*/\1/')
        slot=$(echo "$line" | sed 's/.*pci0:\([0-9]*\):\([0-9]*\):\([0-9]*\):.*/\2/')
        func=$(echo "$line" | sed 's/.*pci0:\([0-9]*\):\([0-9]*\):\([0-9]*\):.*/\3/')
        vendor=$(echo "$line" | sed 's/.* vendor=\(0x[0-9a-fA-F]*\) .*/\1/')
        device=$(echo "$line" | sed 's/.* device=\(0x[0-9a-fA-F]*\) .*/\1/')

        case "$vendor" in
            0x10de) desc="NVIDIA" ;;
            0x1002) desc="AMD/ATI" ;;
            0x8086) desc="Intel" ;;
            0x1234) desc="QEMU/QXL" ;;
            0x15ad) desc="VMware" ;;
            0x80ee) desc="VirtualBox" ;;
            *)      desc="GPU Desconocida" ;;
        esac

        busid="PCI:${bus}:${slot}:${func}"
        printf '%s|%s|%s|%s|%s\n' "$devname" "$busid" "$vendor" "$device" "$desc" >> "$tmpfile"
    done

    # Cargar GPUs detectadas en variables
    i=0
    while IFS='|' read -r devname busid vendor device desc; do
        i=$((i + 1))
        eval "GPU_${i}_DEVNAME='$devname'"
        eval "GPU_${i}_BUSID='$busid'"
        eval "GPU_${i}_VENDOR='$vendor'"
        eval "GPU_${i}_DEVICE='$device'"
        eval "GPU_${i}_DESC='$desc'"
    done < "$tmpfile"
    total=$i
    rm -f "$tmpfile"

    if [ "$total" -eq 0 ]; then
        echo "No se detectaron GPUs. Usando configuración básica."
    else
        # Mostrar GPUs
        j=1
        while [ "$j" -le "$total" ]; do
            eval "desc=\$GPU_${j}_DESC"
            eval "busid=\$GPU_${j}_BUSID"
            printf ' [%d] %-20s %s\n' "$j" "$desc" "$busid"
            j=$((j + 1))
        done
        echo "══════════════════════════════════════════════"

        # Selección de GPUs por el usuario
        if [ "$total" -eq 1 ]; then
            selected="1"
        else
            printf '\n¿Qué GPUs deseas configurar? (ej: 1 2 / all): '
            read -r selection
            if [ "$selection" = "all" ] || [ "$selection" = "ALL" ] || [ -z "$selection" ]; then
                selected=$(seq 1 "$total")
            else
                selected="$selection"
            fi
        fi
    fi

    # ====================== INSTALACIÓN DE DRIVERS Y CONFIGURACIÓN ======================
    echo ""
    echo "Instalando drivers y generando archivos de configuración..."

    chosen_devnames=""

    for num in $selected; do
        eval "devname=\$GPU_${num}_DEVNAME"
        eval "busid=\$GPU_${num}_BUSID"
        eval "vendor=\$GPU_${num}_VENDOR"
        eval "device=\$GPU_${num}_DEVICE"
        eval "desc=\$GPU_${num}_DESC"

        [ -z "$devname" ] && continue

        echo ""
        echo "── ${desc} (${devname}) ───────────────────────────────"

        # Obtener driver y paquete
        info=$(get_driver_pkg "$vendor" "$device")
        pkg=$(echo "$info" | cut -d'|' -f1)
        kld=$(echo "$info" | cut -d'|' -f2)

        # Instalar paquete si corresponde
        if [ -n "$pkg" ]; then
            if pkg info "$pkg" >/dev/null 2>&1; then
                echo " [✓] $pkg ya está instalado"
            else
                echo " → Instalando $pkg..."
                pkg install -y "$pkg" || echo " [✗] Error al instalar $pkg"
            fi
        else
            echo " [i] Usando driver genérico (modesetting)"
        fi

        # Registrar módulo en rc.conf
        if [ -n "$kld" ]; then
            if ! sysrc -n kld_list 2>/dev/null | grep -q "\b$kld\b"; then
                sysrc kld_list+=" $kld"
                echo " → Añadido $kld a kld_list"
            else
                echo " [✓] $kld ya está en kld_list"
            fi
        fi

        # Determinar driver para Xorg
        case "$vendor" in
        0x10de) desc="NVIDIA" ;;
            #0x1002) desc="AMD/ATI" ;;
            #0x8086) desc="Intel" ;;
            #0x1234) desc="QEMU/QXL" ;;
            #0x15ad) desc="VMware" ;;
            #0x80ee) desc="VirtualBox" ;;
            #*)      desc="GPU Desconocida" ;;
            
            0x15ad) driver_name="vmware" ;;
            0x1234) driver_name="qxl" ;;
            0x10de) driver_name="nvidia" ;;
            *)      driver_name="modesetting" ;;
        esac

        # Generar archivo de configuración
        idx=$(echo "$devname" | tr -dc '0-9' | head -c 2)
        [ -z "$idx" ] && idx=$(printf "%02d" "$num")
        outfile="${XORG_DIR}/$(printf '%02d' "$idx")-${devname}.conf"

        cat > "$outfile" << EOF
# GPU: ${desc} - ${busid}
Section "Device"
    Identifier "${devname}"
    Driver "${driver_name}"
    BusID "${busid}"
EndSection

Section "Monitor"
    Identifier "Monitor-${devname}"
    Option "DPMS" "true"
EndSection

Section "Screen"
    Identifier "Screen-${devname}"
    Device "${devname}"
    Monitor "Monitor-${devname}"
    DefaultDepth 24
EndSection
EOF

        echo " → Configuración: $outfile"
        chosen_devnames="$chosen_devnames $devname"
    done

    # ====================== ServerLayout ======================
    cat > "${XORG_DIR}/99-layout.conf" << EOF
Section "ServerLayout"
    Identifier "Layout0"
EOF

    i=0
    prev=""
    for devname in $chosen_devnames; do
        i=$((i + 1))
        if [ "$i" -eq 1 ]; then
            echo "    Screen 0 \"Screen-${devname}\" 0 0" >> "${XORG_DIR}/99-layout.conf"
        else
            echo "    Screen $((i-1)) \"Screen-${devname}\" RightOf \"Screen-${prev}\"" >> "${XORG_DIR}/99-layout.conf"
        fi
        prev="$devname"
    done
    echo "EndSection" >> "${XORG_DIR}/99-layout.conf"
    echo " → Creado: ${XORG_DIR}/99-layout.conf"
    
    cat > "${XORG_DIR}/20-keyboard.conf" << 'EOF'
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "es"
        Option "XkbVariant" "winkeys"
EndSection
EOF

    cat > "${XORG_DIR}/30-mouse.conf" << 'EOF'
Section "InputClass"
    Identifier  "system-mouse"
    MatchIsPointer "on"
    Driver "libinput"
    Option "AccelSpeed" "0"
EndSection
EOF


	
	}

install_sddm() {
    log_info "Instalando y configurando SDDM..."
    pkg install -y sddm qt6-5compat
    
    sysrc sddm_enable=YES

    if [ ! -d "/usr/local/share/sddm/themes/sugar_dark" ]; then
        log_info "Clonando tema sddm-sugar-dark..."
        mkdir -p /usr/local/share/sddm/themes
        git clone https://github.com/Automatisa/sddm-sugar-dark.git \
            /usr/local/share/sddm/themes/sugar_dark
    else
        log_info "Tema sddm-sugar-dark ya presente."
    fi

    cat > /usr/local/etc/sddm.conf << 'EOF'
[General]
InputMethod=""
Numlock=on

[Theme]
Current=sugar_dark
CursorTheme=DMZ-White
EnableAvatars=false

[X11]
XkbLayout=es
XkbVariant=winkeys
EOF
}

# driver del sistema sysrc kld_list+=vmwgfx

install_system_fonts() {
    log_info "Instalando fuentes del sistema..."
    pkg install -y noto
    pkg install -y  gnu-unifont-otf
    pkg install -y hack-font
    pkg install -y roboto-fonts-ttf
    pkg install -y font-awesome
}


install_lxqt() {

#sddm-freebsd-black-theme
#x11-wm/picom paquete de composer picom
pkg install -y lxqt xdg-user-dirs 
pkg install -y xsettingsd
pkg install -y xcompmgr openbox-arc-theme cursor-dmz-theme papirus-icon-theme
pkg install -y gvfs fusefs-ntfs fusefs-exfat ffmpegthumbnailer pavucontrol-qt freedesktop-sound-theme noto gnu-unifont-otf hack-font roboto-fonts-ttf font-awesome

#ingresamos el proc
if ! grep -q "^proc /proc" /etc/fstab; then
    echo "proc /proc procfs rw 0 0" >> /etc/fstab
fi

# para configurar la creacion de usuarios
cat > /usr/local/etc/polkit-1/rules.d/50-default-wheel-admin.rules << 'EOF'
polkit.addAdminRule(function(action, subject) {
    return ["unix-user:root"];
});

polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.lxqt.lxqt-admin-user") === 0 && subject.isInGroup("wheel")) {
        return polkit.Result.AUTH_ADMIN; 
    }
});
EOF

chmod 644 /usr/local/etc/polkit-1/rules.d/50-default-wheel-admin.rules
chown polkitd:wheel /usr/local/etc/polkit-1/rules.d/50-default-wheel-admin.rules

# Crear el archivo con las reglas
cat > /usr/local/etc/polkit-1/rules.d/60-power-management.rules << 'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.consolekit.system.stop" ||
         action.id == "org.freedesktop.consolekit.system.restart" ||
         action.id == "org.freedesktop.consolekit.system.suspend" ||
         action.id == "org.freedesktop.consolekit.system.hibernate" ||
         action.id == "org.freedesktop.login1.power-off" ||
         action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
         action.id == "org.freedesktop.login1.reboot" ||
         action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
         action.id == "org.freedesktop.login1.suspend" ||
         action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
         action.id == "org.freedesktop.login1.hibernate" ||
         action.id == "org.freedesktop.login1.hibernate-multiple-sessions") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

# Establecer permisos correctos
chmod 644 /usr/local/etc/polkit-1/rules.d/60-power-management.rules
chown polkitd:wheel /usr/local/etc/polkit-1/rules.d/60-power-management.rules
echo "Archivo de reglas de Polkit creado correctamente en /usr/local/etc/polkit-1/rules.d/60-power-management.rules"



sed -i '' 's/^security\.bsd\.see_other_uids=.*/security.bsd.see_other_uids=1/' /etc/sysctl.conf
sed -i '' 's/^security\.bsd\.see_other_gids=.*/security.bsd.see_other_gids=1/' /etc/sysctl.conf

sysctl security.bsd.see_other_uids=1
sysctl security.bsd.see_other_gids=1

printf "[ ${CG}NOTE${NC} ]  Creating SKEL structure\n\n"
mkdir -p /usr/share/skel/Escritorio
mkdir -p /usr/share/skel/Documentos
mkdir -p /usr/share/skel/Descargas
mkdir -p /usr/share/skel/Documentos
mkdir -p /usr/share/skel/Descargas
mkdir -p /usr/share/skel/Música
mkdir -p /usr/share/skel/Imágenes
mkdir -p /usr/share/skel/Vídeos
mkdir -p /usr/share/skel/Imágenes
mkdir -p /usr/share/skel/Vídeos
mkdir -p /usr/share/skel/Público
mkdir -p /usr/share/skel/Plantillas

echo "ck-launch-session /usr/local/bin/startlxqt" > /usr/share/skel/dot.xinitrc

# 1. Crear autostart para xcompmgr 
#configuramos el compositor
mkdir -p /usr/share/skel/.config/autostart
#cat > /usr/share/skel/.config/autostart/xcompmgr.desktop << 'EOF'
cat > /usr/local/etc/xdg/autostart/xcompmgr.desktop << 'EOF'

[Desktop Entry]
Type=Application
Name=X Compositing Manager
Comment=Compositor con sombras (VMware)
Exec=/usr/local/bin/xcompmgr -cC
TryExec=xcompmgr
X-LXQt-Need-Tray=true
X-LXQt-X11-Only=true

EOFpkg install pavucontrol-qt freedesktop-sound-theme

#OnlyShowIn=LXQt;

cat > /usr/share/skel/dot.login_conf << 'EOF'
me:\
        :charset=UTF-8:\
        :lang=es_ES.UTF-8:\
        :lc_all=es_ES.UTF-8:
EOF

# ----------------------------
# Archivo 1: dot.shrc
# ----------------------------
echo "Creando dot.shrc..."
cat >> "/usr/share/skel/dot.shrc" << 'EOF'

# Inicializar carpetas XDG si el entorno es interactivo
if [ -n "$PS1" ]; then
    LC_ALL=es_ES.UTF-8 xdg-user-dirs-update --force
fi
EOF

# ----------------------------
# Archivo 2: dot.cshrc
# ----------------------------
echo "Creando dot.cshrc..."
cat >> "/usr/share/skel/dot.cshrc" << 'EOF'

# Inicializar carpetas XDG
if ( $?prompt ) then
    env LC_ALL=es_ES.UTF-8 xdg-user-dirs-update --force
endif
EOF

# ----------------------------
# Archivo 3: dot.profile
# ----------------------------
echo "Creando dot.profile..."
cat >> "/usr/share/skel/dot.profile" << 'EOF'

# Inicializar carpetas XDG
LC_ALL=es_ES.UTF-8 xdg-user-dirs-update --force
EOF

chmod 644 /usr/share/skel/dot.login_conf
mkdir -p /usr/share/skel/.config
cat > /usr/share/skel/.config/user-dirs.dirs << EOF
XDG_DESKTOP_DIR="$HOME/Escritorio"
XDG_DOWNLOAD_DIR="$HOME/Descargas"
XDG_TEMPLATES_DIR="$HOME/Plantillas"
XDG_PUBLICSHARE_DIR="$HOME/Público"
XDG_DOCUMENTS_DIR="$HOME/Documentos"
XDG_MUSIC_DIR="$HOME/Música"
XDG_PICTURES_DIR="$HOME/Imágenes"
XDG_VIDEOS_DIR="$HOME/Vídeos""
EOF


mkdir -p /usr/share/skel/.config/lxqt
cat > /usr/share/skel/.config/lxqt/session.conf << 'EOF'
[General]
window_manager=openbox

[Appearance]
icon_theme=Papirus-Dark
cursor_theme=DMZ-White
cursor_size=24
[Environment]
XCURSOR_PATH=~/.icons:/usr/local/share/icons

[Mouse]
acc_factor=20
acc_threshold=10
cursor_size=16
cursor_theme=redglass
left_handed=false
EOF

cat > /usr/share/skel/.config/lxqt/session.conf << 'EOF'
[General]
window_manager=openbox

[Environment]
XCURSOR_PATH=~/.icons:/usr/local/share/icons
EOF

cat > /usr/share/skel/.dmrc << 'EOF'
[Desktop]
Session=lxqt
EOF

cat > /usr/share/skel/.config/lxqt/lxqt.conf << 'EOF'
[General]
icon_follow_color_scheme=true
icon_theme=Papirus-Dark
palette_override=true
single_click_activate=false
theme=dark
tool_bar_icon_size=24
tool_button_style=ToolButtonTextBesideIcon
wallpaper_override=false

[Palette]
base_color=#282828
highlight_color=#640b0c
highlighted_text_color=#ebfdff
link_color=#8c9bff
link_visited_color=#ffb3f7
text_color=#b8b8b8
tooltip_base_color=#232323
tooltip_text_color=#b8b8b8
window_color=#232323
window_text_color=#e1e6e6

[Qt]
doubleClickInterval=400
font="Sans,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
style=Fusion
wheelScrollLines=3

EOF


cat > /usr/share/skel/.config/lxqt/lxqt-config-input.conf << 'EOF'
[Keyboard]
layout=es
variant=winkeys
EOF

# 3. Configurar el cursor para el servidor gráfico general (X11 / Pantalla de carga)
#Inherits=redglass
#Vanilla-DMZ

mkdir -p /usr/share/skel/.icons/default
cat > /usr/share/skel/.icons/default/index.theme << 'EOF'
[Icon Theme]
Name=Default
Comment=Default cursor theme
Inherits=redglass
Size=16
EOF

echo "pointer = 1 2 3 4 5 6 7 0 0 0" > /usr/share/skel/dot.xmodmap
echo "es_ES.UTF-8" > /usr/share/skel/.config/user-dirs.locale
echo ""
# rights
chown -R root:wheel /usr/share/skel
find /usr/share/skel -type d -exec chmod 755 {} \;
find /usr/share/skel -type f -exec chmod 644 {} \;


cat > /usr/local/etc/sddm.conf << 'EOF'
[General]
InputMethod=""
Numlock=on

[Theme]
Current=sugar_dark
CursorTheme=DMZ-White
EnableAvatars=false

[X11]
XkbLayout=es
XkbVariant=winkeys
EOF

}

configure_cpu_microcode
install_xlibre
install_system_fonts
install_sddm
install_lxqt
