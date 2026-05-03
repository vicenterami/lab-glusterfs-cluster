# GlusterFS Lab — Clúster Distribuido en KVM

Laboratorio para desplegar un clúster GlusterFS de 3 nodos sobre máquinas virtuales KVM usando Terraform y Ansible.

## Arquitectura

```text
┌─────────────────────────────────────────────────────────────┐
│                     Host (libvirt/KVM)                      │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   nodo1     │  │   nodo2     │  │   nodo3     │          │
│  │ .101        │  │ .102        │  │ .103        │          │
│  │             │  │             │  │             │          │
│  │ GlusterFS   │  │ GlusterFS   │  │ GlusterFS   │          │
│  │ Brick 1     │  │ Brick 1     │  │ Brick 1     │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│         192.168.122.0/24                                    │
└─────────────────────────────────────────────────────────────┘
```



| Nodo	| IP	            | Rol en el Clúster	| Punto de Montaje    |
|-------|-------------------|-------------------|---------------------|
| nodo1	| 192.168.122.101	| Peer / Brick	    | /mnt/vol_compartido |
| nodo2	| 192.168.122.102	| Peer / Brick	    | /mnt/vol_compartido |
| nodo3	| 192.168.122.103	| Peer / Brick	    | /mnt/vol_compartido |





## Requisitos

- KVM / libvirt instalado y activo (`qemu:///system`)
- Terraform >= 1.0
- Ansible >= 2.12
- Imagen Ubuntu Jammy disponible en libvirt
- Redes `default` y `netstack` configuradas en libvirt

## Estructura del repositorio

```
glusterfs-lab/
├── terraform/nodos/
│   ├── main.tf               # Definición de VMs, discos y redes
│   ├── variables.tf          # Parámetros configurables
│   └── ...                   
├── ansible/
│   ├── inventory.yml         # Inventario de hosts
│   └── deploy_glusterfs.yml  # Playbook de instalación y configuración de GlusterFS
└── reset_ssh_finger.sh       # Limpia y restablece fingerprints SSH
```

## Despliegue

### 1. Crear las máquinas virtuales

```bash
cd terraform/nodos
terraform init
terraform apply -auto-approve
```

Esto crea 3 VMs con:
- 8 GB RAM, 1 vCPU
- Disco OS de 20 GB (`/dev/vda`)

### 2. Limpiar fingerprints SSH

Necesario después de crear (o recrear) las VMs:

```bash
cd ../..
./reset_ssh_finger.sh
```

### 3. Instalar y Configurar GlusterFS

Este playbook instalará el servidor de GlusterFS, creará los bricks físicos, conectará los nodos, generará el volumen replicado y lo montará automáticamente.

```bash
cd ansible
ansible-playbook -i inventory.yml deploy_glusterfs.yml
```


# ==========================================
# 1. PRUEBA DE ESCRITURA Y LECTURA (BÁSICA)
# ==========================================

# Escribir un archivo desde el NODO 1
```bash
ssh vicenterog@192.168.122.101 'echo "Prueba de escritura: El volumen GlusterFS funciona" | sudo tee /mnt/vol_compartido/prueba.txt'
```

# Leer el archivo desde el NODO 2
```bash
ssh vicenterog@192.168.122.102 'cat /mnt/vol_compartido/prueba.txt'
```

# Leer el archivo desde el NODO 3
```bash
ssh vicenterog@192.168.122.103 'cat /mnt/vol_compartido/prueba.txt'
```

# ==========================================
# 2. PRUEBA DE ALTA DISPONIBILIDAD (CAÍDA DE NODO)
# ==========================================

# Apagar el NODO 3 para simular una caída
```bash
ssh vicenterog@192.168.122.103 'sudo poweroff'
```

# Escribir un nuevo archivo desde el NODO 1 (demostrando que el clúster sigue vivo)
```bash
ssh vicenterog@192.168.122.101 'echo "Archivo creado mientras el Nodo 3 estaba apagado." | sudo tee /mnt/vol_compartido/supervivencia.txt'
```

# Leer el archivo desde el NODO 2
```bash
ssh vicenterog@192.168.122.102 'cat /mnt/vol_compartido/supervivencia.txt'
```

# ==========================================
# 3. PRUEBA DE AUTO-HEALING (RECUPERACIÓN)
# ==========================================

# Encender el NODO 3 nuevamente desde tu máquina local
```bash
virsh start nodo3
```

# (Esperar unos 20-30 segundos para que inicie Linux y GlusterFS se sincronice)

# Verificar que el Nodo 3 recuperó automáticamente el archivo que se perdió
```bash
ssh vicenterog@192.168.122.103 'cat /mnt/vol_compartido/supervivencia.txt'
```