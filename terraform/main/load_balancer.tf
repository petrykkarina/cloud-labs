# Task 4: Application Gateway (L7 load balancer). Created only when enable_lb = true.
#
#   internet -> Public IP -> App Gateway (snet-appgw) -> HTTPS -> internal
#   Container Apps environment (static private IP) -> container
#
# The gateway connects to the environment's private IP and sends the app's
# hostname in the Host header / TLS SNI, so Container Apps routes the request
# to the right app and the backend certificate matches.
locals {
  lb_count = var.enable_lb ? 1 : 0
  appgw = {
    frontend_ip   = "public"
    frontend_port = "http"
    listener      = "http"
    backend_pool  = "aca"
    http_settings = "aca-https"
    probe         = "health"
  }
}

resource "azurerm_public_ip" "appgw" {
  count               = local.lb_count
  name                = "pip-${var.project}-appgw"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_application_gateway" "main" {
  count               = local.lb_count
  name                = "agw-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }

  # Minimum cost: 0 reserved capacity units, scales up to 2 only under load.
  autoscale_configuration {
    min_capacity = 0
    max_capacity = 2
  }

  # Older default TLS policies are retired; pin a supported one.
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  gateway_ip_configuration {
    name      = "gateway"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_ip_configuration {
    name                 = local.appgw.frontend_ip
    public_ip_address_id = azurerm_public_ip.appgw[0].id
  }

  frontend_port {
    name = local.appgw.frontend_port
    port = 80
  }

  http_listener {
    name                           = local.appgw.listener
    frontend_ip_configuration_name = local.appgw.frontend_ip
    frontend_port_name             = local.appgw.frontend_port
    protocol                       = "Http"
  }

  backend_address_pool {
    name         = local.appgw.backend_pool
    ip_addresses = [azurerm_container_app_environment.main.static_ip_address]
  }

  backend_http_settings {
    name                  = local.appgw.http_settings
    protocol              = "Https"
    port                  = 443
    host_name             = azurerm_container_app.api.ingress[0].fqdn
    cookie_based_affinity = "Disabled"
    request_timeout       = 30
    probe_name            = local.appgw.probe
  }

  # Health check on the application endpoint. If /health stops answering 200
  # (app down or database unreachable) the gateway stops sending traffic there.
  probe {
    name                                      = local.appgw.probe
    protocol                                  = "Https"
    path                                      = "/health"
    interval                                  = 30
    timeout                                   = 10
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true

    match {
      status_code = ["200-399"]
    }
  }

  request_routing_rule {
    name                       = "api"
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = local.appgw.listener
    backend_address_pool_name  = local.appgw.backend_pool
    backend_http_settings_name = local.appgw.http_settings
  }

  tags = var.tags
}
