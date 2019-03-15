provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"

  version = "=1.23.0"
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group}"
  location = "${var.location}"
}

resource "azurerm_storage_account" "stor" {
  name                     = "${var.storageaccount_name}stor"
  location                 = "${var.location}"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  account_tier             = "${var.storage_account_tier}"
  account_replication_type = "${var.storage_replication_type}"
}

resource "azurerm_availability_set" "avset" {
  name                         = "avset-${var.rg_prefix}"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

resource "azurerm_public_ip" "lbpip" {
  name                         = "pip-${var.rg_prefix}"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  allocation_method = "Dynamic"
  domain_name_label            = "${var.lb_ip_dns_name}"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.rg_prefix}"
  location            = "${var.location}"
  address_space       = ["${var.address_space}"]
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "subnet" {
  name                 = "sn-${var.rg_prefix}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "${var.subnet_prefix}"
}

resource "azurerm_lb" "lb" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  name                = "ilb-${var.rg_prefix}-web"
  location            = "${var.location}"

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
  name                = "web${count.index + 1}-nic"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  count               = 2

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
  name                  = "web${count.index + 1}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  availability_set_id   = "${azurerm_availability_set.avset.id}"
  vm_size               = "${var.vm_size}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  count                 = "${var.vm_count}"

  storage_image_reference {
    id = "/subscriptions/8b4408ad-500e-49e3-a5f3-231f895d8325/resourceGroups/rg-scus-mscafe-images/providers/Microsoft.Compute/images/Win2016ServerImage"
  }
  #storage_image_reference {
  #  publisher = "${var.image_publisher}"
  #  offer     = "${var.image_offer}"
  #  sku       = "${var.image_sku}"
  #  version   = "${var.image_version}"
  #}

  storage_os_disk {
    name              = "web${count.index + 1}-osdisk"
    managed_disk_type = "Premium_LRS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = "${var.hostname}${count.index +1}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  os_profile_windows_config {}
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