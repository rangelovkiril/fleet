resource "cloudflare_dns_record" "api_rampme_site" {
  zone_id = var.zone_id
  name    = "api"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.rampme_backend.id}.cfargotunnel.com"

  # Proxied so TLS terminates at the edge and the WAF can inspect requests
  # in plaintext. This is why the cluster runs no cert-manager.
  proxied = true

  # Required to be 1 while proxied.
  ttl = 1
}

resource "cloudflare_dns_record" "api_stage_rampme_site" {
  zone_id = var.zone_id
  name    = "api-stage"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.rampme_backend.id}.cfargotunnel.com"

  # Proxied so TLS terminates at the edge and the WAF can inspect requests
  # in plaintext. This is why the cluster runs no cert-manager.
  proxied = true

  # Required to be 1 while proxied.
  ttl = 1
}
