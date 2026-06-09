#!/bin/sh
#https://forums.freebsd.org/threads/how-to-install-standard-ttf-microsoft-fonts.95009/
#/usr/local/share/lxqt/themes/ dodne se almacenan los themas generales
#/usr/local/share/icons/ lugar de los iconos generales

#pkg install x11-fonts/plex-ttf fuenrte ibm

pkg install -y git fastfetch
pkg install -y xlibre-server
pkg install -y xlibre-xf86-video-vmware open-vm-tools 
pkg install -y xlibre xlibre-drivers 
pkg install -y x11-drivers/xlibre-xf86-input-libinput
pkg install -y graphics/drm-kmod


sysrc kld_list+=vmwgfx



cd /usr/local/etc/X11/xorg.conf.d/
cat > /usr/local/etc/X11/xorg.conf.d/10-vmware.conf << 'EOF'
Section "Device"
    Identifier "VMware SVGA"
    Driver     "vmware"
EndSection
 
Section "Monitor"
    Identifier "Monitor0"
EndSection
 
Section "Screen"
    Identifier "Screen0"
    Device     "VMware SVGA"
    Monitor    "Monitor0"
EndSection
 
Section "ServerLayout"
    Identifier "Layout0"
    Screen     "Screen0"
EndSection

EOF

cat > /usr/local/etc/X11/xorg.conf.d/20-keyboard.conf << 'EOF'
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "es"
        Option "XkbVariant" "winkeys"
EndSection
EOF

at > /usr/local/etc/X11/xorg.conf.d/30-mouse.conf << 'EOF'
Section "InputClass"
    Identifier  "system-mouse"
    MatchIsPointer "on"
    Driver "libinput"
    Option "AccelSpeed" "0"
EndSection
EOF




#instalamos el microcodigo del procesador
#pkg install cpu-microcode-intel
pkg install -y cpu-microcode-amd

sysrc microcode_update_enable="YES"
service microcode_update start
#sddm-freebsd-black-theme
#x11-wm/picom
pkg install -y lxqt xdg-user-dirs 
pkg install -y sddm devel/qt6-5compat
git clone https://github.com/Automatisa/sddm-sugar-dark.git /usr/local/share/sddm/themes/sugar_dark
pkg install -y xsettingsd
#pkg install -y noto gnu-unifont-otf hack-font roboto-fonts-ttf font-awesome
pkg install -y xcompmgr openbox-arc-theme cursor-dmz-theme papirus-icon-theme
pkg install -y gvfs fusefs-ntfs fusefs-exfat ffmpegthumbnailer pavucontrol-qt freedesktop-sound-theme noto gnu-unifont-otf hack-font roboto-fonts-ttf font-awesome

sysrc dbus_enable="YES"
sysrc sddm_enable="YES"

#instalamos paquetes de programas
#pkg install -y firefox libreoffice gimp vlc inkscape qpdfview

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
# echo "exec mate-session" > /usr/share/skel/dot.xinitrc
# echo "exec cinnamon-session" > /usr/share/skel/dot.xinitrc
# echo "exec startxfce4" > /usr/share/skel/dopkg install pavucontrol-qt freedesktop-sound-themet.xinitrc
# echo "exec startplasma-x11" > /usr/share/skel/dot.xinitrc



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
#### install app
pkg install geany firefox vscode




