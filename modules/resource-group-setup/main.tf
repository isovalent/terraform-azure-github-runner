
resource "azurerm_resource_group" "runner_resource_group" {
  name     = var.azure_resource_group_name
  location = var.azure_location
  tags     = var.tags
}

resource "azurerm_virtual_network" "virtual_network" {
  name                = "${var.virtual_networks.name}-network"
  address_space       = var.virtual_networks.address_space
  location            = azurerm_resource_group.runner_resource_group.location
  resource_group_name = azurerm_resource_group.runner_resource_group.name

  dynamic "subnet" {
    for_each = var.virtual_networks.subnets
    content {
      name             = "${subnet.value.name}-subnet"
      address_prefixes = subnet.value.prefixes
    }
  }

  tags = var.tags
}

resource "azurerm_nat_gateway" "nat_gateway" {
  name                    = "nat-gateway"
  location                = azurerm_resource_group.runner_resource_group.location
  resource_group_name     = azurerm_resource_group.runner_resource_group.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  # Optionally, specify zones for zonal deployment
  # zones = ["1"]
}

resource "azurerm_nat_gateway_public_ip_association" "nat_ip_association" {
  nat_gateway_id       = azurerm_nat_gateway.nat_gateway.id
  public_ip_address_id = azurerm_public_ip.nat_public_ip.id
}

resource "azurerm_public_ip" "nat_public_ip" {
  name                = "nat-gateway-public-ip"
  location            = azurerm_resource_group.runner_resource_group.location
  resource_group_name = azurerm_resource_group.runner_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_subnet_nat_gateway_association" "subnet_nat_association" {
  subnet_id      = tolist(azurerm_virtual_network.virtual_network.subnet)[0].id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
}

resource "azurerm_network_security_group" "nat_network_security_group" {
  name                = "nat-gateway-network-security-group"
  location            = azurerm_resource_group.runner_resource_group.location
  resource_group_name = azurerm_resource_group.runner_resource_group.name
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  subnet_id                 = tolist(azurerm_virtual_network.virtual_network.subnet)[0].id
  network_security_group_id = azurerm_network_security_group.nat_network_security_group.id
}

resource "azurerm_network_security_rule" "allow_ssh_inbound" {
  count = var.allow_ssh_inbound ? 1 : 0

  name                        = "Allow-SSH-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.public_ip_cidr
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nat_network_security_group.name
  resource_group_name         = azurerm_resource_group.runner_resource_group.name
}
