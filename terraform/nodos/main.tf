resource "libvirt_volume" "os_image" {
  count  = var.vm_count
  name   = "${var.hostname_base}${count.index+1}-os_image"  # Incluye el índice
  pool   = "pool"
  source = "${var.path_to_image}/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "null_resource" "resize_volume" {
  count = var.vm_count
  provisioner "local-exec" {
    command = "sudo qemu-img resize ${libvirt_volume.os_image[count.index].id} ${var.diskSize}G"
  }
  depends_on = [libvirt_volume.os_image]
}

#--- CLOUD INIT CONFIGURATION ---

# Configuración por instancia
data "template_file" "user_data" {
  count    = var.vm_count
  template = file("${path.module}/config/cloud_init.cfg")
  vars = {
    hostname   = "${var.hostname_base}${count.index+1}"  # Nombre único por VM
    fqdn       = "${var.hostname_base}${count.index+1}.${var.domain}"
    public_key = file("~/.ssh/id_ed25519.pub")
  }
}

data "template_cloudinit_config" "config" {
  count         = var.vm_count
  gzip          = false
  base64_encode = false
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.user_data[count.index].rendered
  }
}

data "template_file" "network_config" {
  count    = var.vm_count
  template = file("${path.module}/config/network_config${count.index+1}.cfg")
}

# Cloudinit disk por cada VM
resource "libvirt_cloudinit_disk" "commoninit" {
  count          = var.vm_count
  name           = "${var.hostname_base}${count.index+1}-commoninit.iso"
  pool           = "pool"
  user_data      = data.template_cloudinit_config.config[count.index].rendered
  network_config = data.template_file.network_config[count.index].rendered
}

#--- DISCOS ADICIONALES ---

resource "libvirt_volume" "ceph_disk1" {
  count  = var.vm_count
  name   = "${var.hostname_base}${count.index+1}-ceph-disk1"
  pool   = "pool"
  format = "qcow2"
  size   = 1024*1024*1024*30
}

resource "libvirt_volume" "ceph_disk2" {
  count  = var.vm_count
  name   = "${var.hostname_base}${count.index+1}-ceph-disk2"
  pool   = "pool"
  format = "qcow2"
  size   = 1024*1024*1024*30
}

#--- DEFINICIÓN DE LAS VMs ---

resource "libvirt_domain" "domain-nodos" {
  count  = var.vm_count
  name   = "${var.hostname_base}${count.index+1}"
  memory = var.memoryMB
  vcpu   = var.cpu

  disk {
    volume_id = libvirt_volume.os_image[count.index].id
  }

  disk {
    volume_id = libvirt_volume.ceph_disk1[count.index].id
  }

  disk {
    volume_id = libvirt_volume.ceph_disk2[count.index].id
  }

  network_interface {
    network_name = "default"
  }

  network_interface {
    network_name = "netstack"
  }

  cloudinit = libvirt_cloudinit_disk.commoninit[count.index].id

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  cpu {
    mode = "host-passthrough"  
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = "true"
  }
}
