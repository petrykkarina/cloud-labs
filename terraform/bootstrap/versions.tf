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

  # Bootstrap keeps its state LOCALLY on purpose: it creates the storage
  # account that every other Terraform config uses as a remote backend
  # (chicken-and-egg). terraform.tfstate here is git-ignored.
}

provider "azurerm" {
  subscription_id = var.subscription_id

  # azurerm v5 registers no resource providers by default.
  # We list exactly the ones this repo needs (bootstrap + main).
  resource_providers_to_register = [
    "Microsoft.App",
    "Microsoft.Consumption",
    "Microsoft.ContainerRegistry",
    "Microsoft.DBforPostgreSQL",
    "Microsoft.ManagedIdentity",
    "Microsoft.Network",
    "Microsoft.OperationalInsights",
    "Microsoft.Storage",
  ]

  features {}
}
