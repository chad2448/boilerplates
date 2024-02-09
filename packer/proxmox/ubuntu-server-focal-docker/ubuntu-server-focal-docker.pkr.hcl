packer {
  required_plugins {
    name = {
      #version = "~> 1"
      version = "v1.1.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_api_url" {
    type = string
}

variable "proxmox_api_token_id" {
    type = string
}

variable "proxmox_api_token_secret" {
    type = string
    sensitive = true
}

variable "proxmox_password" {
    type = string
    sensitive = true
}

variable "proxmox_username" {
    type = string
}

#source "proxmox-iso" "ubuntu-server-focal-docker" {
source "proxmox-iso" "ubuntu-server-focal-docker" {
    proxmox_url = "${var.proxmox_api_url}"
    // username = "${var.proxmox_api_token_id}"
    // token = "${var.proxmox_api_token_secret}"
    username = "${var.proxmox_username}"
    password = "${var.proxmox_password}"
    insecure_skip_tls_verify = true
    #pool = ""
    vm_id = "125"
    vm_name = "ubuntu-server-focal-docker"
    template_name = "ubuntu-focal-docker"
    template_description = "Ubuntu Server Focal Image with Docker pre-installed"
    iso_url = "https://releases.ubuntu.com/focal/ubuntu-20.04.6-live-server-amd64.iso"
    iso_checksum = "b8f31413336b9393ad5d8ef0282717b2ab19f007df2e9ed5196c13d8f9153c8b"
    iso_storage_pool = "local"
    node = "proxmox"
    unmount_iso = true
    qemu_agent = true
    scsi_controller = "virtio-scsi-pci"
    cores = "1"
    memory = "2048" 
    cloud_init = true
    cloud_init_storage_pool = "local"
    boot_command = [
        "<esc><wait><esc><wait>",
        "<f6><wait><esc><wait>",
        "<bs><bs><bs><bs><bs>",
        "autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ",
        "--- <enter>"
    ]
    boot = "c"
    boot_wait = "5s"
    http_directory = "http" 
    # (Optional) Bind IP Address and Port
    #http_bind_address = "0.0.0.0"
    #http_port_min = 8802
    #http_port_max = 8802
    ssh_username = "chad"
    #ssh_password = "chad"
    ssh_private_key_file = "~/.ssh/id_rsa"
    ssh_timeout = "20m"

    disks {
        disk_size = "20G"
        format = "qcow2"
        storage_pool = "local-lvm"
        storage_pool_type = "lvm"
        type = "virtio"
    }

    network_adapters {
        model = "virtio"
        bridge = "vmbr0"
        firewall = "false"
        vlan_tag = "5"
    } 
}

build {
    name = "ubuntu-server-focal-docker"
    sources = ["source.proxmox-iso.ubuntu-server-focal-docker"]

    provisioner "shell" {
        inline = [
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo apt -y autoremove --purge",
            "sudo apt -y clean",
            "sudo apt -y autoclean",
            "sudo cloud-init clean",
            "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
            "sudo sync"
        ]
    }

    provisioner "file" {
        source = "files/99-pve.cfg"
        destination = "/tmp/99-pve.cfg"
    }

    provisioner "shell" {
        inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
    }

    provisioner "shell" {
        inline = [
            "sudo apt-get install -y ca-certificates curl gnupg lsb-release",
            "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
            "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
            "sudo apt-get -y update",
            "sudo apt-get install -y docker-ce docker-ce-cli containerd.io"
        ]
    }
}
