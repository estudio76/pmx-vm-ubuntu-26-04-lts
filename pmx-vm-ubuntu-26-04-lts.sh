#!/usr/bin/env bash

# Copyright (c) 2021-2026 Estudio76co
# Author: Estudio76co (happyCo) | Adaptado para Ubuntu 26.04 LTS de tteck (tteckster)
# License: MIT
# https://github.com/estudio76/pmx-vm-ubuntu-26-04-lts/blob/main/LICENSE

# ─────────────────────────────────────────────────────────────────────────────
# SEGURIDAD: Este script NO depende de repositorios externos en tiempo de
# ejecución y NO envía telemetría a ningún tercero.
# Todas las funciones están definidas localmente.
# ─────────────────────────────────────────────────────────────────────────────

function header_info {
  clear
  cat <<"EOF"
   __  ____                __           ___  __   ____  __ __     _    ____  ___
  / / / / /_  __  ______  / /___  __   |__ \/ /_ / __ \/ // /    | |  / /  |/  |
 / / / / __ \/ / / / __ \/ __/ / / /   __/ / _ \/ / / / // /_    | | / / /|_/ /
/ /_/ / /_/ / /_/ / / / / /_/ /_/ /   / __/  __/ /_/ /__  __/    | |/ / /  / /
\____/_.___/\__,_/_/ /_/\__/\__,_/   /____/\___/\____/  /_/       |___/_/  /_/

              Ubuntu 26.04 LTS - Resolute Raccoon - VM Creator
              github.com/estudio76/pmx-vm-ubuntu-26-04-lts
EOF
}
header_info
echo -e "\n Loading..."

GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
RANDOM_UUID="$(cat /proc/sys/kernel/random/uuid)"
METHOD=""
NSAPP="ubuntu2604-vm"
var_os="ubuntu"
var_version="2604"

YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BOLD=$(echo "\033[1m")
BFR="\\r\\033[K"
HOLD=" "
TAB="  "

CM="${TAB}✔️${TAB}${CL}"
CROSS="${TAB}✖️${TAB}${CL}"
INFO="${TAB}💡${TAB}${CL}"
OS="${TAB}🖥️${TAB}${CL}"
CONTAINERTYPE="${TAB}📦${TAB}${CL}"
DISKSIZE="${TAB}💾${TAB}${CL}"
CPUCORE="${TAB}🧠${TAB}${CL}"
RAMSIZE="${TAB}🛠️${TAB}${CL}"
CONTAINERID="${TAB}🆔${TAB}${CL}"
HOSTNAME="${TAB}🏠${TAB}${CL}"
BRIDGE="${TAB}🌉${TAB}${CL}"
GATEWAY="${TAB}🌐${TAB}${CL}"
DEFAULT="${TAB}⚙️${TAB}${CL}"
MACADDRESS="${TAB}🔗${TAB}${CL}"
VLANTAG="${TAB}🏷️${TAB}${CL}"
CREATING="${TAB}🚀${TAB}${CL}"
ADVANCED="${TAB}🧩${TAB}${CL}"

THIN="discard=on,ssd=1,"
set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
# ── ELIMINADO: traps que llamaban a post_update_to_api (telemetría externa) ───
# ANTES:
#   trap 'post_update_to_api "failed" "130"' SIGINT
#   trap 'post_update_to_api "failed" "143"' SIGTERM
#   trap 'post_update_to_api "failed" "129"; exit 129' SIGHUP
trap 'echo -e "\n${CROSS}${RD}Interrumpido por el usuario${CL}\n"; exit 130' SIGINT
trap 'echo -e "\n${CROSS}${RD}Script terminado (SIGTERM)${CL}\n"; exit 143' SIGTERM
trap 'echo -e "\n${CROSS}${RD}Sesión cerrada (SIGHUP)${CL}\n"; exit 129' SIGHUP

function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  # ── ELIMINADO: post_update_to_api "failed" "$exit_code" ──────────────────
  # Esa llamada enviaba datos del error al API de community-scripts
  local error_message="${RD}[ERROR]${CL} en línea ${RD}$line_number${CL}: código ${RD}$exit_code${CL}: comando ${YW}$command${CL}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function get_valid_nextid() {
  local try_id
  try_id=$(pvesh get /cluster/nextid)
  while true; do
    if [ -f "/etc/pve/qemu-server/${try_id}.conf" ] || [ -f "/etc/pve/lxc/${try_id}.conf" ]; then
      try_id=$((try_id + 1))
      continue
    fi
    if lvs --noheadings -o lv_name 2>/dev/null | grep -qE "(^|[-_])${try_id}($|[-_])"; then
      try_id=$((try_id + 1))
      continue
    fi
    break
  done
  echo "$try_id"
}

function cleanup_vmid() {
  if [ -n "${VMID:-}" ] && qm status "$VMID" &>/dev/null; then
    qm stop "$VMID" &>/dev/null
    qm destroy "$VMID" &>/dev/null
  fi
}

function cleanup() {
  local exit_code=$?
  popd >/dev/null 2>&1 || true
  rm -rf "${TEMP_DIR:-}"
}

TEMP_DIR=$(mktemp -d)
pushd "$TEMP_DIR" >/dev/null

if whiptail --backtitle "Estudio76co - Proxmox Scripts" --title "Ubuntu 26.04 LTS VM" \
  --yesno "Esto creará una nueva VM con Ubuntu 26.04 LTS (Resolute Raccoon). ¿Continuar?" 10 62; then
  :
else
  header_info && echo -e "${CROSS}${RD}Usuario salió del script${CL}\n" && exit
fi

function msg_info() { echo -ne "${TAB}${YW}${HOLD}${1}${HOLD}"; }
function msg_ok()   { echo -e "${BFR}${CM}${GN}${1}${CL}"; }
function msg_error(){ echo -e "${BFR}${CROSS}${RD}${1}${CL}"; }

function check_root() {
  if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Ejecuta este script como root."
    echo -e "\nSaliendo..."
    sleep 2
    exit
  fi
}

function pve_check() {
  local PVE_VER
  PVE_VER="$(pveversion | awk -F'/' '{print $2}' | awk -F'-' '{print $1}')"
  if [[ "$PVE_VER" =~ ^8\.([0-9]+) ]]; then
    return 0
  fi
  if [[ "$PVE_VER" =~ ^9\.([0-9]+) ]]; then
    return 0
  fi
  msg_error "Versión de Proxmox VE no soportada. Se requiere 8.x o 9.x"
  exit 105
}

function arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    echo -e "\n ${INFO}${YW}Este script no funciona en PiMox (ARM). \n"
    echo -e "Saliendo..."
    sleep 2
    exit
  fi
}

function ssh_check() {
  if command -v pveversion >/dev/null 2>&1; then
    if [ -n "${SSH_CLIENT:+x}" ]; then
      if whiptail --backtitle "Estudio76co - Proxmox Scripts" --defaultno --title "SSH DETECTADO" \
        --yesno "Se recomienda usar la shell de Proxmox en vez de SSH. ¿Continuar con SSH?" 10 62; then
        echo "advertencia aceptada"
      else
        clear && exit
      fi
    fi
  fi
}

function exit-script() {
  clear
  echo -e "\n${CROSS}${RD}Usuario salió del script${CL}\n"
  exit
}

function default_settings() {
  VMID=$(get_valid_nextid)
  FORMAT=",efitype=4m"
  MACHINE=""
  DISK_SIZE="20G"
  DISK_CACHE=""
  HN="ubuntu-2604"
  CPU_TYPE=""
  CORE_COUNT="2"
  RAM_SIZE="2048"
  BRG="vmbr0"
  MAC="$GEN_MAC"
  VLAN=""
  MTU=""
  START_VM="yes"
  METHOD="default"
  echo -e "${CONTAINERID}${BOLD}${DGN}VM ID: ${BGN}${VMID}${CL}"
  echo -e "${CONTAINERTYPE}${BOLD}${DGN}Machine Type: ${BGN}q35${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Disco: ${BGN}${DISK_SIZE}${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Disk Cache: ${BGN}None${CL}"
  echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}${HN}${CL}"
  echo -e "${OS}${BOLD}${DGN}CPU Model: ${BGN}KVM64${CL}"
  echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}${CORE_COUNT}${CL}"
  echo -e "${RAMSIZE}${BOLD}${DGN}RAM: ${BGN}${RAM_SIZE} MiB${CL}"
  echo -e "${BRIDGE}${BOLD}${DGN}Bridge: ${BGN}${BRG}${CL}"
  echo -e "${MACADDRESS}${BOLD}${DGN}MAC Address: ${BGN}${MAC}${CL}"
  echo -e "${VLANTAG}${BOLD}${DGN}VLAN: ${BGN}Default${CL}"
  echo -e "${DEFAULT}${BOLD}${DGN}MTU: ${BGN}Default${CL}"
  echo -e "${GATEWAY}${BOLD}${DGN}Iniciar VM al terminar: ${BGN}yes${CL}"
  echo -e "${INFO}${BOLD}${YW}Usa 'Advanced' para personalizar todos los valores${CL}"
  echo -e "${CREATING}${BOLD}${DGN}Creando Ubuntu 26.04 VM con configuración por defecto${CL}"
}

function advanced_settings() {
  METHOD="advanced"
  [ -z "${VMID:-}" ] && VMID=$(get_valid_nextid)

  # VM ID
  while true; do
    if VMID=$(whiptail --backtitle "Estudio76co - Proxmox Scripts" --inputbox "ID de la Máquina Virtual" \
      8 58 $VMID --title "VM ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      [ -z "$VMID" ] && VMID=$(get_valid_nextid)
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        echo -e "${CROSS}${RD} ID $VMID ya está en uso${CL}"; sleep 2; continue
      fi
      echo -e "${CONTAINERID}${BOLD}${DGN}VM ID: ${BGN}$VMID${CL}"; break
    else exit-script; fi
  done

  # Machine Type
  if MACH=$(whiptail --backtitle "Estudio76co - Proxmox Scripts" --title "MACHINE TYPE" --radiolist \
    "Elige el tipo de máquina" 10 58 2 \
    "q35"    "Machine q35 (recomendado)" ON \
    "i440fx" "Machine i440fx"            OFF \
    3>&1 1>&2 2>&3); then
    if [ "$MACH" = "q35" ]; then
      FORMAT=""; MACHINE=" -machine q35"
    else
      FORMAT=",efitype=4m"; MACHINE=""
    fi
    echo -e "${CONTAINERTYPE}${BOLD}${DGN}Machine Type: ${BGN}$MACH${CL}"
  else exit-script; fi

  # Disk Size
  if DISK_SIZE=$(whiptail --backtitle "Estudio76co - Proxmox Scripts" --inputbox \
    "Tamaño del disco en GiB (ej: 100)" 8 58 "100" --title "DISK SIZE" \
    --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    DISK_SIZE=$(echo "$DISK_SIZE" | tr -d ' ')
    [[ "$DISK_SIZE" =~ ^[0-9]+$ ]] && DISK_SIZE="${DISK_SIZE}G"
    echo -e "${DISKSIZE}${BOLD}${DGN}Disco: ${BGN}$DISK_SIZE${CL}"
  else exit-script; fi

  # Disk Cache
  if DISK_CACHE=$(whiptail --backtitle "Estudio76co - Proxmox Scripts" --title "DISK CACHE" \
    --radiolist "Elige el caché del disco" 10 58 2 \
    "0" "None (Default)" ON \
    "1" "Write Through"  OFF \
    3>&1 1>&2 2>&3); then
    if [ "$DISK_CACHE" = "1" ]; then
      DISK_CACHE="cache=writethrough,"
      echo -e "${DISKSIZE}${BOLD}${DGN}Disk Cache: ${BGN}Write Through${CL}"
    else
      DISK_CACHE=""
      echo -e "${DISKSIZE}${BOLD}${DGN}Disk Cache: ${BGN}None${CL}"
    fi
  else exit-script; fi

  # Hostname
  if VM_NAME=$(whiptail --backtitle "Estudio76co - Proxmox Scripts" --inputbox "Hostname de la VM" \
    8 58 "ubuntu-2604" --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    HN=$(echo "${VM_NAME,,}" | tr -cs 'a-z0-9-' '-' | sed 's/^-//;s/-$//')
    [ -z "$HN" ] && HN="ubuntu-2604"
    echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}$HN${CL}"
  else exit-script; fi

  # CPU Model
  if CPU_TYPE1=$(whiptail --backtitle "Estudio76co - Proxmox Scripts" --title "CPU MODEL" \
    --radiolist "Elige el modelo de CPU" 10 58 2 \
    "1" "Host (mejor rendimiento)"  ON \
    "0" "KVM64 (más compatible)"    OFF \
    3>&1 1>&2 2>&3); then
    if [ "$CPU_TYPE1" = "1" ]; then
      CPU_TYPE=" -cpu host"
      echo -e "${OS}${BOLD}${DGN}CPU Model: ${BGN}Host${CL}"
    else
      CPU_TYPE=""
      echo -e "${OS}${BOLD}${DGN}CPU Model: ${BGN}KVM64${CL}"
    fi
  else exit-script; fi

  # CPU Cores
  while true; do
    if CORE_COUNT=$(whiptail --backtitle "Estudio76co - Proxmox Scripts" --inputbox \
      "Número de cores CPU" 8 58 "2" --title "CPU CORES" \
      --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      [ -z "$CORE_COUNT" ] && CORE_COUNT="2"
      [[ "$CORE_COUNT" =~ ^[1-9][0-9]*$ ]] && { echo -e "${CPUCORE}${BOLD}${DGN}Cores: ${BGN}$CORE_COUNT${CL}"; break; }
    else exit-script; fi
  done

  # RAM
  while true; do
    if RAM_SIZE=$(whiptail --backtitle "Estudio76co - Proxmox Scripts" --inputbox \
      "RAM en MiB (ej: 4096)" 8 58 "4096" --title "RAM" \
      --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      [ -z "$RAM_SIZE" ] && RAM_SIZE="4096"
      [[ "$RAM_SIZE" =~ ^[1-9][0-9]*$ ]] && { echo -e "${RAMSIZE}${BOLD}${DGN}RAM: ${BGN}$RAM_SIZE MiB${CL}"; break; }
    else exit-script; fi
  done

  # Bridge
  if BRG=$(whiptail --backtitle "Estudio76co - Proxmox Scripts" --inputbox \
    "Bridge de red" 8 58 "vmbr1" --title "BRIDGE" \
    --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    [ -z "$BRG" ] && BRG="vmbr1"
    echo -e "${BRIDGE}${BOLD}${DGN}Bridge: ${BGN}$BRG${CL}"
  else exit-script; fi

  # MAC Address
  while true; do
    if MAC1=$(whiptail --backtitle "Estudio76co - Proxmox Scripts" --inputbox \
      "MAC Address" 8 58 $GEN_MAC --title "MAC ADDRESS" \
      --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      if [ -z "$MAC1" ]; then MAC="$GEN_MAC"
      elif [[ "$MAC1" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then MAC="$MAC1"
      else continue; fi
      echo -e "${MACADDRESS}${BOLD}${DGN}MAC: ${BGN}$MAC${CL}"; break
    else exit-script; fi
  done

  # VLAN
  while true; do
    if VLAN1=$(whiptail --backtitle "Estudio76co - Proxmox Scripts" --inputbox \
      "VLAN (deja en blanco para default)" 8 58 "" --title "VLAN" \
      --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      if [ -z "$VLAN1" ]; then VLAN=""; VLAN1="Default"
      elif [[ "$VLAN1" =~ ^[0-9]+$ ]] && [ "$VLAN1" -ge 1 ] && [ "$VLAN1" -le 4094 ]; then
        VLAN=",tag=$VLAN1"
      else continue; fi
      echo -e "${VLANTAG}${BOLD}${DGN}VLAN: ${BGN}$VLAN1${CL}"; break
    else exit-script; fi
  done

  # MTU
  while true; do
    if MTU1=$(whiptail --backtitle "Estudio76co - Proxmox Scripts" --inputbox \
      "MTU Size (deja en blanco para default)" 8 58 "" --title "MTU SIZE" \
      --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      if [ -z "$MTU1" ]; then MTU=""; MTU1="Default"
      elif [[ "$MTU1" =~ ^[0-9]+$ ]] && [ "$MTU1" -ge 576 ] && [ "$MTU1" -le 65520 ]; then
        MTU=",mtu=$MTU1"
      else continue; fi
      echo -e "${DEFAULT}${BOLD}${DGN}MTU: ${BGN}$MTU1${CL}"; break
    else exit-script; fi
  done

  # Start VM
  if whiptail --backtitle "Estudio76co - Proxmox Scripts" --title "INICIAR VM" \
    --yesno "¿Iniciar la VM al terminar?" 10 58; then
    START_VM="yes"
    echo -e "${GATEWAY}${BOLD}${DGN}Iniciar al terminar: ${BGN}yes${CL}"
  else
    START_VM="no"
    echo -e "${GATEWAY}${BOLD}${DGN}Iniciar al terminar: ${BGN}no${CL}"
  fi

  if whiptail --backtitle "Estudio76co - Proxmox Scripts" --title "LISTO" \
    --yesno "¿Crear la VM Ubuntu 26.04 con esta configuración?" --no-button Do-Over 10 58; then
    echo -e "${CREATING}${BOLD}${DGN}Creando Ubuntu 26.04 VM...${CL}"
  else
    header_info
    echo -e "${ADVANCED}${BOLD}${RD}Configuración avanzada${CL}"
    advanced_settings
  fi
}

function start_script() {
  if whiptail --backtitle "Estudio76co - Proxmox Scripts" --title "CONFIGURACIÓN" \
    --yesno "¿Usar configuración por defecto?" --no-button Advanced 10 58; then
    header_info
    echo -e "${DEFAULT}${BOLD}${BL}Usando configuración por defecto${CL}"
    default_settings
  else
    header_info
    echo -e "${ADVANCED}${BOLD}${RD}Usando configuración avanzada${CL}"
    advanced_settings
  fi
}

check_root
arch_check
pve_check
ssh_check
start_script

# ─── STORAGE ─────────────────────────────────────────────────
msg_info "Validando Storage"
while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  ITEM="  Type: $TYPE Free: $FREE "
  OFFSET=2
  if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
    MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
  fi
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')

VALID=$(pvesm status -content images | awk 'NR>1')
if [ -z "$VALID" ]; then
  msg_error "No se detectó storage válido."
  exit
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
  STORAGE=${STORAGE_MENU[0]}
else
  while [ -z "${STORAGE:+x}" ]; do
    STORAGE=$(whiptail --backtitle "Estudio76co - Proxmox Scripts" --title "Storage Pools" --radiolist \
      "¿Qué storage usar para ${HN}?\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3)
  done
fi
msg_ok "Storage: ${CL}${BL}$STORAGE${CL}"
msg_ok "VM ID: ${CL}${BL}$VMID${CL}"

# ─── DESCARGAR CLOUD IMAGE DE UBUNTU 26.04 ───────────────────
# URL oficial de Ubuntu — única conexión externa del script
IMAGE_BASE_URL="https://cloud-images.ubuntu.com/releases/26.04/release"
IMAGE_FILE="ubuntu-26.04-server-cloudimg-amd64.img"
URL="${IMAGE_BASE_URL}/${IMAGE_FILE}"
CHECKSUM_URL="${IMAGE_BASE_URL}/SHA256SUMS"

msg_info "Descargando Ubuntu 26.04 LTS Cloud Image"
sleep 2
msg_ok "${CL}${BL}${URL}${CL}"
curl -f#SL -o "${IMAGE_FILE}" "$URL"
echo -en "\e[1A\e[0K"
msg_ok "Descargado: ${CL}${BL}${IMAGE_FILE}${CL}"

# ─── VERIFICAR INTEGRIDAD (SHA256) ───────────────────────────
# NUEVO: verifica que la imagen no esté corrompida ni manipulada
msg_info "Verificando integridad SHA256 de la imagen"
curl -fsSL "$CHECKSUM_URL" -o SHA256SUMS
if grep -q "${IMAGE_FILE}" SHA256SUMS; then
  grep "${IMAGE_FILE}" SHA256SUMS | sha256sum --check --status
  msg_ok "Integridad verificada correctamente"
else
  msg_error "No se encontró el checksum para ${IMAGE_FILE}. El archivo puede ser incorrecto."
  exit 1
fi
FILE="$IMAGE_FILE"

# ─── TIPO DE STORAGE ─────────────────────────────────────────
STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
case $STORAGE_TYPE in
  nfs | dir | cifs)
    DISK_EXT=".qcow2"; DISK_REF="$VMID/"; DISK_IMPORT="-format qcow2"; THIN="";;
  btrfs)
    DISK_EXT=".raw"; DISK_REF="$VMID/"; DISK_IMPORT="-format raw"; FORMAT=",efitype=4m"; THIN="";;
  *)
    DISK_EXT=""; DISK_REF=""; DISK_IMPORT="-format raw";;
esac

for i in {0,1}; do
  disk="DISK$i"
  eval DISK${i}=vm-${VMID}-disk-${i}${DISK_EXT:-}
  eval DISK${i}_REF=${STORAGE}:${DISK_REF:-}${!disk}
done

# ─── CREAR VM ────────────────────────────────────────────────
msg_info "Creando Ubuntu 26.04 LTS VM"
qm create $VMID \
  -agent 1${MACHINE} \
  -tablet 0 \
  -localtime 1 \
  -bios ovmf${CPU_TYPE} \
  -cores $CORE_COUNT \
  -memory $RAM_SIZE \
  -name $HN \
  -tags estudio76co \
  -net0 virtio,bridge=$BRG,macaddr=$MAC$VLAN$MTU \
  -onboot 1 \
  -ostype l26 \
  -scsihw virtio-scsi-pci

pvesm alloc $STORAGE $VMID $DISK0 4M 1>&/dev/null
qm importdisk $VMID ${FILE} $STORAGE ${DISK_IMPORT:-} 1>&/dev/null
qm set $VMID \
  -efidisk0 ${DISK0_REF}${FORMAT} \
  -scsi0 ${DISK1_REF},${DISK_CACHE}${THIN}size=${DISK_SIZE} \
  -ide2 ${STORAGE}:cloudinit \
  -boot order=scsi0 \
  -serial0 socket >/dev/null

# ─── DESCRIPCIÓN ─────────────────────────────────────────────
DESCRIPTION=$(cat <<EOF
<div align='center'>
  <h2>Ubuntu 26.04 LTS - Resolute Raccoon</h2>
  <p>VM creada por Estudio76co</p>
  <p><a href='https://github.com/estudio76/pmx-vm-ubuntu-26-04-lts'>github.com/estudio76/pmx-vm-ubuntu-26-04-lts</a></p>
</div>
EOF
)
qm set $VMID -description "$DESCRIPTION" >/dev/null

# ─── RESIZE DISCO ────────────────────────────────────────────
msg_info "Redimensionando disco a $DISK_SIZE"
qm resize $VMID scsi0 ${DISK_SIZE} >/dev/null

msg_ok "VM Ubuntu 26.04 LTS creada: ${CL}${BL}(${HN})${CL}"

# ─── INICIAR VM ──────────────────────────────────────────────
if [ "$START_VM" == "yes" ]; then
  msg_info "Iniciando Ubuntu 26.04 VM"
  qm start $VMID
  msg_ok "VM iniciada"
fi

msg_ok "¡Completado exitosamente!\n"
echo -e "${YW}⚠️  Configura Cloud-Init antes de usar la VM${CL}"
echo -e "${INFO}${BL}https://github.com/estudio76/pmx-vm-ubuntu-26-04-lts${CL}\n"
