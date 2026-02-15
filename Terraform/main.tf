terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.92"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone      = "ru-central1-a"
  folder_id = var.folder_id

}


# Подсеть в сети default
resource "yandex_vpc_subnet" "app_subnet" {
  name           = var.subnet-name
  description    = var.subnet-name
  zone           = "ru-central1-a"
  network_id     = var.network_id_default
  v4_cidr_blocks = ["10.131.0.0/24"]
}

# Диски для ВМ
resource "yandex_compute_disk" "boot_disks" {
  for_each = toset(var.vm_names)
  name     = "${each.value}-boot-disk"
  type     = "network-ssd"
  zone     = "ru-central1-a"
  size     = 20
  image_id = var.image_id
}

# Виртуальные машины
resource "yandex_compute_instance" "vms" {
  for_each = toset(var.vm_names)
  name     = each.value
  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    disk_id = yandex_compute_disk.boot_disks[each.key].id
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.app_subnet.id
    nat       = true
  }
  labels = {
    name = each.value
  }
  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
    user-data = <<-EOF
      #!/bin/bash
      systemctl stop unattended-upgrades
      systemctl disable unattended-upgrades
      apt-get remove -y unattended-upgrades 2>/dev/null || true
    EOF

  }
}


locals {
  vms = {
    for vm_name, vm_instance in yandex_compute_instance.vms : vm_name => {
      ansible_host = vm_instance.network_interface[0].nat_ip_address
      ansible_user = "ubuntu"
    }
  }

  # Только сервера
  server_vms = {
    for vm_name, vm_instance in yandex_compute_instance.vms : 
    vm_name => vm_instance
    if startswith(vm_name, "server")
  }

}


resource "local_file" "ansible_inventory_ini" {
  filename = "${path.module}/ansible/inventory.ini"
  content  = templatefile("${path.module}/templates/ansible.tmpl", { 
    vms = local.vms 
  })
}

# Создание DNS зоны для Let's Encrypt
resource "yandex_dns_zone" "lego_zone" {
  name        = "stellarclaw-lego-cert-zone"
  zone        = "${var.domain_name}." 
  public      = true
  description = "DNS zone for Let's Encrypt Lego"
}

# Wildcard DNS запись
resource "yandex_dns_recordset" "wildcard" {
  count = length(local.server_vms) > 0 ? 1 : 0

  zone_id = yandex_dns_zone.lego_zone.id
  name    = "*.${var.domain_name}."
  type    = "A"
  ttl     = 300
  data    = [for vm in local.server_vms : vm.network_interface[0].nat_ip_address]

  depends_on = [
    yandex_compute_instance.vms,
    yandex_dns_zone.lego_zone
  ]
}

# Сервисный аккаунт для Lego Let's Encrypt
resource "yandex_iam_service_account" "lego_sa" {
  name        = "lego-cert-sa"
  description = "Service account for Let's Encrypt Lego"
  folder_id   = var.folder_id
}

# Роль для управления DNS зонами
resource "yandex_resourcemanager_folder_iam_member" "dns_admin" {
  folder_id = var.folder_id
  role      = "dns.admin"
  member    = "serviceAccount:${yandex_iam_service_account.lego_sa.id}"
}

# Создание JSON ключа для сервисного аккаунта
resource "yandex_iam_service_account_key" "lego_key" {
  service_account_id = yandex_iam_service_account.lego_sa.id
  description        = "JSON key for Lego Let's Encrypt DNS provider"
  key_algorithm      = "RSA_2048"
}

# Создание статического ключа доступа 
resource "yandex_iam_service_account_static_access_key" "lego_static_key" {
  service_account_id = yandex_iam_service_account.lego_sa.id
  description        = "Static access key for Lego"
}

# Сохранение JSON ключа в файл
resource "local_file" "lego_service_account_key" {
  content = jsonencode({
    "id"                 = yandex_iam_service_account_key.lego_key.id
    "service_account_id" = yandex_iam_service_account.lego_sa.id
    "created_at"         = yandex_iam_service_account_key.lego_key.created_at
    "key_algorithm"      = "RSA_2048"
    "public_key"         = yandex_iam_service_account_key.lego_key.public_key
    "private_key"        = yandex_iam_service_account_key.lego_key.private_key
  })
  filename = "${path.module}/ansimble/role/certs_update/lego-service-account-key.json"
}

# Output для JSON ключа 
output "lego_service_account_key_json" {
  value = jsonencode({
    "id"                 = yandex_iam_service_account_key.lego_key.id
    "service_account_id" = yandex_iam_service_account.lego_sa.id
    "created_at"         = yandex_iam_service_account_key.lego_key.created_at
    "key_algorithm"      = "RSA_2048"
    "public_key"         = yandex_iam_service_account_key.lego_key.public_key
    "private_key"        = yandex_iam_service_account_key.lego_key.private_key
  })
  sensitive   = true
  description = "Full JSON key for Lego Let's Encrypt authentication"
}

# Output для информации о DNS зоне
output "dns_zone_id" {
  value       = yandex_dns_zone.lego_zone.id
  description = "DNS zone ID for Let's Encrypt challenges"
}

output "dns_zone_name" {
  value       = yandex_dns_zone.lego_zone.name
  description = "DNS zone name"
}

output "dns_zone_domain" {
  value       = yandex_dns_zone.lego_zone.zone
  description = "DNS zone domain"
}

