terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "0.7.1"
    }
  }
}

provider "libvirt" {
   uri = "qemu+ssh://root@150.165.83.92/system" #destino da vm
}


# RESOURCES

resource "libvirt_pool" "p-ubuntu" {
  name = "${var.POOL_NAME}"
  type = "dir"
  path = "/home/igor.oliveira/volumes_kvm"
}

resource "libvirt_volume" "ubuntu-qcow2" {
  count  = length(var.vms)
  name   = "${var.VOL_NAME}_${count.index}"
  pool   = libvirt_pool.p-ubuntu.name
  source = "https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_volume" "ubuntu-qcow2-resized" {
  count          = length(var.vms)
  name           = "${var.VOL_NAME}_${count.index}-resized.qcow2"
  pool           = libvirt_pool.p-ubuntu.name
  base_volume_id = libvirt_volume.ubuntu-qcow2[count.index].id
  size           = var.disk
  
}


data "template_file" "user_data" {
  template = "${file("${path.module}/cloud_init.cfg")}"
}


resource "libvirt_cloudinit_disk" "cloud_init" {
  count     = length(var.vms) 
  name      = "commoninit_${count.index}.iso"
  pool      = libvirt_pool.p-ubuntu.name
  user_data = "${data.template_file.user_data.rendered}"
}

resource "libvirt_domain" "ubuntu" {
  count  = length(var.vms)
  name   = "${var.vms[count.index]}"
  memory = "${var.MEMORY_SIZE}"
  vcpu   = "${var.VCPU_SIZE}"

  network_interface {
    network_name = "default"
    hostname = "${var.vms[count.index]}"
  }

  disk {
    volume_id = libvirt_volume.ubuntu-qcow2-resized[count.index].id
  }

  cloudinit = "${libvirt_cloudinit_disk.cloud_init[count.index].id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }
}



