// This file defines the variables used in the Pangolin infrastructure setup

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "client_id" {
  description = "Azure Client ID (Service Principal)"
  type        = string
}

variable "client_secret" {
  description = "Azure Client Secret (Service Principal)"
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "rg-pangolin-vm"
}

variable "location" {
  description = "The Azure location for resources"
  type        = string
  default     = "westeurope"
}

variable "vnet_name" {
  description = "Virtual network name"
  type        = string
  default     = "pangolin-vnet"
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
  default     = "pangolin-subnet"
}

variable "nsg_name" {
  description = "Network security group name"
  type        = string
  default     = "pangolin-nsg"
}

variable "allowed_source_ip4v_addr" {
  description = "Allowed source IPv4 address for SSH access"
  type        = string
  sensitive   = true
}

variable "vm_name" {
  description = "Virtual Machine name"
  type        = string
  default     = "pangolin-vm"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to your public SSH key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vm_size" {
  description = "Size of the Virtual Machine"
  type        = string
  default     = "Standard_B1ms"
}
