# One VNet, three subnets:
#   aca      - Container Apps environment (the application)
#   postgres - PostgreSQL Flexible Server only, no public IP
#   appgw    - reserved for Application Gateway (task 4); empty while enable_lb = false
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.20.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "aca" {
  name                 = "snet-aca"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.0.0/24"]

  # Workload-profiles environments require the subnet delegated to Microsoft.App.
  delegation {
    name = "aca"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "postgres" {
  name                 = "snet-postgres"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.2.0/24"]

  delegation {
    name = "postgres"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.3.0/24"]
}

# Firewall for the database subnet.
#
# AWS would say "allow 5432 from the app's security group". Azure Application
# Security Groups attach only to VM network interfaces, and Container Apps has
# no NICs we control. The Azure equivalent is the app's DEDICATED subnet:
# only the Container Apps environment lives in snet-aca, so "source =
# snet-aca" means "source = the application", not an arbitrary IP range.
resource "azurerm_network_security_group" "postgres" {
  name                = "nsg-${var.project}-postgres"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  security_rule {
    name                       = "allow-postgres-from-app-subnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefixes    = azurerm_subnet.aca.address_prefixes
    source_port_range          = "*"
    destination_address_prefix = azurerm_subnet.postgres.address_prefixes[0]
    destination_port_range     = "5432"
  }

  # Overrides Azure's default "AllowVnetInBound" (priority 65000):
  # nothing else in the VNet can reach the database.
  security_rule {
    name                       = "deny-all-other-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "postgres" {
  subnet_id                 = azurerm_subnet.postgres.id
  network_security_group_id = azurerm_network_security_group.postgres.id
}
