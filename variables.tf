variable "instance_count" {
  default = 1
}

variable "key_pair" {}

variable "security_groups" {
  default = []
}

variable "instance_type" {}
variable "instance_image" {}

variable "domain" {}

variable "primary_network_id" {
  default = ""
}

variable "secondary_network_id" {
  default = ""
}

variable "floating_ip" {
  default = false
}

variable "floating_ip_pool" {
  default = "public"
}

variable "tags" {
  default = {}
}

variable "public_interface" {
  default = "primary"
}

variable "additional_user_data" {
  default = "#cloud-config\n"
}
