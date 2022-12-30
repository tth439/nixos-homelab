output "dhcp_ip" {
  value = libvirt_domain.nixos_server.network_interface.0.addresses
}
