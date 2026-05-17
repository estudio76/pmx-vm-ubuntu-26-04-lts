# pmx-vm-ubuntu-26-04-lts
script para cear máquina virtuales en proxmox con ubuntu-26.04 LTS inspirado en los scripts de [helperscripts](https://github.com/community-scripts/ProxmoxVE/blob/main/vm/ubuntu2204-vm.sh) Proxmox-ve scripts

## Instalación

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/estudio76/pmx-vm-ubuntu-26-04-lts/main/pmx-vm-ubuntu-26-04-lts.sh)"
```
<br />

## Pasos obligatorios antes de usar la VM

### 1. Configura Cloud-Init
Desde la interfaz web de Proxmox, selecciona la VM → pestaña **Cloud-Init**:
- **User** → el usuario que quieras (ej. `ubuntu`)
- **Password** → tu contraseña
- **IP Config** → DHCP o IP estática
- Haz clic en **Regenerate Image**

O por línea de comandos:
```bash
qm set <VMID> --ciuser ubuntu --cipassword TuPassword
qm set <VMID> --ipconfig0 ip=dhcp
qm cloudinit update <VMID>
```

### 2. Instala QEMU Guest Agent
Una vez que la VM esté corriendo, conéctate y ejecuta:
```bash
sudo apt update && sudo apt install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
```

Esto permite a Proxmox ver la IP de la VM, hacer snapshots consistentes y apagarla limpiamente.
