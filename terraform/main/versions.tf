terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.14"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }

  # Remote state in the storage account created by terraform/bootstrap.
  # The state contains the database password, so it must never be in git;
  # in Azure Storage it is protected by RBAC, versioned and locked during apply.
  # If bootstrap is recreated, put its tfstate_storage_account_name output here.
  backend "azurerm" {
    resource_group_name  = "rg-blog-bootstrap"
    storage_account_name = "stblogtfstateq00s5z"
    container_name       = "tfstate"
    key                  = "main.tfstate"
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id

  # Registration is handled by terraform/bootstrap.
  resource_provider_registrations = "none"

  features {}
}
