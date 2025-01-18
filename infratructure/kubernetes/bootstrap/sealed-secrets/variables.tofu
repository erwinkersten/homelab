variable "certificate" {
  type = object({
    cert = string
    key = string
  })
}
