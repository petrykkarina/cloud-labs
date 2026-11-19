# Lab 2, task 5: Redis as a separate container app (NOT managed Azure Cache for
# Redis, which is not in any free tier). Pure cache: no disk, no persistence;
# if the replica restarts the cache is simply empty and fills up again.

resource "random_password" "redis" {
  length  = 32
  special = false
}

resource "azurerm_container_app" "redis" {
  name                         = "ca-${var.project}-redis"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  secret {
    name  = "redis-password"
    value = random_password.redis.result
  }

  # Internal TCP ingress: reachable only from inside the Container Apps
  # environment (our API), never from the internet.
  ingress {
    external_enabled = false
    transport        = "tcp"
    target_port      = 6379
    exposed_port     = 6379

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    # Exactly one replica: several Redis replicas would be separate,
    # unsynchronised caches.
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "redis"
      image  = "docker.io/library/redis:7.4.12-alpine"
      cpu    = 0.25
      memory = "0.5Gi"

      # sh -c is needed so that $REDIS_PASSWORD (from the secret) is expanded.
      command = ["sh", "-c"]
      args = [
        "exec redis-server --requirepass \"$REDIS_PASSWORD\" --save '' --appendonly no --maxmemory 128mb --maxmemory-policy allkeys-lru",
      ]

      env {
        name        = "REDIS_PASSWORD"
        secret_name = "redis-password"
      }
    }
  }

  tags = var.tags
}

locals {
  # Host is the app name, not the ingress FQDN: in an environment that is not
  # internal-only, the "<app>.internal.<domain>" name of a TCP app times out,
  # while the short app name resolves inside the environment and works.
  redis_url = "redis://:${random_password.redis.result}@${azurerm_container_app.redis.name}:6379/0"
}
