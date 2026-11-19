# GitHub Actions identity (created in terraform/bootstrap) gets the minimum it
# needs to deploy, each role scoped to ONE resource, not the whole subscription:
#   AcrPush                    on the registry      -> push new images
#   Container Apps Contributor on this Container App -> switch it to the new image
# It cannot touch the database, network, other apps or anything else.
data "azurerm_user_assigned_identity" "github" {
  name                = var.github_identity_name
  resource_group_name = var.github_identity_resource_group
}

resource "azurerm_role_assignment" "github_acr_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "github_container_app" {
  scope                = azurerm_container_app.api.id
  role_definition_name = "Container Apps Contributor"
  principal_id         = data.azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}
