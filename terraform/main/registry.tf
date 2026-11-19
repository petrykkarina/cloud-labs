# Private image registry. Basic is the cheapest tier (~0.17 USD per day).
resource "azurerm_container_registry" "main" {
  name                = "acr${var.project}${local.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"

  # No shared admin username/password: access only through Entra ID roles.
  admin_enabled = false

  tags = var.tags
}

# Identity of the running application: it can only PULL images.
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.project}-app"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "app_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}
