resource "cloudflare_ruleset" "ramp_rate_limit" {
  zone_id     = var.zone_id
  name        = "ramp-reservation-rate-limit"
  description = "Per-IP rate limiting on ramp reservation create/cancel, api + api-stage"
  kind        = "zone"
  phase       = "http_ratelimit"

  # This account's plan tier allows exactly 1 rule in the http_ratelimit
  # phase (confirmed via API error code 50001, not documented anywhere we
  # could check beforehand). Create and cancel share one rule/one counter
  # instead of a rule each, so the 20/min budget below is combined across
  # both, not 20/min per route.
  rules = [
    {
      description = "Rate limit ramp reservation create/cancel"
      expression  = "(http.host in {\"api.rampme.site\" \"api-stage.rampme.site\"} and ((http.request.uri.path eq \"/ramp/reserve\" and http.request.method eq \"POST\") or (http.request.uri.path wildcard \"/ramp/reserve/*\" and http.request.method eq \"DELETE\")))"
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
