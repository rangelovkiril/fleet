resource "cloudflare_ruleset" "ramp_rate_limit" {
  zone_id     = var.zone_id
  name        = "ramp-reservation-rate-limit"
  description = "Per-IP rate limiting on ramp reservation create/cancel, api + api-stage"
  kind        = "zone"
  phase       = "http_ratelimit"

  # This account's plan tier allows exactly 1 rule in the http_ratelimit
  # phase (API error code 50001) and only a 10s period, not 60s ("not
  # entitled to use the period 60, can only use a period among [10]") -
  # neither is documented anywhere checkable beforehand. Create and cancel
  # share one rule/one counter, and 5 requests/10s is the closest available
  # approximation of the original 20-requests-per-60s design threshold.
  rules = [
    {
      description = "Rate limit ramp reservation create/cancel"
      expression  = "(http.host in {\"api.rampme.site\" \"api-stage.rampme.site\"} and ((http.request.uri.path eq \"/ramp/reserve\" and http.request.method eq \"POST\") or (http.request.uri.path wildcard \"/ramp/reserve/*\" and http.request.method eq \"DELETE\")))"
      action      = "block"
      enabled     = true
      ratelimit = {
        characteristics     = ["ip.src", "cf.colo.id"]
        period              = 10
        requests_per_period = 5
        mitigation_timeout  = 60
      }
    },
  ]
}
