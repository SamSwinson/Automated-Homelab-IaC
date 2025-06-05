# Fedora Server Baseline
# ---
# Packer Template to create an Fedora Server Baseline on Proxmox

# Variable Definitions - These need to match the names within the variables file created earlier
variable "proxmox_api_url" {}
variable "node" {}
variable "memory" {}
variable "vm_id" {}
variable "vm_name" {}
variable "template_description" {}
variable "disk_size" {}
variable "cores" {}
variable "ssh_username" {}

# Get Secrets from HashiCorp Vault
locals {
    proxmox_api_token_id = vault("/secret/proxmox", "api_token_id") #The format is "/path/to/secret/vault", "secret name"
    proxmox_api_token_secret = vault("/secret/proxmox", "api_token_secret")
    initial_ssh_password = vault("/secret/fedora_server_default", "initial_ssh_password")
    default_admin_password = vault("/secret/fedora_server_default", "default_admin_password")
    default_root_password = vault("/secret/fedora_server_default", "default_root_password")
}

# Resource Definition for the VM Template
source "proxmox-iso" "fedora-server-baseline-template" {

  # Proxmox Connection Settings
  proxmox_url              = var.proxmox_api_url
  username                 = local.proxmox_api_token_id
  token                    = local.proxmox_api_token_secret
  insecure_skip_tls_verify = true 

  # VM General Settings
  node                 = var.node
  vm_id                = var.vm_id
  vm_name              = var.vm_name
  template_description = var.template_description

  # VM OS Settings
  boot_iso {
      type = "scsi"
      iso_file = "local:iso/Fedora-Server-dvd-x86_64-42_Beta-1.4.iso" #This is the filename of the ISO to use, this ISO needs to already be present on the Promxox server, alternatively you could tell packer to fetch a specific ISO over HTTPS each time it runs
      unmount = true
      iso_checksum = "sha256:a1a6791c606c0d2054a27cec5a9367c02a32b034284d2351e657c3a7f4f489e7" #Exact hash of the ISO image
    }

  # VM System Settings
  qemu_agent = true #This is how Packer is going to be able to fetch the new VMs network details from Proxmox

  # VM Hard Disk Settings
  scsi_controller = "virtio-scsi-pci"

  disks {
    disk_size         = var.disk_size
    storage_pool      = "local-lvm"            # LVM storage pool name
    type              = "scsi"
  }

  # VM CPU Settings
  cores = var.cores

  # VM Memory Settings
  memory = var.memory

  # VM Network Settings
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = "false"
  }

  # VM Cloud-Init Settings
  cloud_init              = false # In my configuration I am not using Cloud Init to deploy my Fedora Servers
  #cloud_init_storage_pool = "local-lvm"          # LVM storage pool name

  # PACKER Boot Commands
  boot_command = [
    "<up><wait>",
    "e<wait>",
    "<down><down><end>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
    "<f10>"
  ]
  boot      = "c"
  boot_wait = "5s"

  # PACKER Autoinstall Settings
  http_directory    = "http"
  http_bind_address = "192.168.1.31" #This needs to be the address of your Packer server where the HTTP kickstart file is hosted
  http_port_min     = 8535 #This port needs to be allowed through the Packer server firewall
  http_port_max     = 8535

  # PACKER SSH Settings
  ssh_username = var.ssh_username
  ssh_password = local.initial_ssh_password

  # Raise the timeout, when installation takes longer
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 1000

}

# Build Definition to create the VM Template
build {

  name    = "fedora-server-baseline-template"
  sources = ["source.proxmox-iso.fedora-server-baseline-template"]

  # Provisioning Commands
  provisioner "shell" {
    inline = [
      # Update system packages
      "dnf update -y",

      

      # Change root password
      "echo 'root:${local.default_root_password}' | chpasswd",

    # Change admin password (replace 'admin' with your actual admin username)
    "echo 'Admin:${local.default_admin_password}' | chpasswd",

    # Disable Root SSH Login
    "sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config",
    "systemctl reload sshd"
    ]
  }
}
