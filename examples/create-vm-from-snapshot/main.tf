provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"

  version = "=1.23.0"
}

data "azurerm_snapshot" "search" {
  name                = "${var.snapshot_name}"
  resource_group_name = "${var.snapshot_resource_group}"
}

output "snapshot_id" {
  value = "${data.azurerm_snapshot.search.id}"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.resource_group}-${var.environment}"
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
  allocation_method            = "Dynamic"
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
  name                 = "sn-${var.rg_prefix}-internal"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "${var.subnet_prefix}"
}

resource "azurerm_lb" "lb" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  name                = "ilb-${var.rg_prefix}-${var.environment}-web"
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
  count                          = 1 
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
  count               = 1

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

resource "azurerm_managed_disk" "copy" {
  count                 = "2"
  name                  = "${var.environment}-${var.hostname}${count.index + 1}-osdisk"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  storage_account_type  = "Premium_LRS"
  create_option         = "Copy"
  source_resource_id    = "${data.azurerm_snapshot.search.id}"
  disk_size_gb          = "127"

  tags {
    environment = "${var.environment}"
  }
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "${var.environment}-${var.hostname}${count.index + 1}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  availability_set_id   = "${azurerm_availability_set.avset.id}"
  vm_size               = "${var.vm_size}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  count                 = "2"

    tags {
      environment = "${var.environment}"
    }

  storage_os_disk {
    name              = "${var.environment}-${var.hostname}${count.index + 1}-osdisk"
    os_type           = "Windows"
    managed_disk_id   = "${azurerm_managed_disk.copy.id}"
    caching           = "ReadWrite"
    create_option     = "Attach"
  }
}