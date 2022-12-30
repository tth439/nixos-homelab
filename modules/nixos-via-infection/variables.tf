variable "hostname" {
  type    = string
  default = "node"
}

variable "ip_type" {
  type    = string
  default = "dhcp"
}

variable "memory_mb" {
  type    = number
  default = 1
}

variable "cpu" {
  type    = number
  default = 1
}

variable "network" {
  type    = string
  default = "default"
}

variable "img_url" {
  type = string
}

variable "libvirt_disk_path" {
  type = string
}

variable "ssh_key" {
  type = string
}
