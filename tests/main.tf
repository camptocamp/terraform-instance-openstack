###
# Variables
#
variable "key_pair" {}

###
# Datasources
#
data "pass_password" "puppet_autosign_psk" {
  path = "terraform/c2c_mgmtsrv/puppet_autosign_psk"
}

###
# Code to test
#
variable "instance_count" {
  default = 1
}

data "openstack_networking_secgroup_v2" "default" {
  name = "default"
}

resource "openstack_networking_secgroup_rule_v2" "allow_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.allow_ssh.id
  region            = "SBG5"
}

resource "openstack_networking_secgroup_v2" "allow_ssh" {
  name        = "allow_ssh"
  description = "Security Group to allow access to SSH"
  region      = "SBG5"
}

module "single_network_instance" {
  source = "../"

  key_pair = var.key_pair
  domain   = "local"

  security_groups = [
    data.openstack_networking_secgroup_v2.default.id,
    openstack_networking_secgroup_v2.allow_ssh.id,
  ]

  flavor_name        = "s1-2"
  image_name         = "Debian 9"
  primary_network_id = "581fad02-158d-4dc6-81f0-c1ec2794bbec" # Ext-Net

  tags = {
    test = "terraform-instance-openstack testing"
  }

  puppet = {
    autosign_psk      = data.pass_password.puppet_autosign_psk.data["puppet_autosign_psk"]
    server_address    = "puppet.camptocamp.net"
    ca_server_address = "puppetca.camptocamp.net"
    role              = "base"
    environment       = "staging4"
  }
}

module "two_networks_instance" {
  source = "../"

  key_pair = var.key_pair
  domain   = "local"

  security_groups = [
    data.openstack_networking_secgroup_v2.default.id,
    openstack_networking_secgroup_v2.allow_ssh.id,
  ]

  flavor_name          = "s1-2"
  image_name           = "Debian 9"
  primary_network_id   = "581fad02-158d-4dc6-81f0-c1ec2794bbec" # Ext-Net
  secondary_network_id = ""                                     # TODO

  tags = {
    test = "terraform-instance-openstack testing"
  }

  puppet = {
    autosign_psk      = data.pass_password.puppet_autosign_psk.data["puppet_autosign_psk"]
    server_address    = "puppet.camptocamp.net"
    ca_server_address = "puppetca.camptocamp.net"
    role              = "base"
    environment       = "staging4"
  }
}

module "two_networks_with_secondary_public_instance" {
  source = "../"

  key_pair = var.key_pair
  domain   = "local"

  security_groups = [
    data.openstack_networking_secgroup_v2.default.id,
    openstack_networking_secgroup_v2.allow_ssh.id,
  ]

  flavor_name          = "s1-2"
  image_name           = "Debian 9"
  primary_network_id   = ""                                     # TODO
  secondary_network_id = "581fad02-158d-4dc6-81f0-c1ec2794bbec" # Ext-Net
  public_interface     = "secondary"

  tags = {
    test = "terraform-instance-openstack testing"
  }

  puppet = {
    autosign_psk      = data.pass_password.puppet_autosign_psk.data["puppet_autosign_psk"]
    server_address    = "puppet.camptocamp.net"
    ca_server_address = "puppetca.camptocamp.net"
    role              = "base"
    environment       = "staging4"
  }
}

###
# Acceptance test
#
resource "null_resource" "single_network_acceptance" {
  depends_on = [module.instance]
  count      = var.instance_count

  connection {
    host = module.single_network_instance.this_instance_public_ipv4[count.index]
    type = "ssh"
    user = "root"
  }

  provisioner "file" {
    source      = "script.sh"
    destination = "/tmp/script.sh"
  }

  provisioner "file" {
    source      = "goss.yaml"
    destination = "/root/goss.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "sudo /tmp/script.sh",
    ]
  }
}

resource "null_resource" "two_networks_acceptance" {
  depends_on = [module.instance]
  count      = var.instance_count

  connection {
    host = module.two_networks_instance.this_instance_public_ipv4[count.index]
    type = "ssh"
    user = "root"
  }

  provisioner "file" {
    source      = "script.sh"
    destination = "/tmp/script.sh"
  }

  provisioner "file" {
    source      = "goss.yaml"
    destination = "/root/goss.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "sudo /tmp/script.sh",
    ]
  }
}

resource "null_resource" "two_networks_with_secondary_public_acceptance" {
  depends_on = [module.instance]
  count      = var.instance_count

  connection {
    host = module.two_networks_with_secondary_public_instance.this_instance_public_ipv4[count.index]
    type = "ssh"
    user = "root"
  }

  provisioner "file" {
    source      = "script.sh"
    destination = "/tmp/script.sh"
  }

  provisioner "file" {
    source      = "goss.yaml"
    destination = "/root/goss.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "sudo /tmp/script.sh",
    ]
  }
}
