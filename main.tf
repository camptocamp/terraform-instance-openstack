resource "openstack_networking_port_v2" "primary_port" {
  count = var.instance_count

  network_id         = var.primary_network_id
  security_group_ids = var.security_groups
  admin_state_up     = true
  region             = var.region
}

resource "openstack_networking_port_v2" "secondary_port" {
  count = (var.secondary_network_id == "" ? 0 : var.instance_count)

  network_id         = var.secondary_network_id
  security_group_ids = var.security_groups
  admin_state_up     = true
  region             = var.region
}

resource "openstack_networking_floatingip_v2" "this" {
  count = (var.floating_ip ? var.instance_count : 0)

  pool   = var.floating_ip_pool
  region = var.region
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
  region   = var.region
}

resource "openstack_compute_instance_v2" "this" {
  count = var.instance_count

  name        = format("ip-%s.%s", join("-", split(".", length(split(":", openstack_networking_port_v2.primary_port[count.index].all_fixed_ips[0])) > 1 ? openstack_networking_port_v2.primary_port[count.index].all_fixed_ips[1] : openstack_networking_port_v2.primary_port[count.index].all_fixed_ips[0])), var.domain)
  key_pair    = var.key_pair
  flavor_name = var.flavor_name
  image_name  = var.image_name
  metadata    = var.tags
  region      = var.region

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

resource "openstack_compute_interface_attach_v2" "secondary_network" {
  count = (var.secondary_network_id != "" ? var.instance_count : 0)

  instance_id = openstack_compute_instance_v2.this[count.index].id
  port_id     = openstack_networking_port_v2.secondary_port[count.index].id
  region      = var.region
}

resource "openstack_compute_floatingip_associate_v2" "this" {
  count = (var.floating_ip ? var.instance_count : 0)

  floating_ip = openstack_networking_floatingip_v2.this[count.index].address
  instance_id = openstack_compute_instance_v2.this[count.index].id
  region      = var.region
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
    filename     = "additional.cfg"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = var.additional_user_data
  }
}

resource "null_resource" "provisioner" {
  count      = var.instance_count
  depends_on = ["openstack_compute_instance_v2.this", "openstack_networking_port_v2.primary_port", "openstack_networking_port_v2.secondary_port"]

  connection {
    type     = lookup(var.connection, "type", null)
    user     = lookup(var.connection, "user", "terraform")
    password = lookup(var.connection, "password", null)
    host = coalesce(
      (var.floating_ip ? openstack_networking_floatingip_v2.this[count.index].address : ""),
      length(split(":", element(openstack_networking_port_v2.primary_port[count.index].all_fixed_ips, 0))) > 1 ? element(openstack_networking_port_v2.primary_port[count.index].all_fixed_ips, 1) : element(openstack_networking_port_v2.primary_port[count.index].all_fixed_ips, 0),
      openstack_compute_instance_v2.this[count.index].access_ip_v4,
      openstack_compute_instance_v2.this[count.index].access_ip_v6,
    )
    port                = lookup(var.connection, "port", 22)
    timeout             = lookup(var.connection, "timeout", "")
    script_path         = lookup(var.connection, "script_path", null)
    private_key         = lookup(var.connection, "private_key", null)
    agent               = lookup(var.connection, "agent", null)
    agent_identity      = lookup(var.connection, "agent_identity", null)
    host_key            = lookup(var.connection, "host_key", null)
    https               = lookup(var.connection, "https", false)
    insecure            = lookup(var.connection, "insecure", false)
    use_ntlm            = lookup(var.connection, "use_ntlm", false)
    cacert              = lookup(var.connection, "cacert", null)
    bastion_host        = lookup(var.connection, "bastion_host", null)
    bastion_host_key    = lookup(var.connection, "bastion_host_key", null)
    bastion_port        = lookup(var.connection, "bastion_port", 22)
    bastion_user        = lookup(var.connection, "bastion_user", null)
    bastion_password    = lookup(var.connection, "bastion_password", null)
    bastion_private_key = lookup(var.connection, "bastion_private_key", null)
  }

  provisioner "ansible" {
    plays {
      playbook {
        file_path  = "${path.module}/ansible-data/playbooks/instance.yml"
        roles_path = ["${path.module}/ansible-data/roles"]
      }

      groups = ["instance"]
      become = true
      diff   = true

      extra_vars = {
        extra_addresses = jsonencode(zipmap(
          [
            var.secondary_network_id != "" ? openstack_networking_port_v2.secondary_port[count.index].mac_address : "",
          ],
          [
            var.secondary_network_id != "" ? openstack_networking_port_v2.secondary_port[count.index].all_fixed_ips[0] : "",
          ],
        ))
      }
    }

    ansible_ssh_settings {
      connect_timeout_seconds = 60
    }
  }
}

#########
# Puppet

module "puppet-node" {
  source         = "git::ssh://git@github.com/camptocamp/terraform-puppet-node.git"
  instance_count = var.puppet == null ? 0 : var.instance_count

  instances = [
    for i in range(length(openstack_compute_instance_v2.this)) :
    {
      hostname = openstack_compute_instance_v2.this[i].name
      connection = {
        type     = lookup(var.connection, "type", null)
        user     = lookup(var.connection, "user", "terraform")
        password = lookup(var.connection, "password", null)
        host = coalesce(
          (var.floating_ip ? openstack_networking_floatingip_v2.this[i].address : ""),
          length(split(":", element(openstack_networking_port_v2.primary_port[i].all_fixed_ips, 0))) > 1 ? element(openstack_networking_port_v2.primary_port[i].all_fixed_ips, 1) : element(openstack_networking_port_v2.primary_port[i].all_fixed_ips, 0),
          openstack_compute_instance_v2.this[i].access_ip_v4,
          openstack_compute_instance_v2.this[i].access_ip_v6,
        )
        port                = lookup(var.connection, "port", 22)
        timeout             = lookup(var.connection, "timeout", "")
        script_path         = lookup(var.connection, "script_path", null)
        private_key         = lookup(var.connection, "private_key", null)
        agent               = lookup(var.connection, "agent", null)
        agent_identity      = lookup(var.connection, "agent_identity", null)
        host_key            = lookup(var.connection, "host_key", null)
        https               = lookup(var.connection, "https", false)
        insecure            = lookup(var.connection, "insecure", false)
        use_ntlm            = lookup(var.connection, "use_ntlm", false)
        cacert              = lookup(var.connection, "cacert", null)
        bastion_host        = lookup(var.connection, "bastion_host", null)
        bastion_host_key    = lookup(var.connection, "bastion_host_key", null)
        bastion_port        = lookup(var.connection, "bastion_port", 22)
        bastion_user        = lookup(var.connection, "bastion_user", null)
        bastion_password    = lookup(var.connection, "bastion_password", null)
        bastion_private_key = lookup(var.connection, "bastion_private_key", null)
      }
    }
  ]

  server_address    = lookup(var.puppet, "server_address", null)
  server_port       = lookup(var.puppet, "server_port", 443)
  ca_server_address = lookup(var.puppet, "ca_server_address", null)
  ca_server_port    = lookup(var.puppet, "ca_server_port", 443)
  environment       = lookup(var.puppet, "environment", null)
  role              = lookup(var.puppet, "role", null)
  autosign_psk      = lookup(var.puppet, "autosign_psk", null)

  deps_on = null_resource.provisioner[*].id
}

##########
# Rancher

module "rancher-host" {
  source         = "git::ssh://git@github.com/camptocamp/terraform-rancher-host.git"
  instance_count = var.rancher == null ? 0 : var.instance_count

  instances = [
    for i in range(length(openstack_compute_instance_v2.this)) :
    {
      hostname = openstack_compute_instance_v2.this[i].name
      agent_ip = length(split(":", element(openstack_networking_port_v2.primary_port[i].all_fixed_ips, 0))) > 1 ? element(openstack_networking_port_v2.primary_port[i].all_fixed_ips, 1) : element(openstack_networking_port_v2.primary_port[i].all_fixed_ips, 0)
      connection = {
        type     = lookup(var.connection, "type", null)
        user     = lookup(var.connection, "user", "terraform")
        password = lookup(var.connection, "password", null)
        host = coalesce(
          (var.floating_ip ? openstack_networking_floatingip_v2.this[i].address : ""),
          length(split(":", element(openstack_networking_port_v2.primary_port[i].all_fixed_ips, 0))) > 1 ? element(openstack_networking_port_v2.primary_port[i].all_fixed_ips, 1) : element(openstack_networking_port_v2.primary_port[i].all_fixed_ips, 0),
          openstack_compute_instance_v2.this[i].access_ip_v4,
          openstack_compute_instance_v2.this[i].access_ip_v6,
        )
        port                = lookup(var.connection, "port", 22)
        timeout             = lookup(var.connection, "timeout", "")
        script_path         = lookup(var.connection, "script_path", null)
        private_key         = lookup(var.connection, "private_key", null)
        agent               = lookup(var.connection, "agent", null)
        agent_identity      = lookup(var.connection, "agent_identity", null)
        host_key            = lookup(var.connection, "host_key", null)
        https               = lookup(var.connection, "https", false)
        insecure            = lookup(var.connection, "insecure", false)
        use_ntlm            = lookup(var.connection, "use_ntlm", false)
        cacert              = lookup(var.connection, "cacert", null)
        bastion_host        = lookup(var.connection, "bastion_host", null)
        bastion_host_key    = lookup(var.connection, "bastion_host_key", null)
        bastion_port        = lookup(var.connection, "bastion_port", 22)
        bastion_user        = lookup(var.connection, "bastion_user", null)
        bastion_password    = lookup(var.connection, "bastion_password", null)
        bastion_private_key = lookup(var.connection, "bastion_private_key", null)
      }

      host_labels = merge(
        var.rancher != null ? var.rancher.host_labels : {},
        {
          "io.rancher.host.os"       = "linux"
          "io.rancher.host.provider" = "openstack"
          "io.rancher.host.region"   = var.region
          "io.rancher.host.external_dns_ip" = coalesce(
            (var.floating_ip ? openstack_networking_floatingip_v2.this[i].address : ""),
            length(split(":", element(openstack_networking_port_v2.primary_port[i].all_fixed_ips, 0))) > 1 ? element(openstack_networking_port_v2.primary_port[i].all_fixed_ips, 1) : element(openstack_networking_port_v2.primary_port[i].all_fixed_ips, 0),
          )
        }
      )
    }
  ]

  environment_id = var.rancher != null ? var.rancher.environment_id : ""

  deps_on = var.puppet != null ? module.puppet-node.this_provisioner_id : []
}
