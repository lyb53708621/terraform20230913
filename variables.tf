variable "prefix" {
  type    = string
  default = "dev"
}

variable "backend_key" {
  type    = string
  default = "dev.terrasform.tfstate"
}

variable "environment" {
  type    = string
  default = "dev"
}
variable "location" {
  type    = string
  default = "australiaeast"
}

variable "vm_username" {
  type    = string
  default = "azureuser"
}

variable "vm_password" {
  type    = string
  default = "Testceph123!"
}

variable "disk_size_gb" {
  type    = number
  default = 20
}