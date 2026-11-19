output "resource_group_name" {
  value = azurerm_resource_group.bootstrap.name
}

output "tfstate_storage_account_name" {
  value = azurerm_storage_account.tfstate.name
}

output "tfstate_container_name" {
  value = azurerm_storage_container.tfstate.name
}

# The three IDs GitHub Actions needs for azure/login. None of them is a secret.
output "github_client_id" {
  value = azurerm_user_assigned_identity.github.client_id
}

output "tenant_id" {
  value = azurerm_user_assigned_identity.github.tenant_id
}

output "subscription_id" {
  value = var.subscription_id
}

output "github_identity_principal_id" {
  value = azurerm_user_assigned_identity.github.principal_id
}

output "github_identity_name" {
  value = azurerm_user_assigned_identity.github.name
}
