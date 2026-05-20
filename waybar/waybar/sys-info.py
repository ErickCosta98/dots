#!/usr/bin/env python3
import json, psutil, subprocess, os, re

# ----------------------------------------------------------
#  HELPERS
# ----------------------------------------------------------
def safe_run(cmd):
    try:
        return subprocess.check_output(cmd, text=True).strip()
    except:
        return ""

def read_sys(path):
    try:
        return open(path).read().strip()
    except:
        return None

# ----------------------------------------------------------
# CPU TEMP
# ----------------------------------------------------------
def get_cpu_temp():
    temps = psutil.sensors_temperatures()
    for name in ("k10temp", "coretemp", "cpu_thermal"):
        if name in temps:
            return int(temps[name][0].current)
    return 0

def cpu_icon_color(temp):
    if temp < 50: return "#a6e3a1"
    if temp < 70: return "#f9e2af"
    if temp < 85: return "#fe640b"
    return "#d20f39"

cpu_temp = get_cpu_temp()
cpu_load = psutil.cpu_percent()

# ----------------------------------------------------------
# GPU INFO (Arch)
# ----------------------------------------------------------
gpu_temp = 0
gpu_load = 0
gpu_name = "No GPU"

# NVIDIA
if safe_run(["bash","-lc","command -v nvidia-smi"]):
    out = safe_run(["nvidia-smi","--query-gpu=temperature.gpu,utilization.gpu","--format=csv,noheader,nounits"])
    if out:
        gpu_temp, gpu_load = map(int, out.split(","))
    gpu_name = "NVIDIA"

# AMD (amdgpu)
elif os.path.exists("/sys/class/drm/card0/device/hwmon"):
    hw = "/sys/class/drm/card0/device/hwmon"
    dirs = os.listdir(hw)
    if dirs:
        temp = read_sys(f"{hw}/{dirs[0]}/temp1_input")
        if temp:
            gpu_temp = int(temp)//1000
    # load no siempre disponible
    gpu_name = "AMD GPU"

# Intel
elif "intel" in safe_run(["lspci"]).lower():
    gpu_name = "Intel GPU"

# ----------------------------------------------------------
# MEMORY
# ----------------------------------------------------------
mem = psutil.virtual_memory()
mem_text = f"{mem.used//1024//1024} / {mem.total//1024//1024} MB"

# ----------------------------------------------------------
# STORAGE (solo discos reales)
# ----------------------------------------------------------
def get_storage_total():
    total = 0
    used = 0
    for part in psutil.disk_partitions():
        if "rw" not in part.opts: continue
        try:
            usage = psutil.disk_usage(part.mountpoint)
            total += usage.total
            used += usage.used
        except: pass
    return used, total

used,total = get_storage_total()

# ----------------------------------------------------------
# TEXT EN WAYBAR
# ----------------------------------------------------------
text = (
    f"<span foreground='{cpu_icon_color(cpu_temp)}'> {cpu_temp}°C</span>  "
    f" {gpu_temp}°C  "
    f" {mem_text}  "
    f" {used//1024//1024//1024}/{total//1024//1024//1024}GB"
)

# ----------------------------------------------------------
# TOOLTIP
# ----------------------------------------------------------
tooltip = (
    f"<b>CPU</b>\nTemp: {cpu_temp}°C\nLoad: {cpu_load}%\n\n"
    f"<b>GPU</b>\nType: {gpu_name}\nTemp: {gpu_temp}°C\nLoad: {gpu_load}%\n\n"
    f"<b>Memoria</b>\n{mem_text}\n\n"
    f"<b>Almacenamiento</b>\n{used//1024//1024//1024} / {total//1024//1024//1024} GB"
)

print(json.dumps({"text": text, "tooltip": tooltip, "markup": "pango"}))
