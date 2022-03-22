output "ip_address" {
  description = "IP Address of deployed server"
  value       = digitalocean_droplet.www-nextcloud.ipv4_address
}

output "http_address" {
  description = "You can visit your installation at: "
  value       = "http://${var.domain != "" ? var.domain : digitalocean_droplet.www-nextcloud.ipv4_address}/"
}

output "username" {
  description = "Admin user: "
  value       = "atmosphere"
}

output "password" {
  description = "Admin password: "
  sensitive   = true
  value       = "${var.admin_password != "" ? var.admin_password : random_password.admin_password.result}"
}