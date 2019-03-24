variable "resource_group_name" {
  type        = "string"
  description = "Name of the azure resource group."
  default     = "rg-scu-mscafe-recovery_services"
}

variable "resource_group_location" {
  type        = "string"
  description = "Location of the azure resource group."
  default     = "southcentralus"
}

variable "admin_password" {
  description = "Enter VM Administrator Password"
}
