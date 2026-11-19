# Identity that GitHub Actions uses to deploy. There is NO password or key:
# GitHub issues a short-lived OIDC token, Entra ID checks it against the
# federated credential below and returns an Azure access token.
#
# A user-assigned managed identity is used instead of an App Registration
# because students usually cannot create App Registrations in the university tenant.
resource "azurerm_user_assigned_identity" "github" {
  name                = "id-${var.project}-github"
  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location
  tags                = var.tags
}

# "Trust policy": only tokens from this repo AND this branch are accepted.
# Pull requests, forks and other branches get a different "subject" and are rejected.
resource "azurerm_federated_identity_credential" "github_main" {
  name                      = "github-${replace(var.github_repository, "/", "-")}-${var.github_branch}"
  user_assigned_identity_id = azurerm_user_assigned_identity.github.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"
}

# NOTE: this identity gets NO roles here. Its permissions (AcrPush on the
# registry, Container Apps Contributor on one app) are granted in
# terraform/main, scoped to exactly those resources.
