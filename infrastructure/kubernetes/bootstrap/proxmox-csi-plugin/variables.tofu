variable "proxmox" {
  type = object({
    cluster_name = string
    endpoint = string
    insecure = bool
  })
}

variable "role_already_exists" {
  type        = bool
  description = "Whether the CSI role already exists."
  default     = false
}

variable "user_already_exists" {
  type        = bool
  description = "Whether the CSI user already exists."
  default     = false
}