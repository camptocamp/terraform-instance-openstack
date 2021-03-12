variable "instance_count" {
  type    = number
  default = 1
}

variable "key_pair" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "connection" {
  default = {}
}

variable "region" {
  type    = string
  default = ""
}

##########
# Compute

variable "display_name" {
  type    = string
  default = ""
}

variable "flavor_name" {
  type = string
}

variable "image_name" {
  type = string
}

variable "domain" {
  type = string
}

variable "additional_user_data" {
  default = "#cloud-config\n"
}

##########
# Network

variable "security_groups" {
  type    = list(string)
  default = []
}

variable "primary_network_id" {
  type    = string
  default = ""
}

variable "secondary_network_id" {
  type    = string
  default = ""
}

variable "floating_ip" {
  type    = bool
  default = false
}

variable "floating_ip_pool" {
  type    = string
  default = "public"
}

variable "public_interface" {
  type    = string
  default = "primary"
}

##########
# Rancher

variable "rancher" {
  type = object({
    environment_id = string
    host_labels    = map(string)
  })
  default = null
}

#########
# Puppet

variable "puppet" {
  type    = map(string)
  default = null
}
