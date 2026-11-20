terraform {
  required_version = ">= 1.6.0"
  required_providers { null = { source = "hashicorp/null", version = "~> 3.2" } }
}
variable "node_1_ip" { type = string }
variable "node_2_ip" { type = string }
variable "node_3_ip" { type = string }
variable "ssh_private_key_path" { type = string }
variable "k3s_token" { type = string; sensitive = true }
variable "metallb_ip_range" { type = string }

module "network" { source = "../../modules/network"; metallb_ip_range = var.metallb_ip_range }
module "storage" { source = "../../modules/storage" }
module "k3s_nodes" {
  source               = "../../modules/k3s-nodes"
  node_1_ip            = var.node_1_ip
  node_2_ip            = var.node_2_ip
  node_3_ip            = var.node_3_ip
  ssh_private_key_path = var.ssh_private_key_path
  k3s_token            = var.k3s_token
}
