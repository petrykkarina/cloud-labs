# Resource group for everything that must outlive the main infrastructure:
# Terraform remote state and the GitHub Actions identity.
resource "azurerm_resource_group" "bootstrap" {
  name     = "rg-${var.project}-bootstrap"
  location = var.location
  tags     = var.tags
}

# Storage account names are global, 3..24 lowercase letters/digits only.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "tfstate" {
  name                     = "st${var.project}tfstate${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.bootstrap.name
  location                 = azurerm_resource_group.bootstrap.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # cheapest; state is small and versioned below
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false

  blob_properties {
    # Every state write keeps the previous version: a broken state can be restored.
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}
