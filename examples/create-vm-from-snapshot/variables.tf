variable "subscription_id" {}

variable "client_id" {}

variable "client_secret" {}

variable "tenant_id" {}

variable "resource_group" {
  description = "The name of the resource group in which to create the virtual network."
}

variable "rg_prefix" {
  description = "The shortened abbreviation to represent your resource group that will go on the front of some resources."
  default     = "mscafe-terraform-uat"
}

variable "hostname" {
  description = "VM Name"
}

#variable "dns_name" {
#  description = " Label for the Domain Name. Will be used to make up the FQDN. If a domain name label is specified, an A DNS record is created for the public IP in the Microsoft Azure DNS system."
#}

variable "storageaccount_name" {
  description = "Must be a globally unique name that is not already use"
  
}

variable "lb_ip_dns_name" {
  description = "DNS for Load Balancer IP"
}

variable "location" {
  description = "The location/region where the virtual network is created. Changing this forces a new resource to be created."
  default     = "southcentralus"
}

#variable "virtual_network_name" {
#  description = "The name for the virtual network."
#  default     = "vnet-mscafe-terraform"
#}

variable "address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = "10.20.0.0/21"
}

variable "subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.20.1.0/24"
}

variable "storage_account_tier" {
  description = "Defines the Tier of storage account to be created. Valid options are Standard and Premium."
  default     = "Premium"
}

variable "storage_replication_type" {
  description = "Defines the Replication Type to use for this storage account. Valid options include LRS, GRS etc."
  default     = "LRS"
}
variable "vm_count" {
  description = "Number of VM's to deploy"  
}

variable "environment" {
  description = "Name of the environment you want to deploy IE: Dev, Stage, UAT, Prod"  
}

variable "vm_size" {
  description = "Specifies the size of the virtual machine."
  default     = "Standard_B2ms"
}

variable "image_publisher" {
  description = "name of the publisher of the image (az vm image list)"
  default     = "MicrosoftWindowsServer"
}

variable "image_offer" {
  description = "the name of the offer (az vm image list)"
  default     = "WindowsServer"
}

variable "image_sku" {
  description = "image sku to apply (az vm image list)"
  default     = "2016-Datacenter"
}

variable "image_version" {
  description = "version of the image to apply (az vm image list)"
  default     = "latest"
}

variable "admin_username" {
  description = "administrator user name"
  default     = "mscafe"
}

variable "admin_password" {
  description = "administrator password (recommended to disable password auth)"
}
