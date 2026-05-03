# Ceph Lab — Clúster Distribuido en KVM

Laboratorio para desplegar un clúster Ceph de 3 nodos sobre máquinas virtuales KVM usando Terraform y Ansible.

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                     Host (libvirt/KVM)                      │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   nodo1     │  │   nodo2     │  │   nodo3     │          │
│  │ .101        │  │ .102        │  │ .103        │          │
│  │             │  │             │  │             │          │
│  │ MON / MGR   │  │  OSD x2     │  │  OSD x2     │          │
│  │ OSD x2      │  │             │  │             │          │
│  │ Dashboard   │  │             │  │             │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│         192.168.122.0/24                                    │
└─────────────────────────────────────────────────────────────┘
```

| Nodo  | IP              | Roles              |
|-------|-----------------|--------------------|
| nodo1 | 192.168.122.101 | MON, MGR, OSD, Dashboard |
| nodo2 | 192.168.122.102 | OSD                |
| nodo3 | 192.168.122.103 | OSD                |

**Total OSDs:** 6 (2 discos × 3 nodos — `/dev/vdb` y `/dev/vdc`)

## Requisitos

- KVM / libvirt instalado y activo (`qemu:///system`)
- Terraform >= 1.0
- Ansible >= 2.12
- Imagen Ubuntu Jammy disponible en libvirt
- Redes `default` y `netstack` configuradas en libvirt

## Estructura del repositorio

```
ceph-lab/
├── terraform/nodos/
│   ├── main.tf               # Definición de VMs, discos y redes
│   ├── variables.tf          # Parámetros configurables (RAM, CPU, discos)
│   ├── provider.tf           # Proveedor libvirt
│   ├── terraform.tf          # Versión de providers
│   ├── limpia.sh             # Script de destrucción y limpieza
│   └── config/
│       ├── cloud_init.cfg    # Cloud-init: usuario, paquetes, locale
│       ├── network_config1.cfg  # Netplan nodo1 (192.168.122.101)
│       ├── network_config2.cfg  # Netplan nodo2 (192.168.122.102)
│       └── network_config3.cfg  # Netplan nodo3 (192.168.122.103)
├── ansible/
│   ├── inventory.yml         # Inventario de hosts
│   ├── config_hosts.yml      # Configura /etc/hosts en los nodos
│   ├── config_keys.yml       # Distribución de claves SSH entre nodos
│   ├── deploy_ceph.yml       # Despliegue principal del clúster Ceph
│   └── ceph-dashboard-password.yml  # Configura contraseña del dashboard
└── reset_ssh_finger.sh       # Limpia y restablece fingerprints SSH
```

## Despliegue

### 1. Crear las máquinas virtuales

```bash
cd terraform/nodos
terraform init
terraform apply
```

Esto crea 3 VMs con:
- 8 GB RAM, 1 vCPU
- Disco OS de 20 GB (`/dev/vda`)
- 2 discos adicionales de 30 GB cada uno (`/dev/vdb`, `/dev/vdc`)

### 2. Limpiar fingerprints SSH

Necesario después de crear (o recrear) las VMs:

```bash
./reset_ssh_finger.sh
```

### 3. Configurar los nodos

```bash
cd ansible

# Configurar /etc/hosts en todos los nodos
ansible-playbook -i inventory.yml config_hosts.yml

# Distribuir claves SSH entre nodos (necesario para cephadm)
ansible-playbook -i inventory.yml config_keys.yml
```

### 4. Desplegar Ceph

```bash
ansible-playbook -i inventory.yml deploy_ceph.yml
```

Este playbook:
1. Instala dependencias (`lvm2`, `docker`, `chrony`, etc.)
2. Descarga e instala `cephadm` (release Reef)
3. Hace bootstrap del clúster en `nodo1`
4. Agrega `nodo2` y `nodo3` al orquestador
5. Crea los OSDs a partir de los discos extra

### 5. Configurar el Dashboard

```bash
ansible-playbook -i inventory.yml ceph-dashboard-password.yml
```

Al finalizar muestra la URL del dashboard y las credenciales generadas.

## Configuración (variables Terraform)

Editar `terraform/nodos/variables.tf` para ajustar recursos:

| Variable      | Default | Descripción               |
|---------------|---------|---------------------------|
| `ram`         | 8192    | RAM por nodo (MB)         |
| `vcpu`        | 1       | vCPUs por nodo            |
| `disk_size`   | 20 GB   | Tamaño disco OS           |
| `osd_size`    | 30 GB   | Tamaño discos OSD         |

## Acceso

```bash
# SSH a cualquier nodo
ssh amellado@192.168.122.101   # usuario: amellado / pass: linux

# Dashboard Ceph (desde nodo1)
https://192.168.122.101:8443
```

## Destruir el laboratorio

```bash
cd terraform/nodos
./limpia.sh
```

El script ejecuta `terraform destroy` y limpia archivos de estado residuales.

## Versiones

| Componente | Versión          |
|------------|-----------------|
| Ceph       | Reef (18.x)     |
| Ubuntu     | 22.04 (Jammy)   |
| Terraform  | >= 1.0          |
| libvirt    | dmacvicar/libvirt v0.8.2 |
| cephadm    | Método de despliegue (contenedores) |
