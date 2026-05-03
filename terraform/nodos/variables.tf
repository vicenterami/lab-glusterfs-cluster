variable "vm_count" {
  description = "Número de máquinas virtuales a crear"
  type        = number
  default     = 3
}

variable "hostname_base" {
  default = "nodo"
  description = "Nombre del servidor OpenNebula 1"
}

variable "domain" {
  default = "midominio.org"
}

variable "ip_type" {
  default = "dhcp"
}

variable "memoryMB" {
  default = 1024*8
}

variable "cpu" {
  default = 1
}

variable "diskSize" {
  default = 20
}

variable "path_to_image" {
  default = "/home/amellado/vmstore/images"
}

variable "network_configs" {
  default = {
    0 = "network_config1.cfg"
    1 = "network_config2.cfg"
    2 = "network_config3.cfg"
  }
}

