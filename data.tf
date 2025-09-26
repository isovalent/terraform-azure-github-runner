data "azurerm_resource_group" "resource_group" {
  name = var.azure_resource_group_name
}

data "azurerm_client_config" "current" {}
