output "azure_subnet_id" {
  description = "The ID of the subnet where the runners will be deployed"
  value       = tolist(azurerm_virtual_network.virtual_network.subnet)[0].id
}

output "resource_group_id" {
  description = "The ID of the resource group where the runners will be deployed"
  value       = azurerm_resource_group.runner_resource_group.id
}
