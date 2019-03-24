output "hostname" {
  value = "${var.hostname}"
}

output "ilb_fqdn" {
  value = "${azurerm_public_ip.lbpip.fqdn}"
}

output "sqlsvr_fqdn" {
  value = "${azurerm_sql_server.server.fully_qualified_domain_name}"
}

output "VMs RDP access" {
  value = "${formatlist("RDP_URL=%v:%v", azurerm_public_ip.lbpip.fqdn, azurerm_lb_nat_rule.tcp.*.frontend_port)}"
}
