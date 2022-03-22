variable "database_password" {
    default = ""
}

variable "domain" {
    default = ""
}

variable "webmaster_email" {
    default = ""
}

variable "admin_password" {
    default = ""
}

resource "random_password" "database_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "admin_password" {
  length           = 8
  special          = true
  override_special = "_%@"
}


resource "digitalocean_droplet" "www-nextcloud" {
  #This has pre installed docker
  image = "docker-20-04"
  name = "www-nextcloud-ghost"
  region = "nyc3"
  size = "s-1vcpu-1gb"
  ssh_keys = [
    digitalocean_ssh_key.terraform.id
  ]

  connection {
    host = self.ipv4_address
    user = "root"
    type = "ssh"
    private_key = var.pvt_key != "" ? file(var.pvt_key) : tls_private_key.pk.private_key_pem
    timeout = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin",
      # install nginx and docker
      "sleep 5s",
      "apt update",
      "sleep 5s",
      "apt install -y nginx",
      "apt install -y python3-certbot-nginx",
      # create nextcloud_ghost installation directory
      "mkdir /root/nextcloud_ghost",
      "mkdir /root/nextcloud_ghost/web",
    ]
  }

  provisioner "file" {
    content      = templatefile("db.env.tpl", {
      database_password = var.database_password != "" ? var.database_password : random_password.database_password.result
    })
    destination = "/root/nextcloud_ghost/db.env"
  }

  provisioner "file" {
    content      = templatefile("docker-compose.yml.tpl", {
      url = var.domain != "" ? var.domain : "0.0.0.0"
    })
    destination = "/root/nextcloud_ghost/docker-compose.yml"
  }

  provisioner "file" {
    source      = "web/Dockerfile"
    destination = "/root/nextcloud_ghost/web/Dockerfile"
  }

  provisioner "file" {
    source      = "web/nginx.conf"
    destination = "/root/nextcloud_ghost/web/nginx.conf"
  }

  provisioner "file" {
    content      = templatefile("atmosphere-nginx.conf.tpl", {
      server_name = var.domain != "" ? var.domain : "0.0.0.0"
    })
    destination = "/etc/nginx/conf.d/atmosphere-nginx.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin",
      # run compose
      "cd /root/nextcloud_ghost",
      "docker-compose up -d",
      "rm /etc/nginx/sites-enabled/default",
      "systemctl restart nginx",
      "ufw allow http",
      "ufw allow https",
      "sleep 5s",
      "%{if var.domain!= ""}certbot --nginx --non-interactive --agree-tos --domains ${var.domain} --redirect %{if var.webmaster_email!= ""} --email ${var.webmaster_email} %{ else } --register-unsafely-without-email %{ endif } %{ else }echo NOCERTBOT%{ endif }"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin",
      # Bugfix with nextcloud desktop client & complete installation to avoid users with @ symbol breaking the installation wizard
      "cd /root/nextcloud_ghost",
      "docker exec -u www-data nextcloud_app_1 php occ maintenance:install --admin-user=atmosphere --admin-pass=${var.admin_password != "" ? var.admin_password : random_password.admin_password.result}",
    ]
  }
  
  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin",
      # Bugfix desktop client fails to connect
      "cd /root/nextcloud_ghost",
      "docker exec -u www-data nextcloud_app_1 php occ config:system:set trusted_domains 0 --value ${var.domain}",
      "docker exec -u www-data nextcloud_app_1 php occ config:system:set overwriteprotocol --type string --value https",
      # Disabling uneeded nextcloud plugins
      "docker exec -u www-data nextcloud_app_1 php occ app:disable circles contactsinteraction dashboard firstrunwizard nextcloud_announcements recommendations sharebymail support survey_client updatenotification user_status weather_status",
    ]
  }
}