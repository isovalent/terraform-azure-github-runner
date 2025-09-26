variable "azure_resource_group_name" {
  type = string
}

variable "azure_location" {
  type = string
}

variable "virtual_networks" {
  description = "Configuration for the virtual network and its subnets."
  type = object({
    name          = string
    address_space = list(string)
    subnets = list(object({
      name     = string
      prefixes = list(string)
    }))
  })
}

variable "tags" {
  description = "Map of tags that will be added to created resources."
  type        = map(string)
  default     = {}
}

variable "name" {
  type = string
}

variable "allow_ssh_inbound" {
  description = "Whether to allow inbound SSH traffic."
  type        = bool
  default     = true
}

variable "public_ip_cidr" {
  description = "The CIDR block for the public IP."
  type        = string
  default     = "127.0.0.1/32"
}
