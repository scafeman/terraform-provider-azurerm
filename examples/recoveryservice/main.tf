resource "random_integer" "ri" {
  min = 100
  max = 999
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}"
  location = "${var.resource_group_location}"
}

module "vm" {
  source = "modules/vm"

  resource_group_name = "${azurerm_resource_group.rg.name}"
  vm_size             = "Standard_B2ms"
  prefix              = "mscafe-web${random_integer.ri.result}"
  hostname            = "mscafe-web${random_integer.ri.result}"
  dns_name            = "mscafe-web${random_integer.ri.result}"
  admin_username      = "mscafe"
  admin_password      = "${var.admin_password}"
}

resource "azurerm_recovery_services_vault" "example" {
  name                = "mscafe-recovery-vault"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  sku                 = "Standard"
}

resource "azurerm_recovery_services_protection_policy_vm" "simple" {
  name                = "BKP-POL-DAILY11PM-RET14D"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  recovery_vault_name = "${azurerm_recovery_services_vault.example.name}"

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 14
  }
}

resource "azurerm_recovery_services_protection_policy_vm" "advanced" {
  name                = "BKP-POL-DAILY11PM-RET7D4W1M"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  recovery_vault_name = "${azurerm_recovery_services_vault.example.name}"

  timezone = "UTC"

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 7
  }
  retention_weekly {
    weekdays = ["Sunday"]
    count    = 4
  }

  retention_monthly {
    weekdays = ["Sunday"]
    weeks    = ["First"]
    count    = 1
  }
}

resource "azurerm_recovery_services_protected_vm" "example" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  recovery_vault_name = "${azurerm_recovery_services_vault.example.name}"
  source_vm_id        = "${module.vm.vm-id}"
  backup_policy_id    = "${azurerm_recovery_services_protection_policy_vm.simple.id}"
}
