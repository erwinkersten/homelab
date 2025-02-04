resource "proxmox_virtual_environment_vm" "this" {
  for_each = var.nodes

  node_name = each.value.host_node

  name        = each.key
  description = each.value.machine_type == "controlplane" ? "Talos Linux for Kubernetes - Control Plane" : "Talos Linux for Kubernetes - Worker"
  tags        = each.value.machine_type == "controlplane" ? ["${each.value.ip}", "k8s", "control-plane"] : ["${each.value.ip}", "k8s", "worker", ]
  on_boot     = true
  vm_id       = each.value.vm_id

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  bios          = "seabios"

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated = each.value.ram_dedicated
  }

  network_device {
    bridge      = "vmbr1"
  }

  disk {
    datastore_id = each.value.datastore_id
    interface    = "scsi0"
    iothread     = true
    cache        = "writethrough"
    discard      = "on"
    ssd          = true
    file_format  = "raw"
    size         = 20
    file_id      = proxmox_virtual_environment_download_file.this.id
  }
  
  boot_order = ["scsi0"]

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 6.X.
  }

  initialization {
    datastore_id = each.value.datastore_id
    ip_config {
      ipv4 {
        address = "${each.value.ip}/${each.value.cidr}"
        gateway = "${each.value.gateway}"
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }
}