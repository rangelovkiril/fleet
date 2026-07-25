variable "account_id" {
  description = "Cloudflare account id that owns every resource in this configuration."
  type        = string
  default     = "128bba3db2913a3022728e0278795ac6"
}

variable "zone_id" {
  description = "Zone id for rampme.site."
  type        = string
  default     = "d8c10b1b6e5f98777081ec11b395fe50"
}
