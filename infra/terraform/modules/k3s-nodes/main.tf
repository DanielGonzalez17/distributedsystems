variable "node_1_ip" { type = string }
variable "node_2_ip" { type = string }
variable "node_3_ip" { type = string }
variable "ssh_user"  { type = string; default = "ubuntu" }
variable "ssh_private_key_path" { type = string }
variable "k3s_token" { type = string; sensitive = true }
variable "k3s_version" { type = string; default = "v1.31.2+k3s1" }

resource "null_resource" "k3s_node_1" {
  connection {
    type        = "ssh"
    host        = var.node_1_ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
  }
  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' K3S_TOKEN='${var.k3s_token}' sh -s - server --cluster-init --disable servicelb --tls-san ${var.node_1_ip} --write-kubeconfig-mode 644"
    ]
  }
}

resource "null_resource" "k3s_node_2" {
  depends_on = [null_resource.k3s_node_1]
  connection {
    type        = "ssh"
    host        = var.node_2_ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
  }
  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' K3S_TOKEN='${var.k3s_token}' sh -s - server --server https://${var.node_1_ip}:6443 --disable servicelb --tls-san ${var.node_2_ip}"
    ]
  }
}

resource "null_resource" "k3s_node_3" {
  depends_on = [null_resource.k3s_node_1]
  connection {
    type        = "ssh"
    host        = var.node_3_ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
  }
  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' K3S_TOKEN='${var.k3s_token}' sh -s - server --server https://${var.node_1_ip}:6443 --disable servicelb --tls-san ${var.node_3_ip}"
    ]
  }
}

resource "null_resource" "fetch_kubeconfig" {
  depends_on = [null_resource.k3s_node_1, null_resource.k3s_node_2, null_resource.k3s_node_3]
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "New-Item -ItemType Directory -Path \"$env:USERPROFILE\\.kube\" -Force | Out-Null; scp -o StrictHostKeyChecking=no -i '${var.ssh_private_key_path}' ${var.ssh_user}@${var.node_1_ip}:/etc/rancher/k3s/k3s.yaml \"$env:USERPROFILE\\.kube\\config\"; (Get-Content \"$env:USERPROFILE\\.kube\\config\") -replace '127.0.0.1', '${var.node_1_ip}' | Set-Content \"$env:USERPROFILE\\.kube\\config\""
  }
}
