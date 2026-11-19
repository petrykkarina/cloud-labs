variable "subscription_id" {
  description = "Azure subscription ID (kept in terraform.tfvars)."
  type        = string
}

variable "location" {
  description = "Region allowed by the Azure for Students policy."
  type        = string
  default     = "polandcentral"
}

variable "project" {
  description = "Short name used in resource names."
  type        = string
  default     = "blog"
}

variable "enable_lb" {
  description = <<-EOT
    Task 4. true = Application Gateway in front of an INTERNAL Container Apps
    environment (the gateway is the only thing reachable from the internet).
    Costs about 0.25 USD per hour, so it is false by default and enabled only
    for the demo. Changing it RECREATES the Container Apps environment and app.
  EOT
  type        = bool
  default     = false
}

variable "cache_enabled" {
  description = "Lab 2, task 5: switch the Redis cache for GET /posts on/off (new revision)."
  type        = bool
  default     = false
}

variable "cache_ttl_seconds" {
  description = "How long a cached page of posts lives in Redis."
  type        = number
  default     = 30
}

variable "alert_email" {
  description = "Where Azure Monitor alerts are sent (kept in terraform.tfvars)."
  type        = string
}

variable "github_identity_name" {
  description = "Managed identity created by terraform/bootstrap for GitHub Actions."
  type        = string
  default     = "id-blog-github"
}

variable "github_identity_resource_group" {
  type    = string
  default = "rg-blog-bootstrap"
}

variable "tags" {
  description = "Tags added to every resource that supports them."
  type        = map(string)
  default = {
    project    = "cloud-labs"
    owner      = "karina-petryk"
    managed_by = "terraform"
    stack      = "main"
  }
}
