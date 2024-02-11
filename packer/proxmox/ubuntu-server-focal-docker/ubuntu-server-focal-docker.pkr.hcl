packer {
  required_plugins {
    name = {
      #version = "~> 1"
      version =  "v1.1.7"
      #version = "v1.0.6"
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

variable "proxmox_node" {
    type = string
    default = "promox"
}

#source "proxmox-iso" "ubuntu-server-focal-docker" {
source "proxmox-iso" "ubuntu-server" {
    proxmox_url = "${var.proxmox_api_url}"
    username = "${var.proxmox_api_token_id}"
    token = "${var.proxmox_api_token_secret}"
    insecure_skip_tls_verify = true
    #vm_id = "125"
    vm_name = "ubuntu-server"
    template_name = "ubuntu-docker-tmpl"
    template_description = "Ubuntu Server Focal Image with Docker pre-installed"
    # iso_file = "local:iso/ubuntu-22.04.3-live-server-amd64.iso"
    iso_file = "local:iso/ubuntu-20.04.6-live-server-amd64.iso"
    # iso_url = "https://releases.ubuntu.com/focal/ubuntu-20.04.6-live-server-amd64.iso"
    iso_checksum = "b8f31413336b9393ad5d8ef0282717b2ab19f007df2e9ed5196c13d8f9153c8b"
    # iso_file = "local:iso/ubuntu-22.04.3-desktop-amd64.iso"
    iso_storage_pool = "local"
    node = "${var.proxmox_node}"
    unmount_iso = true
    qemu_agent = true
    scsi_controller = "virtio-scsi-pci"
    #scsi_controller = "virtio-scsi-single"
    cores = "1"
    memory = "2048" 
    cloud_init = true
    cloud_init_storage_pool = "local-lvm"

    # For Older Versions
    boot_command = [
        "<esc><wait><esc><wait>",
        "<f6><wait><esc><wait>",
        "<bs><bs><bs><bs><bs>",
        #"ip=${cidrhost("192.168.1.0/24", 190)}::${cidrhost("192.168.1.0/24", 1)}:${cidrnetmask("192.168.1.0/24")}::::${cidrhost("192.168.1.0/24", 1)} ",
        #"ip=192.168.1.190::192.168.1.1:255.255.255.0:ubuntu-server",
        #"ip=dhcp",
        #"nameserver=192.168.1.1",
        "autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ",
        #"autoinstall ds=nocloud-net;s=http://0.0.0.0:8082/ ",
        "--- <enter>"
    ]

    // boot_command = ["<enter><enter><f6><esc><wait> ", "autoinstall ds=nocloud-net;seedfrom=http://{{ .HTTPIP }}:{{ .HTTPPort }}/", "<enter><wait>"]
    boot = "c"
    # order = "virtio0;ide2;net0"

    // boot_command = [
    //     "c",
    //     "linux /casper/vmlinuz -- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'", 
    //     "<enter><wait><wait>", 
    //     "initrd /casper/initrd", 
    //     "<enter><wait><wait>", 
    //     "boot<enter>"
    //     ]

    boot_wait = "5s"
    http_directory = "http"
    # (Optional) Bind IP Address and Port
    // http_bind_address = "0.0.0.0"
    // http_port_min = 8802
    // http_port_max = 8802
    ssh_username = "chad"
    ssh_password = "chad"
    #ssh_private_key_file = "~/.ssh/id_rsa"
    ssh_timeout = "20m"

    disks {
        disk_size = "20G"
        // format = "qcow2"
        format = "raw"
        storage_pool = "local"
        #type = "virtio"
        type="scsi"
    }

    network_adapters {
        model = "virtio"
        bridge = "vmbr0"
        #firewall = "false"
        #vlan_tag = "5"
    } 
}

build {
    name = "ubuntu-server"
    sources = ["source.proxmox-iso.ubuntu-server"]

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
            "systemctl start qemu-guest-agent",
            "systemctl enable qemu-guest-agent",
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
    
    // post-processor "shell-local" {
    //     command = "curl -k -X POST -H 'Authorization: PVEAPIToken=${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}' --data-urlencode delete=ide2 ${var.proxmox_api_url}/nodes/${var.proxmox_node}/qemu/ubuntu-server/config"
    // }

}
