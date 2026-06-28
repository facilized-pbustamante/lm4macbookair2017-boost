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
