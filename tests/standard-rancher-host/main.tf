###
# Datasources
#
data "pass_password" "puppet_autosign_psk" {
  path = "terraform/c2c_mgmtsrv/puppet_autosign_psk"
}

data "pass_password" "ssh_key" {
  path = "terraform/ssh/terraform"
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

resource "openstack_networking_secgroup_v2" "test_standard_rancher_host" {
  name        = "test_standard_rancher_host"
  description = "Terraform instance testing"
  region      = "SBG5"
}

resource "openstack_networking_secgroup_rule_v2" "allow_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.test_standard_rancher_host.id
  region            = "SBG5"
}

resource "openstack_networking_network_v2" "standard_rancher_host" {
  name           = "test-standard-rancher-host"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "standard_rancher_host" {
  name       = "test-standard-rancher-host"
  network_id = openstack_networking_network_v2.standard_rancher_host.id
  cidr       = "10.10.10.0/24"
  ip_version = 4
}

module "instance" {
  source = "../../"

  key_pair = "terraform"
  domain   = "local"

  security_groups = [
    data.openstack_networking_secgroup_v2.default.id,
    openstack_networking_secgroup_v2.test_standard_rancher_host.id,
  ]

  flavor_name          = "s1-2"
  image_name           = "Debian 9"
  primary_network_id   = "581fad02-158d-4dc6-81f0-c1ec2794bbec" # Ext-Net
  secondary_network_id = openstack_networking_network_v2.standard_rancher_host.id

  tags = {
    test = "terraform-instance-openstack testing standard-rancher-host"
  }

  puppet = {
    autosign_psk      = data.pass_password.puppet_autosign_psk.data["puppet_autosign_psk"]
    server_address    = "puppet.camptocamp.com"
    ca_server_address = "puppetca.camptocamp.com"
    role              = "base"
    environment       = "staging4"
  }

  rancher = {
    environment_id = "1a5"
    host_labels = {
      foo = "bar"
      bar = "baz"
    }
  }

  connection = {
    private_key = data.pass_password.ssh_key.data["id_rsa"]
  }
}

###
# Acceptance test
#
resource "null_resource" "acceptance" {
  depends_on = [module.instance]
  count      = var.instance_count

  connection {
    host        = module.instance.this_instance_public_ipv4[count.index]
    type        = "ssh"
    user        = "terraform"
    private_key = data.pass_password.ssh_key.data["id_rsa"]
  }

  provisioner "file" {
    source      = "script.sh"
    destination = "/tmp/script.sh"
  }

  provisioner "file" {
    source      = "goss.yaml"
    destination = "/home/terraform/goss.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "sudo /tmp/script.sh",
    ]
  }
}
