variable "prefix" {
  type        = string
  description = "Prefix for all metric and trace names"
}

variable "url" {
  type        = string
  description = "URL to differentiate different clusters"
}

variable "token" {
  type        = string
  description = "Wavefront API token"
}
