terraform {
  source = "./modules//nixos-via-infection"
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "libvirt" {
  uri = "qemu:///system"
}

provider "cloudinit" {}
EOF
}

inputs = {
  hostname          = "nixos-server-1"
  domain_name       = "nixos"
  memory_mb         = 2
  cpu               = 2
  libvirt_disk_path = "/tmp/terraform-provider-libvirt-pool-nixos"
  qcow_path         = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  ssh_key           = "<public key>"
}
