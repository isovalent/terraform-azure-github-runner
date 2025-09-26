data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "resource_group" {
  name = var.azure_resource_group_name
}

data "azurerm_subscription" "primary" {
  subscription_id = var.azure_subscription_id
}

resource "azurerm_monitor_action_group" "isovalent_alerts" {
  name                = "isovalent-runners-alerts"
  resource_group_name = data.azurerm_resource_group.resource_group.name
  location            = data.azurerm_resource_group.resource_group.location
  short_name          = "isorunalerts"

  email_receiver {
    name          = "sendtoadmin"
    email_address = var.alert_email_address
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "quota_alerts" {
  name                 = "vcpu-low-quota-alert"
  resource_group_name  = data.azurerm_resource_group.resource_group.name
  location             = data.azurerm_resource_group.resource_group.location
  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"
  scopes = [
    data.azurerm_subscription.primary.id,
  ]
  severity                = 2
  description             = "Quota Usage Alert Rule >=85%"
  display_name            = "Quota Usage Alert Rule"
  enabled                 = true
  auto_mitigation_enabled = true
  criteria {
    query                   = <<-QUERY
    arg("").QuotaResources
        | where subscriptionId =~ '${var.azure_subscription_id}'
        | where type =~ 'microsoft.compute/locations/usages'
        | where isnotempty(properties)
        | mv-expand propertyJson = properties.value limit 400
        | extend
        usage = propertyJson.currentValue,
        quota = propertyJson.['limit'],
        quotaName = tostring(propertyJson.['name'].value)
        | extend usagePercent = toint(usage)*100 / toint(quota)| project-away properties| where quotaName in~ ('Standard NCASv3_T4 Family')
      QUERY
    time_aggregation_method = "Maximum"
    threshold               = 85
    operator                = "GreaterThanOrEqual"

    metric_measure_column = "usagePercent"
    dimension {
      name     = "location"
      operator = "Include"
      values   = ["*"]
    }
    dimension {
      name     = "quotaName"
      operator = "Include"
      values   = ["Standard NCASv3_T4 Family"]
    }
    dimension {
      name     = "type"
      operator = "Include"
      values   = ["microsoft.compute/locations/usages"]
    }
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.isovalent_alerts.id]
  }

  identity {
    type = "SystemAssigned"
  }
}


resource "azurerm_monitor_activity_log_alert" "vm_creation_alert" {
  name                = "vm-creation-alert"
  resource_group_name = data.azurerm_resource_group.resource_group.name
  location            = "Global" # Activity Log Alerts are global
  description         = "Alert when a new VM is created"

  scopes = [
    data.azurerm_subscription.primary.id,
  ]

  criteria {
    operation_name = "Microsoft.Compute/virtualMachines/write" # This operation corresponds to VM creation/update
    category       = "Administrative"
    resource_type  = "Microsoft.Compute/virtualMachines"
  }

  action {
    action_group_id = azurerm_monitor_action_group.isovalent_alerts.id
  }
}
