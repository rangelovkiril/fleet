# Deployments are published by the frontend CI in rampme-software. Only the
# project settings and the domain attachment are declared here.

resource "cloudflare_pages_project" "rampme" {
  account_id        = var.account_id
  name              = "rampme"
  production_branch = "main"
}

resource "cloudflare_pages_domain" "rampme_site" {
  account_id   = var.account_id
  project_name = cloudflare_pages_project.rampme.name

  # "name" holds the domain. This resource has no "domain" argument.
  name = "rampme.site"
}
