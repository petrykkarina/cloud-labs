# Container logs (stdout/stderr) go here. PerGB2018 is the pay-per-GB tier;
# the first 5 GB per month are free.
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  # Safety cap. Lab 2 logs one line per request (for the p95 latency tile),
  # a 10-minute load test writes roughly 50-100 MB, so the cap is 1 GB/day.
  # The first 5 GB per month are free; the cap protects from a logging loop.
  daily_quota_gb = 1

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Lab 2, task 4: email alert
# ---------------------------------------------------------------------------

# Delivery channel. Azure email needs no subscription confirmation, but
# sends an "added to action group" notice once.
resource "azurerm_monitor_action_group" "email" {
  name                = "ag-${var.project}-email"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "blogalerts" # max 12 chars, shown in SMS/email subject

  # Azure asks every new email address to confirm itself (OTP from a
  # "Verify your email" letter, valid 30 min); until then no alert emails are
  # delivered. A new letter is sent when the action group is saved again.
  email_receiver {
    name                    = "karina-lpnu"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }

  tags = var.tags
}

# Condition: the service hit the autoscaling ceiling (4 replicas).
# At that point autoscaling cannot absorb more load, so a human must look.
# Stateful alert (auto_mitigate): one email "Fired" when it starts and one
# "Resolved" when replicas drop below 4 again. Rationale: docs/ALERTS.md.
resource "azurerm_monitor_metric_alert" "max_replicas" {
  name                = "alert-${var.project}-max-replicas"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_container_app.api.id]
  description         = "Blog API reached the maximum number of replicas (4): autoscaling has no headroom left."
  severity            = 2

  frequency     = "PT1M" # evaluate every minute
  window_size   = "PT1M" # look at the last minute
  auto_mitigate = true   # send "Resolved" when the condition is no longer true

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "Replicas"
    aggregation      = "Maximum"
    operator         = "GreaterThanOrEqual"
    threshold        = 4
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }

  tags = var.tags
}
