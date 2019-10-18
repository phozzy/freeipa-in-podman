# main.tf

# Define terraform backend
terraform {
  required_version = "~> 0.12.0"
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "TheHyve"
    workspaces {
      name = "ipacont8"
    }
  }
}

# Definition of variables
variable "hcloud_token" {
  type = string
  description = "Use -var='hcloud_token=...' CLI option"
}
variable "hetzner_dns" {
  type = list(string)
  description = "Dns servers proposed by Hetzner infrastructure"
  default = [
    "213.133.98.98",
    "213.133.99.99",
    "213.133.100.100",
  ]
}
variable "server" {
  description = "The mapping of servername to server Data Center"
  type = "map"
  default = {
    "etc00" = "nbg1"
    "etc01" = "fsn1"
    "etc10" = "hel1"
  }
}
variable "server_type" {
  type = string
  description = "defines resources for provisioned server"
  default = "cx31-ceph"
}
variable "ssh_key_private" {
  type = string
  description = "Ssh private key to use for connection to a server. Export TF_VAR_ssh_key_private environment variable to define a value."
}
variable "ssh_key" {
  type = string
  description = "An id of public key of ssh key-pairs that will be used for connection to a server. Export TF_VAR_ssh_key environment variable to define a value."
}
variable "remote_user" {
  type = string
  description = "A user being used for a connection to a server. By default is root, unless redefined with user-data (cloud-init)."
  default = "root"
}
variable "server_image" {
  type = string
  description = "An image being used for a server provisioning."
  default = "centos-8"
}
variable "domain" {
  type = string
  description = "A domain name for FreeIPA server. Export TF_VAR_domain environment variable to define."
}

# User Hetzner cloud
provider "hcloud" {
  token = "${var.hcloud_token}"
}

# Get data from Hetzner Cloud
data "hcloud_floating_ip" "fip" {
  for_each = var.server
  with_selector = "host==${each.key}"
}
data "hcloud_volume" "vol" {
  for_each = var.server
  with_selector = "host==${each.key}"
}

# Create resources
resource "hcloud_server" "host" {
  for_each = var.server
  name = each.key
  location = each.value
  server_type = "${var.server_type}"
  keep_disk = true
  backups = true
  image = "${var.server_image}"
  ssh_keys = [
    "${var.ssh_key}",
  ]
  provisioner "remote-exec" {
    inline = [
      "dnf install -y python3 python3-libselinux"
    ]
    connection {
      host = "${self.ipv4_address}"
      type = "ssh"
      user = "${var.remote_user}"
      private_key = "${file("${var.ssh_key_private}")}"
    }
  }
}

# Assign floating IP
resource "hcloud_floating_ip_assignment" "fip_ass" {
  for_each = var.server
  floating_ip_id = "${data.hcloud_floating_ip.fip[each.key].id}"
  server_id = "${hcloud_server.host[each.key].id}"
}
# Attach volume
resource "hcloud_volume_attachment" "vol_att" {
  for_each = var.server
  volume_id = "${data.hcloud_volume.vol[each.key].id}"
  server_id = "${hcloud_server.host[each.key].id}"
}

# Create an inventory file from template
resource "null_resource" "inventory" {
  depends_on = [ hcloud_floating_ip_assignment.fip_ass ]
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    cluster_instance_ids = "${join(",", [ for k, v in var.server: hcloud_server.host[k].id ])}"
  }
  provisioner "local-exec" {
    command = "echo '${templatefile("inventory.template", { hosts = "${hcloud_server.host}", domain = "${var.domain}", user = "${var.remote_user}", forwarders = "${var.hetzner_dns}" })}' > inventory.yml"
  }
}
