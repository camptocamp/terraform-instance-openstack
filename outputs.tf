output "floating_ips" {
  value = openstack_networking_floatingip_v2.this[*].address
}

output "instances_v4_ips" {
  value = openstack_compute_instance_v2.this[*].access_ip_v4
}

output "secondary_ports_ips" {
  value = openstack_networking_port_v2.secondary_port[*].all_fixed_ips
}

output "floating_ips_association" {
  value = openstack_compute_floatingip_associate_v2.this[*].floating_ip
}

output "public_ips_v4" {
  description = "Instances' public IPv4"
  value = [
    for i in range(length(openstack_compute_instance_v2.this[*])) :
    (var.public_interface == "primary" ? length(split(":", openstack_networking_port_v2.primary_port[i].all_fixed_ips[0])) > 1 ? openstack_networking_port_v2.primary_port[i].all_fixed_ips[1] : openstack_networking_port_v2.primary_port[i].all_fixed_ips[0] : length(split(":", openstack_networking_port_v2.secondary_port[i].all_fixed_ips[0])) > 1 ? openstack_networking_port_v2.secondary_port[i].all_fixed_ips[1] : openstack_networking_port_v2.secondary_port[i].all_fixed_ips[0])
  ]
}

output "hostnames" {
  description = "Instances' hostname"
  value       = openstack_compute_instance_v2.this[*].name
}
