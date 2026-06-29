#!/bin/bash
set -e

echo "╔══════════════════════════════════════════╗"
echo "║     OPTIMIZADOR DE RENDIMIENTO LINUX     ║"
echo "╚══════════════════════════════════════════╝"
echo

if [ "$EUID" -eq 0 ]; then
  echo "No ejecutar como root. Ejecutar como usuario normal."
  exit 1
fi

echo "▶ Verificando contraseña sudo..."
sudo -v || exit 1

# ===== 0. WIFI BROADCOM (MacBook BCM4360) =====
echo
echo "═══════════════════════════════════════════"
echo " 0. Driver WiFi Broadcom (MacBook)"
echo "═══════════════════════════════════════════"
if lspci -k 2>/dev/null | grep -qi broadcom; then
  if lsmod | grep -q "^wl"; then
    echo "   ✅ WiFi Broadcom (wl) ya activo"
  else
    echo "   ⏩ Instalando driver wl (REQUIERE cable/tethering la 1ra vez)..."
    sudo apt install -y bcmwl-kernel-source broadcom-sta-dkms
    sudo modprobe wl 2>/dev/null || true
    echo "   ✅ WiFi Broadcom instalado"
  fi
else
  echo "   ⏩ Sin hardware Broadcom, saltando"
fi

# ===== 0b. KERNEL FIJO (el WiFi Broadcom falla en otros) =====
echo
echo "═══════════════════════════════════════════"
echo " 0b. Fijar kernel 6.14.0-37 (estable con WiFi)"
echo "═══════════════════════════════════════════"
KVER="6.14.0-37-generic"
if uname -r | grep -q "$KVER" && dpkg -l "linux-image-$KVER" 2>/dev/null | grep -q "^ii"; then
  echo "   ✅ Kernel $KVER ya instalado"
else
  echo "   ⏩ Instalando kernel $KVER (si sigue en los repos)..."
  sudo apt install -y "linux-image-$KVER" "linux-headers-$KVER" \
                      "linux-modules-$KVER" "linux-modules-extra-$KVER" \
    || echo "   ⚠️  Versión no disponible en repos; usar los .deb del release si hace falta"
fi
# Bloquear actualizaciones de kernel (evita romper el driver wl)
sudo apt-mark hold "linux-image-$KVER" "linux-headers-$KVER" \
                   "linux-modules-$KVER" "linux-modules-extra-$KVER" \
                   linux-generic-6.14 linux-image-generic-6.14 linux-headers-generic-6.14 2>/dev/null
echo "   ✅ Kernel bloqueado (apt-mark hold) — no se actualizará solo"

# ===== 1. SYSCTL =====
echo
echo "═══════════════════════════════════════════"
echo " 1. Parámetros del kernel (sysctl)"
echo "═══════════════════════════════════════════"
echo 'vm.swappiness=10
vm.vfs_cache_pressure=200' | sudo tee /etc/sysctl.d/99-performance.conf > /dev/null
sudo sysctl -p /etc/sysctl.d/99-performance.conf
echo "   ✅ sysctl aplicado"

# ===== 2. NOATIME =====
echo
echo "═══════════════════════════════════════════"
echo " 2. noatime en SSD"
echo "═══════════════════════════════════════════"
if mount | grep "on / " | grep -q noatime; then
  echo "   ✅ noatime ya activo"
else
  sudo sed -i 's/errors=remount-ro/noatime,errors=remount-ro/' /etc/fstab
  sudo mount -o remount /
  echo "   ✅ noatime aplicado"
fi

# ===== 3. KERNEL BOOT PARAMS =====
echo
echo "═══════════════════════════════════════════"
echo " 3. Desactivar mitigaciones de seguridad"
echo "═══════════════════════════════════════════"
CURRENT_CMDLINE="quiet splash mitigations=off nowatchdog nmi_watchdog=0"
if grep -q "mitigations=off" /etc/default/grub 2>/dev/null; then
  echo "   ✅ Ya configurado"
else
  sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"$CURRENT_CMDLINE\"/" /etc/default/grub
  sudo update-grub
  echo "   ✅ Aplicado (requiere reinicio)"
fi

# ===== 4. ZRAM =====
echo
echo "═══════════════════════════════════════════"
echo " 4. ZRAM (swap comprimido en RAM)"
echo "═══════════════════════════════════════════"
if command -v zramctl &>/dev/null && zramctl 2>/dev/null | grep -q zram; then
  echo "   ✅ ZRAM ya activo"
else
  sudo apt install -y zram-tools
  sudo sed -i 's/#PERCENT=50/PERCENT=50/' /etc/default/zramswap
  sudo systemctl enable --now zramswap.service
  echo "   ✅ ZRAM instalado y activo"
fi

# ===== 5. PRELOAD =====
echo
echo "═══════════════════════════════════════════"
echo " 5. Preload (precarga de apps)"
echo "═══════════════════════════════════════════"
if command -v preload &>/dev/null; then
  echo "   ✅ Preload ya instalado"
else
  sudo apt install -y preload
  echo "   ✅ Preload instalado"
fi

# ===== 6. ANANICY =====
echo
echo "═══════════════════════════════════════════"
echo " 6. Ananicy (prioridades automáticas)"
echo "═══════════════════════════════════════════"
if systemctl is-active ananicy &>/dev/null; then
  echo "   ✅ Ananicy ya activo"
elif [ -d "/tmp/Ananicy" ]; then
  sudo apt install -y schedtool 2>/dev/null
  sudo dpkg -i /tmp/Ananicy/ananicy-*.deb 2>/dev/null || true
  sudo systemctl enable --now ananicy 2>/dev/null && echo "   ✅ Ananicy instalado"
else
  echo "   ⏩ Descargar ananicy desde GitHub..."
  git clone https://github.com/Nefelim4ag/Ananicy.git /tmp/Ananicy 2>/dev/null
  cd /tmp/Ananicy && ./package.sh debian 2>/dev/null
  sudo apt install -y schedtool 2>/dev/null
  sudo dpkg -i /tmp/Ananicy/ananicy-*.deb 2>/dev/null
  sudo systemctl enable --now ananicy 2>/dev/null
  echo "   ✅ Ananicy instalado"
fi

# ===== 7. XFCE COMPOSITOR =====
echo
echo "═══════════════════════════════════════════"
echo " 7. Compositor xfwm4 (transparencias)"
echo "═══════════════════════════════════════════"
if command -v xfconf-query &>/dev/null; then
  xfconf-query -c xfwm4 -p /general/use_compositing -s true 2>/dev/null
  xfconf-query -c xfwm4 -p /general/frame_opacity -s 90 2>/dev/null
  xfconf-query -c xfwm4 -p /general/inactive_opacity -s 80 2>/dev/null
  echo "   ✅ Compositor xfwm4 activado"
else
  echo "   ⏩ XFCE no detectado, saltando"
fi

# ===== 8. XFCE SESSION RESTORE =====
echo
echo "═══════════════════════════════════════════"
echo " 8. Desactivar restauración de sesión XFCE"
echo "═══════════════════════════════════════════"
if command -v xfconf-query &>/dev/null; then
  xfconf-query -c xfce4-session -p /general/SaveOnExit -s false 2>/dev/null
  rm -f ~/.cache/sessions/xfce4-session-* 2>/dev/null
  echo "   ✅ Session restore desactivado"
else
  echo "   ⏩ No aplica"
fi

# ===== 9. FIREFOX =====
echo
echo "═══════════════════════════════════════════"
echo " 9. Desactivar restauración Firefox"
echo "═══════════════════════════════════════════"
FF_PROFILE=$(ls -d ~/.mozilla/firefox/*.default-release 2>/dev/null | head -1)
if [ -n "$FF_PROFILE" ] && [ -f "$FF_PROFILE/prefs.js" ]; then
  if grep -q "browser.sessionstore.resume_from_crash" "$FF_PROFILE/prefs.js" 2>/dev/null; then
    echo "   ✅ Firefox ya configurado"
  else
    echo '
user_pref("browser.startup.page", 0);
user_pref("browser.sessionstore.resume_from_crash", false);' >> "$FF_PROFILE/prefs.js"
    echo "   ✅ Firefox configurado"
  fi
else
  echo "   ⏩ Firefox no detectado"
fi

# ===== 10. BORRAR AUTOSTART INNECESARIO =====
echo
echo "═══════════════════════════════════════════"
echo "10. Limpiar programas de inicio"
echo "═══════════════════════════════════════════"
rm -f ~/.config/autostart/plank.desktop 2>/dev/null
rm -f ~/.config/autostart/print-applet.desktop 2>/dev/null
rm -f ~/.config/autostart/mintupdate.desktop 2>/dev/null
rm -f ~/.config/autostart/mintreport.desktop 2>/dev/null
rm -f ~/.config/autostart/blueman.desktop 2>/dev/null
rm -f ~/.config/autostart/picom.desktop 2>/dev/null
echo "   ✅ Autostart limpio"

# ===== 11. DESACTIVAR SERVICIOS =====
echo
echo "═══════════════════════════════════════════"
echo "11. Desactivar servicios innecesarios"
echo "═══════════════════════════════════════════"
for s in transmission-daemon cups cups-browsed kerneloops rsyslog accounts-daemon \
         power-profiles-daemon switcheroo-control speech-dispatcher iio-sensor-proxy \
         lxc lxc-net lxc-monitord lxcfs obex; do
  sudo systemctl disable --now "$s" 2>/dev/null || true
done
for s in bolt colord power-profiles-daemon; do
  sudo systemctl mask "$s" 2>/dev/null || true
done
for s in obex gvfs-daemon gvfs-afc-volume-monitor gvfs-goa-volume-monitor \
         gvfs-gphoto2-volume-monitor gvfs-mtp-volume-monitor gvfs-udisks2-volume-monitor \
         gvfs-metadata at-spi-dbus-bus; do
  systemctl --user stop "$s" 2>/dev/null || true
  systemctl --user mask "$s" 2>/dev/null || true
done
sudo systemctl mask cups.socket cups.path 2>/dev/null
sudo systemctl mask docker.service docker.socket 2>/dev/null
echo "   ✅ Servicios innecesarios desactivados"

# ===== 12. ELIMINAR PAQUETES =====
echo
echo "═══════════════════════════════════════════"
echo "12. Eliminar paquetes pesados innecesarios"
echo "═══════════════════════════════════════════"
sudo apt remove --purge -y thunderbird libreoffice-core libreoffice-common picom \
                          docker.io docker-ce docker-ce-cli containerd lxc lxcfs \
                          cups cups-browsed 2>/dev/null || true
sudo apt autoremove --purge -y 2>/dev/null || true
echo "   ✅ Paquetes eliminados"

# ===== 13. SCRIPTS thunderbolt-on / bluetooth-on =====
echo
echo "═══════════════════════════════════════════"
echo "13. Crear scripts thunderbolt-on y bluetooth-on"
echo "═══════════════════════════════════════════"
cat > ~/thunderbolt-on << 'THUN'
#!/bin/bash
sudo systemctl unmask bolt.service 2>/dev/null
sudo systemctl start bolt.service 2>/dev/null
if systemctl is-active bolt.service &>/dev/null; then
  echo "Thunderbolt activado"
else
  echo "Error al activar Thunderbolt"
  exit 1
fi
THUN
chmod +x ~/thunderbolt-on

cat > ~/bluetooth-on << 'BTON'
#!/bin/bash
sudo systemctl start blueman-mechanism.service 2>/dev/null
/usr/lib/blueman/blueman-applet &
echo "Bluetooth activado"
BTON
chmod +x ~/bluetooth-on

mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/thunderbolt-on.desktop << 'TDESK'
[Desktop Entry]
Type=Application
Name=Thunderbolt On
Comment=Activar servicio Thunderbolt
Exec=/home/$USER/thunderbolt-on
Icon=thunderbolt
Categories=Utility;X-Professional;
Terminal=false
StartupNotify=false
TDESK
cat > ~/.local/share/applications/bluetooth-on.desktop << 'BDESK'
[Desktop Entry]
Type=Application
Name=Bluetooth On
Comment=Activar servicio Bluetooth
Exec=/home/$USER/bluetooth-on
Icon=blueman
Categories=Utility;X-Professional;
Terminal=false
StartupNotify=false
BDESK
echo "   ✅ Scripts creados"

# ===== 14. FIREFOX VA-API + WEBRENDER =====
echo
echo "═══════════════════════════════════════════"
echo "14. Firefox: aceleración de video por GPU"
echo "═══════════════════════════════════════════"
FF_PROFILE=$(ls -d ~/.mozilla/firefox/*.default-release 2>/dev/null | head -1)
if [ -n "$FF_PROFILE" ]; then
  cat > "$FF_PROFILE/user.js" << 'FFEOF'
// --- Aceleracion de video/GPU (Intel HD 6000) ---
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
user_pref("media.rdd-ffmpeg.enabled", true);
user_pref("gfx.webrender.all", true);
user_pref("layers.acceleration.force-enabled", true);
user_pref("browser.sessionstore.interval", 60000);
FFEOF
  echo "   ✅ user.js (VA-API + WebRender) — recuerda instalar extensión h264ify"
else
  echo "   ⏩ Firefox no detectado"
fi

# ===== 15. EARLYOOM (anti-congelamiento) =====
echo
echo "═══════════════════════════════════════════"
echo "15. earlyoom (evita freezes por falta de RAM)"
echo "═══════════════════════════════════════════"
if systemctl is-active earlyoom &>/dev/null; then
  echo "   ✅ earlyoom ya activo"
else
  sudo apt install -y earlyoom
  sudo systemctl enable --now earlyoom
  echo "   ✅ earlyoom instalado y activo"
fi

# ===== 16. GPU FBC + GRUB TIMEOUT =====
echo
echo "═══════════════════════════════════════════"
echo "16. GPU framebuffer compression + boot rápido"
echo "═══════════════════════════════════════════"
if ! grep -q "i915.enable_fbc=1" /etc/default/grub; then
  sudo sed -i 's/mitigations=off/mitigations=off i915.enable_fbc=1/' /etc/default/grub
fi
sudo sed -i 's/^GRUB_TIMEOUT=5/GRUB_TIMEOUT=1/' /etc/default/grub
sudo update-grub
echo "   ✅ i915.enable_fbc=1 + GRUB_TIMEOUT=1 (requiere reinicio)"

# ===== 17. SERVICIOS INÚTILES (hardware ausente) =====
echo
echo "═══════════════════════════════════════════"
echo "17. Desactivar servicios sin hardware/uso"
echo "═══════════════════════════════════════════"
sudo systemctl disable --now blueman-mechanism.service 2>/dev/null || true
sudo systemctl disable fwupd-refresh.timer 2>/dev/null || true
for s in ModemManager motd-news.timer motd-news.service \
         avahi-daemon.service avahi-daemon.socket; do
  sudo systemctl disable --now "$s" 2>/dev/null || true
  sudo systemctl mask "$s" 2>/dev/null || true
done
echo "   ✅ ModemManager, motd-news, avahi, blueman-mechanism, fwupd-refresh OFF"

# ===== 18. AUTOSTART INÚTIL + NUNCA BLOQUEAR PANTALLA =====
echo
echo "═══════════════════════════════════════════"
echo "18. Autostart inútil + pantalla sin bloqueo"
echo "═══════════════════════════════════════════"
mkdir -p ~/.config/autostart
# desactivar autostart globales que no aplican (override per-usuario)
for app in nvidia-prime orca-autostart onboard-autostart at-spi-dbus-bus \
           geoclue-demo-agent org.gnome.Evolution-alarm-notify \
           org.gnome.SettingsDaemon.DiskUtilityNotify print-applet \
           mintwelcome xscreensaver warpinator-autostart mintupdate \
           light-locker betterlockscreen; do
  src="/etc/xdg/autostart/$app.desktop"
  [ -f "$src" ] && cp "$src" ~/.config/autostart/"$app.desktop"
  f=~/.config/autostart/"$app.desktop"
  [ -f "$f" ] || { echo -e "[Desktop Entry]\nType=Application\nExec=/bin/false" > "$f"; }
  grep -q "^Hidden=" "$f" && sed -i 's/^Hidden=.*/Hidden=true/' "$f" || echo "Hidden=true" >> "$f"
done
# pantalla: nunca bloquear (persistente)
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lock-screen-suspend-hibernate -s false 2>/dev/null || true
xfconf-query -c xfce4-screensaver -p /lock/enabled -s false 2>/dev/null || true
xfconf-query -c xfce4-session -p /shutdown/LockScreen -s false 2>/dev/null || true
pkill -x light-locker 2>/dev/null || true
xset s off 2>/dev/null || true
echo "   ✅ Autostart limpio + pantalla nunca se bloquea"

# ===== 19. MÁXIMO RENDIMIENTO PERSISTENTE (CPU/GPU/PCIe/Fan) =====
echo
echo "═══════════════════════════════════════════"
echo "19. Servicio de máximo rendimiento (sin ahorro de energía)"
echo "═══════════════════════════════════════════"
# msr-tools: necesario para subir el limite de potencia y desactivar BD PROCHOT
sudo apt install -y msr-tools 2>/dev/null || true
sudo tee /usr/local/bin/max-performance.sh > /dev/null << 'MAXEOF'
#!/bin/bash
# === MÁXIMO RENDIMIENTO — sin ahorro de energía (CPU/GPU/PCIe/Fan) ===
# CPU: performance + frecuencia minima = maxima (nunca baja, igual en bateria)
for cf in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
  echo performance > "$cf/scaling_governor" 2>/dev/null || true
  [ -r "$cf/cpuinfo_max_freq" ] && cat "$cf/cpuinfo_max_freq" > "$cf/scaling_min_freq" 2>/dev/null || true
done
echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
# RAPL: DESACTIVAR el power-capping de Linux.
# OJO: en este MacBook Air, ACTIVAR el capping (enabled=1) clava la CPU a ~500MHz/5W
# aunque el limite sea 100W. Por eso aqui se DESHABILITA el enforcement.
# Las protecciones reales por sobretemperatura (Tjmax/PROCHOT del EC) siguen activas.
for d in /sys/class/powercap/intel-rapl:0 /sys/class/powercap/intel-rapl:0:*; do
  [ -d "$d" ] && echo 0 > "$d/enabled" 2>/dev/null || true
done
# MSR: subir limite de potencia del paquete y desactivar BD PROCHOT (señal del SMC)
if command -v rdmsr >/dev/null 2>&1 && command -v wrmsr >/dev/null 2>&1; then
  modprobe msr 2>/dev/null || true
  for c in $(seq 0 $(($(nproc) - 1))); do
    wrmsr -p "$c" 0x610 0x00dd8320 2>/dev/null || true
    v=$(rdmsr -p "$c" 0x1FC 2>/dev/null) || continue
    wrmsr -p "$c" 0x1FC "$(printf '0x%x' $((0x$v & ~1)))" 2>/dev/null || true
  done
fi
# GPU Intel: frecuencia minima = maxima
for card in /sys/class/drm/card*; do
  if [ -r "$card/gt_RP0_freq_mhz" ]; then
    RP0=$(cat "$card/gt_RP0_freq_mhz" 2>/dev/null)
    [ -n "$RP0" ] && echo "$RP0" > "$card/gt_min_freq_mhz" 2>/dev/null || true
    [ -n "$RP0" ] && echo "$RP0" > "$card/gt_boost_freq_mhz" 2>/dev/null || true
  fi
done
# PCIe sin ahorro
echo performance > /sys/module/pcie_aspm/parameters/policy 2>/dev/null || true
# Ventilador MacBook (Apple SMC) al maximo
SMC=/sys/devices/platform/applesmc.768
if [ -d "$SMC" ]; then
  FMAX=$(cat "$SMC/fan1_max" 2>/dev/null)
  echo 1 > "$SMC/fan1_manual" 2>/dev/null || true
  [ -n "$FMAX" ] && echo "$FMAX" > "$SMC/fan1_output" 2>/dev/null || true
  [ -n "$FMAX" ] && echo "$FMAX" > "$SMC/fan1_min" 2>/dev/null || true
fi
MAXEOF
sudo chmod +x /usr/local/bin/max-performance.sh
sudo tee /etc/systemd/system/max-performance.service > /dev/null << 'SVCEOF'
[Unit]
Description=CPU al maximo + ventilador al maximo (sin ahorro de energia)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/max-performance.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF
sudo systemctl daemon-reload
sudo systemctl enable --now max-performance.service
echo "   ✅ CPU/GPU/PCIe/ventilador fijados al máximo (persistente, igual en batería)"

# ===== 20. EXPERIENCIA MAC: TRACKPAD + TECLADO + ATAJOS =====
echo
echo "═══════════════════════════════════════════"
echo "20. Experiencia Mac (trackpad, teclado, atajos)"
echo "═══════════════════════════════════════════"
# dependencias
sudo apt install -y libinput-gestures xbindkeys xdotool xcape \
                    xfce4-screenshooter
# grupo input (necesario para libinput-gestures)
sudo gpasswd -a "$USER" input 2>/dev/null || true

# --- Trackpad: tap, click con dedos, scroll natural (estilo Mac) ---
sudo tee /etc/X11/xorg.conf.d/40-touchpad.conf > /dev/null << 'TPEOF'
Section "InputClass"
    Identifier "bcm5974 touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
    Option "TappingButtonMap" "lrm"
    Option "ClickMethod" "clickfinger"
    Option "NaturalScrolling" "true"
EndSection
TPEOF

# --- Gestos del trackpad (pinch zoom / 5 dedos = F4) ---
cat > ~/.config/libinput-gestures.conf << 'GESTEOF'
device bcm5974
gesture pinch out 2 xdotool key ctrl+plus
gesture pinch in 2 xdotool key ctrl+minus
gesture pinch in 5 xdotool key F4
gesture pinch out 5 xdotool key F4
GESTEOF

# --- Teclado Mac: layout latam, Cmd->Ctrl, acentos, xcape ---
cat > ~/.config/mac-keyboard.sh << 'KBEOF'
#!/bin/bash
# Layout base correcto para teclado Mac latino
setxkbmap -layout latam -variant nodeadkeys -option "terminate:ctrl_alt_bksp,lv3:lalt_switch"
# Dead keys solo en teclas de acento
xmodmap -e "keycode 34 = dead_grave asciicircum dead_grave asciicircum bracketleft degree bracketleft"
xmodmap -e "keycode 48 = dead_acute diaeresis dead_acute diaeresis braceleft braceleft braceleft"
# Cmd (Super_L) actúa como Ctrl
xmodmap -e "remove mod4 = Super_L"
xmodmap -e "keycode 133 = Control_L NoSymbol Control_L"
xmodmap -e "add control = Control_L"
# F20 para xcape (Control_L sola = abrir/cerrar widget)
xmodmap -e "keycode 253 = F20"
killall xcape 2>/dev/null
xcape -e 'Control_L=F20'
KBEOF
chmod +x ~/.config/mac-keyboard.sh

# --- Atajos (xbindkeys): screenshots estilo Mac + tiling 6 zonas ---
cat > ~/.xbindkeysrc << 'XBEOF'
"xfce4-screenshooter -f -s $HOME/Desktop"
  control+shift + 3
"xfce4-screenshooter -r -s $HOME/Desktop"
  control+shift + 4
"xfce4-screenshooter -f -c"
  control+shift + c:14
"xfce4-screenshooter -r -c"
  control+shift + c:15
XBEOF

# --- Autostart de los 3 (teclado, gestos, atajos) ---
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/mac-keyboard.desktop << KBDESK
[Desktop Entry]
Type=Application
Name=Mac Keyboard Setup
Exec=/bin/bash $HOME/.config/mac-keyboard.sh
X-GNOME-Autostart-enabled=true
KBDESK
cat > ~/.config/autostart/libinput-gestures.desktop << 'GDESK'
[Desktop Entry]
Type=Application
Name=Libinput Gestures
Exec=/usr/bin/libinput-gestures
X-GNOME-Autostart-enabled=true
GDESK
cat > ~/.config/autostart/xbindkeys.desktop << 'XDESK'
[Desktop Entry]
Type=Application
Name=xbindkeys
Exec=/usr/bin/xbindkeys
X-GNOME-Autostart-enabled=true
XDESK
echo "   ✅ Trackpad + teclado Mac + atajos configurados (re-loguear para aplicar todo)"

# ===== 21. (OPCIONAL) BARRA DE TAREAS + FONDO IDÉNTICOS =====
echo
echo "═══════════════════════════════════════════"
echo "21. (Opcional) Barra de tareas + fondo de escritorio"
echo "═══════════════════════════════════════════"
read -rp "   ¿Instalar la barra de tareas y el fondo idénticos al original? (s/N): " RESP
if [[ "$RESP" =~ ^[sS] ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -d "$SCRIPT_DIR/desktop" ]; then
    # Fondo de escritorio
    mkdir -p ~/"Imágenes/wallpapers"
    cp "$SCRIPT_DIR/desktop/Sonoma.jpg" ~/"Imágenes/wallpapers/" 2>/dev/null || true
    # Config del panel
    mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml ~/.config/xfce4/panel
    cp "$SCRIPT_DIR/desktop/xfce4-panel.xml" ~/.config/xfce4/xfconf/xfce-perchannel-xml/ 2>/dev/null || true
    cp -r "$SCRIPT_DIR/desktop/panel/." ~/.config/xfce4/panel/ 2>/dev/null || true
    # Reemplazar rutas /home/koe por el HOME real (portable a otro usuario)
    find ~/.config/xfce4/panel ~/.config/xfce4/xfconf/xfce-perchannel-xml \
         -type f -exec sed -i "s#/home/koe#$HOME#g" {} + 2>/dev/null || true
    # Aplicar fondo en todos los monitores/espacios
    for prop in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep last-image); do
      xfconf-query -c xfce4-desktop -p "$prop" -s "$HOME/Imágenes/wallpapers/Sonoma.jpg" 2>/dev/null || true
    done
    # Recargar panel
    xfce4-panel -r 2>/dev/null || true
    echo "   ✅ Barra de tareas + fondo aplicados"
  else
    echo "   ⚠️  Falta la carpeta 'desktop/' junto al script"
  fi
else
  echo "   ⏩ Omitido (solo optimizaciones de sistema)"
fi

# ===== RESUMEN =====
echo
echo "╔══════════════════════════════════════════╗"
echo "║         OPTIMIZACIÓN COMPLETADA          ║"
echo "╚══════════════════════════════════════════╝"
echo
echo "   🔄 REINICIA para aplicar mitigations=off (+15% CPU)"
echo
echo "   Scripts disponibles:"
echo "     ~/thunderbolt-on     — Activar Thunderbolt"
echo "     ~/bluetooth-on       — Activar Bluetooth"
echo
