resource "libvirt_pool" "nixos" {
  name = "nixos"
  type = "dir"
  path = var.libvirt_disk_path
}

resource "libvirt_volume" "ubuntu_qcow2" {
  name   = "ubuntu-qcow2"
  pool   = libvirt_pool.nixos.name
  source = var.img_url
  format = "qcow2"
}

data "cloudinit_config" "user_data" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    filename     = "nixos-infect.yaml"
    content = sensitive(<<-EOT
      #cloud-config
      package_update: true

      packages:
        - apt-transport-https
        - ca-certificates
        - curl
        - gnupg-agent
        - software-properties-common

      users:
        - name: temp
          groups: users, admin
          sudo: ALL=(ALL) NOPASSWD:ALL
          shell: /bin/bash
          lock_passwd: true
          ssh-authorized-keys:
            - ${var.ssh_key}

      write_files:
      - path: /etc/nixos/host.nix
        permissions: '0644'
        content: |
          {pkgs, config, lib}:
          {
            nix = {
              extraOptions = ''
                experimental-features = nix-command flakes
              '';
            
              gc = {
                automatic = true;
                dates = "03:15";
                options = "--delete-older-than 8d";
              };
          };

          # Firewall
            networking.firewall = {
              enable = true;
              rejectPackets = true;
              allowPing = true;
              allowedTCPPorts = [ 
                22
                443
                80
              ];
            };

            # Better performance
            boot.kernelModules = [ "tcp_bbr" ];
            boot.kernel.sysctl = {
              "net.ipv4.tcp_min_snd_mss" = 536;
              "net.ipv4.tcp_congestion_control" = "bbr";
            };

            # Docker 
            virtualisation.docker.enable = true;

            # Services
            services.openssh = {
              enable = true;
              permitRootLogin = "prohibit-password";
              extraConfig = "AcceptEnv LANG LC_*";
            };

            services.fstrim = {
              enable = true;
            };
            
            services.logrotate.enable = true;
            services.consul.enable = true;
            # Packages
            environment.systemPackages = with pkgs;
              [
                htop
                ncdu
                vim
                curl
              ];

            # No X11. This could be done with `environment.noXlibs = true;', but
            # that would require recompiling too many stuff.
            security.pam.services.su.forwardXAuth = lib.mkForce false;
            fonts.fontconfig.enable = false;

            # Users
            users = {
              mutableUsers = false;
              users.root.openssh.authorizedKeys.keys = [ ${var.ssh_key} ];
              users.duncan = {
                isNormalUser = true;
                home = "/home/duncan";
                description = "duncan idaho";
                extraGroups = [ 
                  "docker"
                  "wheel"
                ];
                openssh.authorizedKeys.keys = [ ${var.ssh_key} ];
              };
            };
            security.sudo.wheelNeedsPassword = false;
          }

      runcmd:
        - curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIXOS_IMPORT=./host.nix NIX_CHANNEL=nixos-22.05 bash 2>&1 | tee /tmp/infect.log
EOT
    )
  }
}

data "template_file" "network_config" {
  template = file("${path.module}/network_config.cfg")
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "commoninit.iso"
  user_data      = data.cloudinit_config.user_data.rendered
  network_config = data.template_file.network_config.rendered
  pool           = libvirt_pool.nixos.name
}

# Create the machine
resource "libvirt_domain" "nixos_server" {
  name   = "nixos-server"
  memory = var.memory_mb * 1024
  vcpu   = var.cpu

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name   = var.network
    wait_for_lease = true
    hostname       = var.hostname
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.ubuntu_qcow2.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
