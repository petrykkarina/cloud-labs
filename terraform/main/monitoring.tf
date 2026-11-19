# Container logs (stdout/stderr) go here. PerGB2018 is the pay-per-GB tier;
# the first 5 GB per month are free.
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  # Safety cap: at most 0.15 GB per day (about 4.5 GB a month) stays in the
  # free allowance even if the app starts logging in a loop.
  daily_quota_gb = 0.15

  tags = var.tags
}
