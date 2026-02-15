# ТОЛЬКО несекретные переменные
variable "folder_id" {
  type        = string
  description = "Yandex Cloud Folder ID"
}

# дЛя теста потом убрать обязательно
variable "registry_id" {
  type        = string
  description = "Yandex Container Registry ID"
}

variable "s3_bucket_name" {
  type        = string
  description = "S3 bucket name for Docker registry"
  default     = "docker-registry-stellarclaw"
}

variable "domain_name" {
  type        = string
  description = "Domain name"
  default     = "stellarclaw.ru"
}


# Чувствительные переменные БЕЗ значений по умолчанию
variable "yc_access_key" {
  type        = string
  description = "Yandex Cloud Access Key for S3"
  sensitive   = true
}

variable "yc_secret_key" {
  type        = string
  description = "Yandex Cloud Secret Key for S3"
  sensitive   = true
}

variable "network_id_default" {
  type        = string
  description = "id network default"
}

variable "subnet-name" {
  type        = string
  description = "subnet name for default network"
  default     = "app-subnet"
}

variable "image_id" {
  description = "id image VM"
  type        = string
  default     = "fd81r1dpns2m4mgssm0q"
}


variable "vm_names" {
  type    = list(string)
  #default = ["server-1","client-1"]
  default = ["server-1","server-2","server-3","client-1","client-2","client-3"]

}


