variable "subscription_id" {
  description = "Azure subscription ID (not a secret, but kept in terraform.tfvars)."
  type        = string
}

variable "location" {
  description = "Region. Azure for Students policy allows only a few EU regions."
  type        = string
  default     = "polandcentral"
}

variable "project" {
  description = "Short name used in resource names."
  type        = string
  default     = "blog"
}

variable "github_repository" {
  description = "owner/repo that is allowed to log in to Azure via OIDC."
  type        = string
  default     = "petrykkarina/cloud-labs"
}

variable "github_branch" {
  description = "Only workflows running on this branch can get an Azure token."
  type        = string
  default     = "main"
}

variable "budget_email" {
  description = "Where budget alerts are sent."
  type        = string
}

variable "budget_amount" {
  description = "Monthly subscription budget in USD. Alerts fire at 10, 25 and 50 USD."
  type        = number
  default     = 50
}

variable "budget_start_date" {
  description = "First day of the month the budget starts (RFC3339)."
  type        = string
  default     = "2026-11-01T00:00:00Z"
}

variable "tags" {
  description = "Tags added to every resource."
  type        = map(string)
  default = {
    project    = "cloud-labs"
    owner      = "karina-petryk"
    managed_by = "terraform"
    stack      = "bootstrap"
  }
}
