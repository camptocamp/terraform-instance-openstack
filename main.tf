resource "openstack_networking_port_v2" "primary_port" {
  count = var.instance_count

  network_id         = var.primary_network_id
  security_group_ids = var.security_groups
  admin_state_up     = true
}

resource "openstack_networking_port_v2" "secondary_port" {
  count = (var.secondary_network_id == "" ? 0 : var.instance_count)

  network_id         = var.secondary_network_id
  security_group_ids = var.security_groups
  admin_state_up     = true
}

resource "openstack_networking_floatingip_v2" "this" {
  count = (var.floating_ip ? var.instance_count : 0)

  pool = var.floating_ip_pool
}

resource "random_string" "servergroup_name" {
  length  = 16
  upper   = false
  number  = false
  special = false
}

resource "openstack_compute_servergroup_v2" "this" {
  name     = random_string.servergroup_name.result
  policies = ["anti-affinity"]
}

resource "openstack_compute_instance_v2" "this" {
  count = var.instance_count

  name        = format("ip-%s.%s", join("-", split(".", length(split(":", openstack_networking_port_v2.primary_port[count.index].all_fixed_ips[0])) > 1 ? openstack_networking_port_v2.primary_port[count.index].all_fixed_ips[1] : openstack_networking_port_v2.primary_port[count.index].all_fixed_ips[0])), var.domain)
  key_pair    = var.key_pair
  flavor_name = var.instance_type
  image_name  = var.instance_image
  metadata    = var.tags

  user_data = data.template_cloudinit_config.config[count.index].rendered

  network {
    port = openstack_networking_port_v2.primary_port[count.index].id
  }

  scheduler_hints {
    group = openstack_compute_servergroup_v2.this.id
  }

  lifecycle {
    ignore_changes = [
      "user_data",
      "key_pair",
      "image_name",
      "network",
      "scheduler_hints",
    ]
  }
}

resource "openstack_compute_interface_attach_v2" "attach_secondary_network" {
  count = (var.secondary_network_id != "" ? var.instance_count : 0)

  instance_id = openstack_compute_instance_v2.this[count.index].id
  port_id     = openstack_networking_port_v2.secondary_port[count.index].id
}

resource "openstack_compute_floatingip_associate_v2" "this" {
  count = (var.floating_ip ? var.instance_count : 0)

  floating_ip = openstack_networking_floatingip_v2.this[count.index].address
  instance_id = openstack_compute_instance_v2.this[count.index].id
}

data "template_cloudinit_config" "config" {
  count = var.instance_count

  gzip          = false
  base64_encode = false

  part {
    filename     = "default.cfg"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"

    content = <<EOF
#cloud-config
system_info:
  default_user:
    name: terraform
EOF
  }

  part {
    filename = "additional.cfg"
    merge_type = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content = var.additional_user_data
  }
}
