# A plan that replaces this tunnel rather than updating it rotates the
# tunnel token and takes api.rampme.site down until the cloudflared-token
# secret is re-encrypted and rolled out. Do not apply such a plan.

resource "cloudflare_zero_trust_tunnel_cloudflared" "rampme_backend" {
  account_id = var.account_id
  name       = "rampme-backend"

  # Ingress lives in Cloudflare, declared below, not in a config.yaml on the
  # origin.
  config_src = "cloudflare"

  # tunnel_secret applies only to locally-managed tunnels. This one
  # authenticates with a token, held in the cluster as cloudflared-token.
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "rampme_backend" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.rampme_backend.id

  config = {
    ingress = [
      {
        hostname = "api.rampme.site"
        service  = "http://eg-envoy.envoy-gateway-system.svc.cluster.local:80"
      },
      # Stage backend. Same Envoy Gateway Service as production; the
      # rampme-api-stage listener there does the host-based routing to
      # backend-stage.
      {
        hostname = "api-stage.rampme.site"
        service  = "http://eg-envoy.envoy-gateway-system.svc.cluster.local:80"
      },
      # A remotely-managed config is rejected without a trailing catch-all.
      {
        service = "http_status:404"
      },
    ]
  }
}
