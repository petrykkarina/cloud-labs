# Lab 2, task 3: Azure Monitor dashboard (Azure portal -> Dashboard hub).
#
# Tiles (2 columns):
#   Replicas | CPU %
#   Requests per minute | p95 latency (from request logs)
#   5xx responses | Average response time (metric)
#   PostgreSQL CPU % and transactions | notes
#
# Azure Monitor metrics for Container Apps give response time only as
# average/min/max, so p95 is computed with KQL from the JSON request log
# lines that app/main.py writes to stdout (ContainerAppConsoleLogs_CL).

locals {
  app_ns = "microsoft.app/containerapps"
  db_ns  = "microsoft.dbforpostgresql/flexibleservers"

  # aggregationType codes used by the portal: 1 Sum, 2 Min, 3 Max, 4 Avg
  metric_tiles = [
    {
      # Container Apps has no "desired replicas" metric (KEDA/HPA desired count
      # is not exported to Azure Monitor). Closest analogue:
      #   Max per minute ~ desired: counts a replica as soon as it is scheduled,
      #                    i.e. the moment the scaler decided to add it;
      #   Avg per minute ~ actual: how many replicas really served during the minute.
      title = "Replicas: Max (~desired) and Avg (actual) per minute"
      metrics = [
        { id = azurerm_container_app.api.id, ns = local.app_ns, name = "Replicas", agg = 3, label = "Replicas max (~desired)" },
        { id = azurerm_container_app.api.id, ns = local.app_ns, name = "Replicas", agg = 4, label = "Replicas avg (actual)" },
      ]
      filters = []
    },
    {
      title = "CPU % of requested 0.25 vCPU (scale target 60%)"
      metrics = [
        { id = azurerm_container_app.api.id, ns = local.app_ns, name = "CpuPercentage", agg = 4, label = "CPU avg" },
        { id = azurerm_container_app.api.id, ns = local.app_ns, name = "CpuPercentage", agg = 3, label = "CPU max" },
      ]
      filters = []
    },
    {
      title = "Requests per minute"
      metrics = [
        { id = azurerm_container_app.api.id, ns = local.app_ns, name = "Requests", agg = 1, label = "Requests" },
      ]
      filters = []
    },
    {
      title = "5xx responses per minute"
      metrics = [
        { id = azurerm_container_app.api.id, ns = local.app_ns, name = "Requests", agg = 1, label = "5xx" },
      ]
      filters = [{ key = "statusCodeCategory", operator = 0, values = ["5xx"] }]
    },
    {
      title = "Average response time, ms (metric)"
      metrics = [
        { id = azurerm_container_app.api.id, ns = local.app_ns, name = "ResponseTime", agg = 4, label = "Response time avg" },
      ]
      filters = []
    },
    {
      title = "PostgreSQL: CPU % and committed transactions"
      metrics = [
        { id = azurerm_postgresql_flexible_server.main.id, ns = local.db_ns, name = "cpu_percent", agg = 4, label = "DB CPU avg" },
        { id = azurerm_postgresql_flexible_server.main.id, ns = local.db_ns, name = "xact_commit", agg = 1, label = "Transactions" },
      ]
      filters = []
    },
  ]

  p95_query = <<-KQL
    ContainerAppConsoleLogs_CL
    | where ContainerAppName_s == "${azurerm_container_app.api.name}"
    | where Log_s startswith "{\"type\": \"request\""
    | extend r = parse_json(Log_s)
    | summarize p95_ms = percentile(todouble(r.duration_ms), 95) by bin(TimeGenerated, 1m)
    | render timechart
  KQL

  notes = <<-MD
    **Blog API, Lab 2**

    * Scale rule: CPU > **60%** of 0.25 vCPU, replicas **1..4**, polling 30 s, cooldown 300 s
    * Alert: replicas **= 4** (max) -> email, resolved email when < 4
    * No *desired replicas* metric in Container Apps: Max per minute ~ desired, Avg ~ actual
    * p95 tile: KQL over app request logs (ContainerAppConsoleLogs_CL)
  MD

  tile_position = [for i in range(8) : { x = (i % 2) * 6, y = floor(i / 2) * 4, colSpan = 6, rowSpan = 4 }]

  # Grid slot of each metric tile; slot 3 = p95 logs tile, slot 7 = notes.
  metric_slots = [0, 1, 2, 4, 5, 6]

  metric_parts = [
    for i, t in local.metric_tiles : jsonencode({
      position = local.tile_position[local.metric_slots[i]]
      metadata = {
        inputs = [
          {
            name       = "options"
            isOptional = true
            value = {
              chart = {
                metrics = [for m in t.metrics : {
                  resourceMetadata    = { id = m.id }
                  name                = m.name
                  aggregationType     = m.agg
                  namespace           = m.ns
                  metricVisualization = { displayName = m.label }
                }]
                title            = t.title
                titleKind        = 2
                filterCollection = { filters = t.filters }
                visualization = {
                  chartType           = 2
                  legendVisualization = { isVisible = true, position = 2, hideSubtitle = false }
                  axisVisualization = {
                    x = { isVisible = true, axisType = 2 }
                    y = { isVisible = true, axisType = 1 }
                  }
                }
              }
            }
          },
          { name = "sharedTimeRange", isOptional = true },
        ]
        type     = "Extension/HubsExtension/PartType/MonitorChartPart"
        settings = {}
      }
    })
  ]

  p95_part = jsonencode({
    position = local.tile_position[3]
    metadata = {
      inputs = [
        { name = "resourceTypeMode", isOptional = true },
        { name = "ComponentId", isOptional = true },
        { name = "Scope", isOptional = true, value = { resourceIds = [azurerm_log_analytics_workspace.main.id] } },
        { name = "PartId", isOptional = true, value = "p95-latency" },
        { name = "Version", isOptional = true, value = "2.0" },
        { name = "TimeRange", isOptional = true },
        { name = "DashboardId", isOptional = true },
        { name = "DraftRequestParameters", isOptional = true },
        { name = "Query", isOptional = true, value = local.p95_query },
        { name = "ControlType", isOptional = true, value = "FrameControlChart" },
        { name = "SpecificChart", isOptional = true, value = "Line" },
        { name = "PartTitle", isOptional = true, value = "p95 latency, ms (request logs)" },
        { name = "PartSubTitle", isOptional = true, value = azurerm_log_analytics_workspace.main.name },
        {
          name       = "Dimensions"
          isOptional = true
          value = {
            xAxis       = { name = "TimeGenerated", type = "datetime" }
            yAxis       = [{ name = "p95_ms", type = "real" }]
            splitBy     = []
            aggregation = "Sum"
          }
        },
        { name = "LegendOptions", isOptional = true, value = { isEnabled = true, position = "Bottom" } },
        { name = "IsQueryContainTimeRange", isOptional = true, value = false },
      ]
      type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
      settings = {
        content = {
          PartTitle    = "p95 latency, ms (request logs)"
          PartSubTitle = "percentile(duration_ms, 95) per minute"
        }
      }
    }
  })

  notes_part = jsonencode({
    position = local.tile_position[7]
    metadata = {
      inputs = []
      type   = "Extension/HubsExtension/PartType/MarkdownPart"
      settings = {
        content = {
          settings = { content = local.notes, title = "Notes", subtitle = "", markdownSource = 1 }
        }
      }
    }
  })

  parts_json = join(",", concat(
    [for i, p in local.metric_parts : "\"${local.metric_slots[i]}\": ${p}"],
    ["\"3\": ${local.p95_part}", "\"7\": ${local.notes_part}"],
  ))

  dashboard_metadata = jsonencode({
    model = {
      timeRange = {
        value = { relative = { duration = 1, timeUnit = 2 } } # last 1 hour
        type  = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
      }
      filterLocale = { value = "en-us" }
      filters = {
        value = {
          MsPortalFx_TimeRange = {
            model           = { format = "local", granularity = "1m", relative = "60m" }
            displayCache    = { name = "Local Time", value = "Past hour" }
            filteredPartIds = []
          }
        }
      }
    }
  })
}

resource "azurerm_portal_dashboard" "main" {
  name                = "dash-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = merge(var.tags, { "hidden-title" = "Blog API: autoscaling, load, errors" })

  dashboard_properties = "{\"lenses\": {\"0\": {\"order\": 0, \"parts\": {${local.parts_json}}}}, \"metadata\": ${local.dashboard_metadata}}"
}
