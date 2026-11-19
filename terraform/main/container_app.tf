resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${var.project}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  logs_destination           = "log-analytics"

  infrastructure_subnet_id = azurerm_subnet.aca.id

  # enable_lb = true: the environment gets only a private IP in the VNet and
  # the Application Gateway becomes the single public entry point.
  # ForceNew: flipping this recreates the environment AND the app.
  internal_load_balancer_enabled = var.enable_lb

  zone_redundancy_enabled = false

  # Only the serverless Consumption profile (no dedicated, always-billed nodes).
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = var.tags
}

resource "azurerm_container_app" "api" {
  name                         = "ca-${var.project}-api"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  # Pull from ACR with the app identity (AcrPull), no registry password.
  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  # Stored encrypted by Container Apps; the container sees it only as an env var.
  secret {
    name  = "database-url"
    value = local.database_url
  }

  secret {
    name  = "redis-url"
    value = local.redis_url
  }

  ingress {
    # "external" = reachable from outside the environment. With enable_lb = true
    # the environment itself is internal, so this means "reachable from the VNet"
    # (i.e. from the Application Gateway), not from the internet.
    external_enabled           = true
    target_port                = 8000
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    # Lab 2, task 1: horizontal autoscaling between 1 and 4 replicas.
    min_replicas = 1
    max_replicas = 4

    # How often KEDA checks the scale rule (seconds).
    polling_interval_in_seconds = 30
    # KEDA cooldown: wait this long after the last active trigger before
    # scaling in. Scale-in between N>1 replicas additionally goes through the
    # Kubernetes HPA 300 s stabilization window. See docs/AUTOSCALING.md.
    cooldown_period_in_seconds = 300

    # On scale-in / new revision the replica gets SIGTERM and up to 30 s to
    # finish in-flight requests (uvicorn --timeout-graceful-shutdown 20).
    termination_grace_period_seconds = 30

    # Add replicas when average CPU across replicas goes above 60% of the
    # requested 0.25 vCPU. Why 60%: see docs/AUTOSCALING.md.
    custom_scale_rule {
      name             = "cpu-60"
      custom_rule_type = "cpu"
      metadata = {
        type  = "Utilization"
        value = "60"
      }
    }

    container {
      name = "api"
      # Placeholder for the very first apply: the real image does not exist
      # until GitHub Actions builds and pushes it. After that CI owns the image
      # (az containerapp update --image ...), so Terraform ignores this field.
      image  = "mcr.microsoft.com/k8se/quickstart:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }

      # Lab 2, task 5: cache-aside for GET /posts.
      env {
        name        = "REDIS_URL"
        secret_name = "redis-url"
      }

      env {
        name  = "CACHE_ENABLED"
        value = tostring(var.cache_enabled)
      }

      env {
        name  = "CACHE_TTL_SECONDS"
        value = tostring(var.cache_ttl_seconds)
      }
    }
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.app_acr_pull]

  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }
}
