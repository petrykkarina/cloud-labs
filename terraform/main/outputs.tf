output "public_url" {
  description = "Public address of the API (App Gateway when enable_lb = true)."
  value = (var.enable_lb
    ? "http://${azurerm_public_ip.appgw[0].ip_address}"
  : "https://${azurerm_container_app.api.ingress[0].fqdn}")
}

output "container_app_fqdn" {
  value = azurerm_container_app.api.ingress[0].fqdn
}

output "container_app_name" {
  value = azurerm_container_app.api.name
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}

output "postgres_fqdn" {
  description = "Resolves only inside the VNet (private DNS zone)."
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

# IDs for azure/login in GitHub Actions. Not secrets.
output "github_client_id" {
  value = data.azurerm_user_assigned_identity.github.client_id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  value = var.subscription_id
}
