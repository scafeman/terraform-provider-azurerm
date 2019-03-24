provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"

  version = "=1.23.0"
}

# Locate the existing custom/golden image
data "azurerm_image" "search" {
  name                = "${var.image_name}"
  resource_group_name = "${var.image_resource_group}"
}

output "image_id" {
  value = "${data.azurerm_image.search.id}"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-scu-${var.resource_group}-${var.environment}"
  location = "${var.location}"

  tags {
   environment = "${var.environment}"
  }
}

resource "azurerm_resource_group" "rsv_rg" {
  name     = "rg-scu-rsv-${var.rsv_resource_group}-${var.environment}"
  location = "${var.location}"

  tags {
   environment = "${var.environment}"
  }
}

resource "azurerm_storage_account" "stor" {
  name                     = "${var.environment}${var.storageaccount_name}stor"
  location                 = "${var.location}"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  account_tier             = "${var.storage_account_tier}"
  account_replication_type = "${var.storage_replication_type}"

  tags {
   environment = "${var.environment}"
  }
}

resource "azurerm_availability_set" "avset" {
  name                         = "avset-${var.rg_prefix}-${var.environment}"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true

  tags {
   environment = "${var.environment}"
  }
}

resource "azurerm_public_ip" "lbpip" {
  name                         = "pip-${var.rg_prefix}-${var.environment}"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  allocation_method = "Dynamic"
  domain_name_label            = "${var.lb_ip_dns_name}-${var.environment}-${var.hostname}"

  tags {
   environment = "${var.environment}"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.rg_prefix}-${var.environment}"
  location            = "${var.location}"
  address_space       = ["${var.address_space}"]
  resource_group_name = "${azurerm_resource_group.rg.name}"

  tags {
   environment = "${var.environment}"
  }
}

resource "azurerm_subnet" "subnet" {
  name                 = "sn-${var.rg_prefix}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "${var.subnet_prefix}"
}

resource "azurerm_lb" "lb" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  name                = "ilb-${var.rg_prefix}-${var.environment}-${var.hostname}"
  location            = "${var.location}"

    tags {
      environment = "${var.environment}"
    }

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = "${azurerm_public_ip.lbpip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.lb.id}"
  name                = "BackendPool1"
}

resource "azurerm_lb_nat_rule" "tcp" {
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.lb.id}"
  name                           = "RDP-VM-${count.index}"
  protocol                       = "tcp"
  frontend_port                  = "5000${count.index + 1}"
  backend_port                   = 3389
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  count                          = 2
}

resource "azurerm_lb_rule" "lb_rule" {
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.lb.id}"
  name                           = "LBRule"
  protocol                       = "tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  enable_floating_ip             = false
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.backend_pool.id}"
  idle_timeout_in_minutes        = 5
  probe_id                       = "${azurerm_lb_probe.lb_probe.id}"
  depends_on                     = ["azurerm_lb_probe.lb_probe"]
}

resource "azurerm_lb_probe" "lb_probe" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.lb.id}"
  name                = "tcpProbe"
  protocol            = "tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.environment}-${var.hostname}${count.index + 1}-nic"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  count               = 2
    tags {
      environment = "${var.environment}"
    }

  ip_configuration {
    name                                    = "ipconfig${count.index}"
    subnet_id                               = "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation           = "Dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.backend_pool.id}"]
    load_balancer_inbound_nat_rules_ids     = ["${element(azurerm_lb_nat_rule.tcp.*.id, count.index)}"]
  }
}

#resource "azurerm_network_interface_backend_address_pool_association" "backend_pool" {
#  network_interface_id    = "${element(azurerm_network_interface.nic.*.id,count.index)}"
#  ip_configuration_name   = "ipconfig${count.index}"
#  backend_address_pool_id = "${azurerm_lb_backend_address_pool.backend_pool.id}"
#  count                   = "${var.vm_count}"
#  depends_on              = ["azurerm_network_interface.nic","azurerm_lb_backend_address_pool.backend_pool"]
#}

#resource "azurerm_network_interface_nat_rule_association" "tcp" {
#  network_interface_id  = "${element(azurerm_network_interface.nic.*.id,count.index)}"
#  ip_configuration_name = "ipconfig${count.index}"
#  nat_rule_id           = "${azurerm_lb_nat_rule.tcp.id}"
#  count                 = "${var.vm_count}"
#  depends_on            = ["azurerm_network_interface.nic","azurerm_lb_nat_rule.tcp"]
#}

resource "azurerm_virtual_machine" "vm" {
  name                  = "${var.environment}-${var.hostname}${count.index + 1}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  availability_set_id   = "${azurerm_availability_set.avset.id}"
  vm_size               = "${var.vm_size}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  count                 = "${var.vm_count}"

    tags {
      environment = "${var.environment}"
    }

  storage_image_reference {
    id = "${data.azurerm_image.search.id}"
  }
  #storage_image_reference {
  #  publisher = "${var.image_publisher}"
  #  offer     = "${var.image_offer}"
  #  sku       = "${var.image_sku}"
  #  version   = "${var.image_version}"
  #}

  storage_os_disk {
    name              = "${var.environment}-${var.hostname}${count.index + 1}-osdisk"
    managed_disk_type = "Premium_LRS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = "${var.hostname}${count.index +1}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  os_profile_windows_config {
    provision_vm_agent  = "true"
  }
}

resource "azurerm_sql_server" "server" {
  name                         = "sqlsvr-${var.rg_prefix}-${var.environment}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  location                     = "${var.location}"
  version                      = "12.0"
  administrator_login          = "${var.sql_admin}"
  administrator_login_password = "${var.sql_password}"

  tags {
   environment = "${var.environment}"
  }
}

resource "azurerm_sql_database" "db" {
  name                             = "sqlsvr-${var.rg_prefix}-${var.environment}-db"
  resource_group_name              = "${azurerm_resource_group.rg.name}"
  location                         = "${var.location}"
  edition                          = "Standard"
  collation                        = "SQL_Latin1_General_CP1_CI_AS"
  create_mode                      = "Default"
  requested_service_objective_name = "S1"
  server_name                      = "${azurerm_sql_server.server.name}"

  tags {
   environment = "${var.environment}"
  }
}

# Enables the "Allow Access to Azure services" box as described in the API docs 
# https://docs.microsoft.com/en-us/rest/api/sql/firewallrules/createorupdate
resource "azurerm_sql_firewall_rule" "fw" {
  name                = "firewallrule-1"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  server_name         = "${azurerm_sql_server.server.name}"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

resource "azurerm_recovery_services_vault" "rsv" {
  name                = "rsv-${var.rg_prefix}-${var.environment}"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rsv_rg.name}"
  sku                 = "Standard"
}

resource "azurerm_recovery_services_protection_policy_vm" "simple" {
  name                = "BKP-POL-DAILY11PM-RET14D"
  resource_group_name = "${azurerm_resource_group.rsv_rg.name}"
  recovery_vault_name = "${azurerm_recovery_services_vault.rsv.name}"

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
  resource_group_name = "${azurerm_resource_group.rsv_rg.name}"
  recovery_vault_name = "${azurerm_recovery_services_vault.rsv.name}"

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

resource "azurerm_recovery_services_protected_vm" "enable_backup" {
  count               = "${var.enable_backup == "true" && var.vm_count > 0 ? var.vm_count : 0}"
  resource_group_name = "${azurerm_resource_group.rsv_rg.name}"
  recovery_vault_name = "${azurerm_recovery_services_vault.rsv.name}"
  source_vm_id        = "${element(azurerm_virtual_machine.vm.*.id, count.index)}"
#  source_vm_id        = "${azurerm_virtual_machine.vm.*.id[count.index]}"
  backup_policy_id    = "${azurerm_recovery_services_protection_policy_vm.simple.id}"

    tags {
    environment = "${var.environment}"
  }
}

#resource "azurerm_virtual_machine_extension" "IIS" {
#  name                 = "${var.hostname}${count.index +1}"
#  location             = "${var.location}"
#  resource_group_name  = "${azurerm_resource_group.rg.name}"
#  virtual_machine_name = "${element(azurerm_virtual_machine.vm.*.id, count.index)}"
#  publisher            = "Microsoft.Compute"
#  type                 = "CustomScript"
#  type_handler_version = "2.0"
#
#  settings = <<SETTINGS
#    {
#        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools"
#    }
#SETTINGS
#    }