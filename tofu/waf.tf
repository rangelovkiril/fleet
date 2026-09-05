resource "cloudflare_ruleset" "ramp_rate_limit" {
  zone_id     = var.zone_id
  name        = "ramp-reservation-rate-limit"
  description = "Per-IP rate limiting on ramp reservation create/cancel, api + api-stage"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [
    {
      description = "Rate limit ramp reservation creation"
      expression  = "(http.host in {\"api.rampme.site\" \"api-stage.rampme.site\"} and http.request.uri.path eq \"/ramp/reserve\" and http.request.method eq \"POST\")"
      action      = "block"
      enabled     = true
      ratelimit = {
        characteristics     = ["ip.src", "cf.colo.id"]
        period              = 60
        requests_per_period = 20
        mitigation_timeout  = 60
      }
    },
    {
      description = "Rate limit ramp reservation cancellation"
      expression  = "(http.host in {\"api.rampme.site\" \"api-stage.rampme.site\"} and http.request.uri.path wildcard \"/ramp/reserve/*\" and http.request.method eq \"DELETE\")"
      action      = "block"
      enabled     = true
      ratelimit = {
        characteristics     = ["ip.src", "cf.colo.id"]
        period              = 60
        requests_per_period = 20
        mitigation_timeout  = 60
      }
    },
  ]
}
