# 🚀 LM4 MacBook Air 2017 — Performance Boost

Optimizaciones de rendimiento para **Linux Mint** corriendo en un **MacBook Air 2017** (Intel Core i5-5350U, 8 GB DDR3, NVMe SSD).

> ⚠️ **WiFi en MacBook (importante):** el script instala el driver Broadcom (`bcmwl-kernel-source`),
> pero la BCM4360 **no funciona en una instalación limpia hasta instalarlo** → la primera vez
> necesitas **cable Ethernet o tethering USB** para que `apt` pueda descargar todo.
>
> 🔁 **Qué reproduce este script:** la **capa de rendimiento/sistema** (kernel, servicios,
> governor, ventilador, autostart, sin bloqueo de pantalla, aceleración Firefox). **NO** clona
> el escritorio personal (temas, rofi, atajos de teclado, betterlockscreen, gestos, lanzadores,
> perfil de Firefox/extensiones, ollama). Eso es configuración aparte.

---

## 📊 Resultados

| Métrica | Antes | Después |
|---------|-------|--------|
| Tiempo de inicio | ~1 min 45 s | **~7 s** |
| RAM libre al arranque | ~3 GB | **~5.5 GB** |
| CPU disponible | 100% (con mitigaciones) | **~115%** (sin mitigaciones) |
| Servicios en segundo plano | ~45 | **~15** |
| Programas de inicio | 12 | **5** |

---

## ⚡ Optimizaciones aplicadas

### 1. Desactivación de mitigaciones de CPU (`+15%`)
Desactivadas todas las mitigaciones de seguridad (Spectre, Meltdown, MDS, L1TF, SSB) que en conjunto reducían el rendimiento del i5-5350U hasta un 20%.

**Kernel boot params:**
```
mitigations=off nowatchdog nmi_watchdog=0
```

### 2. zram — Swap comprimido en RAM
Crea un disco de swap comprimido usando el 50% de la RAM (3.8 GB), priorizado sobre el swap de disco. Mucho más rápido que el swapfile tradicional.

### 3. Preload — Precarga adaptativa
Demonio que aprende qué programas usas frecuentemente y precarga sus librerías en RAM para que abran al instante.

### 4. Ananicy — Prioridades automáticas
Ajusta automáticamente las prioridades (`nice`/`ionice`) de los procesos según reglas comunitarias:
- Juegos y programas activos → mayor prioridad
- Tareas de fondo (compilación, descargas) → menor prioridad

### 5. noatime — Menos escrituras al SSD
Desactiva la actualización de fecha de acceso a archivos, reduciendo escrituras innecesarias al SSD NVMe y mejorando velocidad de lectura.

### 6. Parámetros del kernel optimizados
```ini
vm.swappiness=10           # Swap solo cuando sea urgente
vm.vfs_cache_pressure=200  # Libera caché de archivos más rápido
```

### 7. Compositor ligero (xfwm4)
Reemplazado `picom` por el compositor nativo de XFCE. Transparencias suaves sin el overhead de picom.

### 8. Servicios eliminados o desactivados

| Servicio | Motivo |
|----------|--------|
| `transmission-daemon` | +90 s de inicio eliminados |
| `docker` / `containerd` | No utilizado |
| `cups` / `cups-browsed` | Sin impresora |
| `lxc` / `lxcfs` | Contenedores no utilizados |
| `bolt` | Thunderbolt (se activa bajo demanda) |
| `blueman-mechanism` | Bluetooth (se activa bajo demanda) |
| `accounts-daemon` | Innecesario en escritorio personal |
| `kerneloops` | Envío de logs a Canonical |
| `rsyslog` | Logs en disco (journald basta) |
| `power-profiles-daemon` | Choca con governor `performance` |
| `switcheroo-control` | Solo GPU Intel, sin switcheo |
| `speech-dispatcher` | Accesibilidad no necesaria |
| `gvfs-*` | Monitores de iPhone/cámara/Android |
| `colord` | Perfiles de color |
| `iio-sensor-proxy` | Sensor de orientación |
| `obex` | Transferencia Bluetooth |
| `packagekit` | Gestor de paquetes gráfico |
| `fwupd` | Actualizaciones de firmware |

### 9. Programas de inicio limpiados
Eliminados del autostart: `plank`, `print-applet`, `blueman`, `mintupdate`, `mintreport`, `picom`.

### 10. Programas pesados eliminados
- **Thunderbird** (~280 MB)
- **LibreOffice** (~145 MB)
- **Picom** (~5 MB + CPU overhead)
- **Docker** (~130 MB)

### 11. Firefox — Sin restauración de sesión
```javascript
user_pref("browser.startup.page", 0);
user_pref("browser.sessionstore.resume_from_crash", false);
```

### 12. XFCE — Sin guardar sesión
`SaveOnExit=false` para que no recuerde las aplicaciones abiertas al apagar.

---

## 🛠️ Script de automatización

El script [`optimizar-linux.sh`](optimizar-linux.sh) aplica todas estas optimizaciones automáticamente:

```bash
chmod +x optimizar-linux.sh
./optimizar-linux.sh
# Reiniciar para aplicar mitigations=off
```

---

## 📦 Scripts adicionales

| Script | Función |
|--------|---------|
| `thunderbolt-on` | Activa servicio Thunderbolt (con icono en Rofi) |
| `bluetooth-on` | Activa Bluetooth + applet (con icono en Rofi) |

---

## 🔧 Especificaciones del equipo

| Componente | Detalle |
|-----------|---------|
| **Modelo** | MacBook Air 2017 (A1466) |
| **CPU** | Intel Core i5-5350U @ 1.80 GHz (Turbo 2.90 GHz) |
| **RAM** | 8 GB DDR3 1600 MHz |
| **Disco** | NVMe SSD 916 GB |
| **GPU** | Intel HD Graphics 6000 |
| **SO** | Linux Mint 22.3 (XFCE) |
| **Kernel** | 6.14.0-37-generic |

---

## 🆕 v2 — Optimizaciones adicionales

Tras una auditoría completa se añadieron estas mejoras (secciones 14-19 del script):

### 14. Firefox — aceleración de video por GPU
`user.js` con VA-API + WebRender → descarga el decodificado H264 a la GPU y libera el CPU.
La HD 6000 **no** acelera VP9/AV1, así que YouTube necesita la extensión **h264ify** para
forzar H264 y aprovecharlo de verdad.

### 15. earlyoom
Mata el proceso que agota la RAM antes de que el equipo se congele (con 2 núcleos importa).

### 16. GPU Framebuffer Compression + boot rápido
`i915.enable_fbc=1` (la iGPU comparte el bus de RAM → menos tráfico, desktop más fluido) y
`GRUB_TIMEOUT 5→1` (−4 s por arranque).

### 17. Servicios sin hardware/uso (desactivados + enmascarados)
`ModemManager` (sin módem WWAN), `motd-news` (telemetría Canonical), `avahi-daemon`
(sin impresoras ni Warpinator), `blueman-mechanism` (BT on-demand), `fwupd-refresh.timer`.

### 18. Autostart inútil + pantalla nunca se bloquea
Desactivados vía override per-usuario (`Hidden=true`): `nvidia-prime` (sin NVIDIA), `orca`,
`onboard`, `at-spi-dbus-bus`, `geoclue-demo`, `evolution-alarm`, `gnome-disk-notify`,
`print-applet`, `mintwelcome`, `xscreensaver`, `warpinator`, `mintupdate`.
Bloqueo de pantalla **desactivado por completo**: `light-locker`/`betterlockscreen` off +
claves xfconf (`lock-screen-suspend-hibernate`, `screensaver/lock`, `session/LockScreen`) en `false`.

### 19. Máximo rendimiento permanente (CPU/GPU/PCIe/ventilador)
Servicio `max-performance.service` que en cada arranque fija, **igual en batería que enchufado**:
- **CPU**: governor `performance` + `scaling_min_freq = max` (nunca baja de 2.9 GHz) + turbo ON
- **GPU**: `gt_min_freq = gt_max` (siempre a 1000 MHz)
- **PCIe**: ASPM en `performance` (sin ahorro en el bus)
- **Ventilador** (Apple SMC): manual al máximo (~6500 RPM)
- **RAPL**: límites de potencia muy por encima del TDP del chip → no throttle por batería

> **Limitadores eliminados:** mitigaciones CPU, governor de ahorro, downclock en reposo,
> TLP/laptop-mode/power-profiles-daemon, RAPL. **Único que queda:** `thermald` (seguridad
> térmica, solo actúa ~105 °C; con el ventilador a tope no se dispara — **no quitar**).
>
> **Sin drivers custom:** GPU usa `i915` + Mesa 25.x (el stack óptimo; no hay propietario más
> rápido para Intel). El techo restante es físico: 2 núcleos, 2.9 GHz, 15 W.

### 0. WiFi Broadcom + 0b. Kernel fijo
- Instala el driver `wl` (`bcmwl-kernel-source`) para la BCM4360.
- **Fija e instala el kernel `6.14.0-37-generic` y lo bloquea** (`apt-mark hold`), porque el
  driver WiFi Broadcom **no funciona bien en otros kernels**. Evita que `apt` lo actualice solo.
  > Si esa versión ya no está en los repos de Ubuntu, hay que usar los `.deb` del release.

### 20. Experiencia Mac (trackpad + teclado + atajos)
- **Trackpad**: tap-to-click, click con dedos (`clickfinger`), scroll natural + gestos
  (pinch zoom, 5 dedos = F4) vía `libinput-gestures`.
- **Teclado**: layout `latam`, **Cmd → Ctrl**, acentos correctos, y `xcape` (Ctrl solo = F20).
- **Atajos** (`xbindkeys`): screenshots estilo Mac — Cmd+Shift+3/4 (a archivo en Desktop) y a portapapeles.

### 21. (Opcional) Barra de tareas + fondo de escritorio
Sección **interactiva** (pregunta s/N): copia desde `desktop/` el panel XFCE (`xfce4-panel.xml`
+ launchers) y el wallpaper (macOS Sonoma), ajustando rutas al usuario actual. Deja el escritorio
**idéntico** al original. Si respondes "N", solo se aplican las optimizaciones de sistema.

> Estructura del repo: el script usa la carpeta `desktop/` (panel + wallpaper) que debe ir
> **junto al script** al copiarlo a otro Mac.
