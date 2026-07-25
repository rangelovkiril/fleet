terraform {
  # State encryption landed in OpenTofu 1.7.
  required_version = ">= 1.7.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.8.2, < 6.0.0"
    }
  }

  # State is committed to this repository rather than kept in a remote
  # backend. See tofu/README.md.
  backend "local" {
    path = "terraform.tfstate"
  }

  # key_provider.pbkdf2.rampme_state is referenced but never declared here:
  # it arrives through TF_ENCRYPTION so the passphrase stays out of version
  # control. See tofu/README.md.
  encryption {
    method "aes_gcm" "rampme_state" {
      keys = key_provider.pbkdf2.rampme_state
    }

    state {
      method = method.aes_gcm.rampme_state
    }

    plan {
      method = method.aes_gcm.rampme_state
    }
  }
}

# The token comes from CLOUDFLARE_API_TOKEN in the environment.
provider "cloudflare" {}
