variable "github_webhook_events_queue_id" {
  type = string
}

variable "app_configuration_endpoint" {
  type = string
}

variable "azure_resource_group_name" {
  type = string
}

variable "azure_resource_group_location" {
  type = string
}

variable "name" {
  type = string
}

variable "docker_registry_url" {
  type = string
}

variable "event_handler_image_name" {
  type = string
}

variable "event_handler_image_tag" {
  type = string
}

variable "azure_secrets_key_vault_resource_id" {
  type = string
}

variable "azure_tenant_id" {
  type = string
}

variable "azure_app_configuration_object_id" {
  type = string
}

variable "tags" {
  description = "Map of tags that will be added to created resources."
  type        = map(string)
  default     = {}
}

variable "log_level" {
  validation {
    condition     = contains(["verbose", "info", "warning", "error"], var.log_level)
    error_message = "log_level must be one of: verbose, info, warning, error"
  }
  type = string
}
