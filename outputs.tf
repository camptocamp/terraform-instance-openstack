output "this_floating_ip_address" {
  value = openstack_networking_floatingip_v2.this[*].address
}

output "this_instance_ipv4" {
  description = "Instances' IPv4"
  value       = openstack_compute_instance_v2.this[*].access_ip_v4
}

output "this_secondary_port_ips" {
  value = openstack_networking_port_v2.secondary_port[*].all_fixed_ips
}

output "this_instance_public_ipv4" {
  description = "Instances' public IPv4"
  value = [
    for i in range(length(openstack_compute_instance_v2.this[*])) :
    (var.public_interface == "primary" ? length(split(":", openstack_networking_port_v2.primary_port[i].all_fixed_ips[0])) > 1 ? openstack_networking_port_v2.primary_port[i].all_fixed_ips[1] : openstack_networking_port_v2.primary_port[i].all_fixed_ips[0] : length(split(":", openstack_networking_port_v2.secondary_port[i].all_fixed_ips[0])) > 1 ? openstack_networking_port_v2.secondary_port[i].all_fixed_ips[1] : openstack_networking_port_v2.secondary_port[i].all_fixed_ips[0])
  ]
}

output "this_instance_hostname" {
  description = "Instances' hostname"
  value       = var.hostname != "" ? [for i in range(length(openstack_compute_instance_v2.this)) : format("%s-%s", var.hostname, i)] : openstack_compute_instance_v2.this[*].name
}

output "this_instance_id" {
  description = "Instance's id"
  value       = openstack_compute_instance_v2.this[*].id
}
