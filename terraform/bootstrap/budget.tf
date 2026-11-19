data "azurerm_subscription" "current" {}

# The first thing a cloud account needs: a budget with email alerts.
# Budgets do NOT stop resources; they only notify. Azure evaluates costs
# a few times a day, so an alert can arrive hours after the spend.
resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "budget-${var.project}-monthly"
  subscription_id = data.azurerm_subscription.current.id
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  dynamic "notification" {
    # 10, 25 and 50 USD of a 50 USD budget = 20%, 50% and 100%.
    for_each = [10, 25, 50]
    content {
      enabled        = true
      threshold      = notification.value / var.budget_amount * 100
      threshold_type = "Actual"
      operator       = "GreaterThanOrEqualTo"
      contact_emails = [var.budget_email]
    }
  }

  lifecycle {
    # Azure may normalise the start date; do not fight it on every plan.
    ignore_changes = [time_period]
  }
}
