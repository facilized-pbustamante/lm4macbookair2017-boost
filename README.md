# 🚀 LM4 MacBook Air 2017 — Performance Boost

Optimizaciones de rendimiento para **Linux Mint** corriendo en un **MacBook Air 2017** (Intel Core i5-5350U, 8 GB DDR3, NVMe SSD).

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
| **SO** | Linux Mint (XFCE) |
| **Kernel** | 6.14.0-37-generic |
