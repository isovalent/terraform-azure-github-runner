variable "alert_email_address" {
  description = "Email address to send alerts to."
  type        = string
  default     = ""
}

variable "azure_subscription_id" {
  description = "The Subscription ID which the resources are deployed into."
  type        = string
}

variable "azure_resource_group_name" {
  description = "The name of the resource group in which to create the alerts resources."
  type        = string
}

variable "azure_location" {
  description = "The Azure location where the alerts resources should be created."
  type        = string
}

variable "tags" {
  description = "Map of tags that will be added to created resources."
  type        = map(string)
  default     = {}
}
