# tofu

OpenTofu configuration for the Cloudflare account that fronts RampMe. It declares the parts of the public request path that are not Kubernetes objects, so that they stop existing only as dashboard state.

This directory is not reconciled by Flux. Flux only watches `./clusters/hetzner`, `./infrastructure/controllers`, `./infrastructure/configs` and `./apps` (see the `Kustomization` manifests under `clusters/hetzner/`), so nothing here is ever applied by the cluster. `tofu plan` and `tofu apply` are run by hand.

## What is managed here

- The `rampme-backend` Cloudflare Tunnel and its remotely-managed ingress config (`tunnel.tf`).
- The `api.rampme.site` DNS record that points at the tunnel (`dns.tf`).
- The `rampme` Cloudflare Pages project and its `rampme.site` custom domain attachment (`pages.tf`).

## What is deliberately not managed here

- **WAF rules.** Tracked as issue #1. `cloudflare_ruleset` resources belong in this directory once that work starts. There are effectively no custom WAF rules today.
- **The Pages deployments themselves.** The frontend CI in the `rampme-software` repository publishes to the `rampme` project; this configuration tracks the project and domain settings, not builds or deployments.
- **The in-cluster side of the tunnel**, meaning the `cloudflared` Deployment and the `cloudflared-token` SOPS secret. Those are Kubernetes manifests under `infrastructure/controllers/cloudflared/`.
- **Everything else in the account.** Only the resources listed above are declared. Zone settings, email routing and the rest remain dashboard state.

## State handling

State uses the local backend (`terraform.tfstate`) with OpenTofu's native state and plan encryption, `pbkdf2` key derivation and `aes_gcm` encryption, and the encrypted state file is committed to this repository.

> [!NOTE]
> Committing state is a deliberate choice. The repository's weakest point is disaster recovery, and the only copy of the account's declared state should not live on a single laptop. A remote backend would usually be preferred for team use; with one maintainer, committing the encrypted state keeps a recoverable copy alongside everything else, at the cost of no locking. Two concurrent applies could race and corrupt state, which is the same tradeoff already accepted for the SOPS age key.

The passphrase that decrypts the state is itself encrypted with SOPS for the repository's age recipient, so there is no separate key to keep track of. See "Supplying the state encryption passphrase" below.

## Supplying the API token

The Cloudflare provider reads the token from the `CLOUDFLARE_API_TOKEN` environment variable; it is intentionally not referenced in any `.tf` file.

```sh
export CLOUDFLARE_API_TOKEN="paste the token here"
```

Tokens are created under My Profile, API Tokens, Create Token, Custom token. Each permission is a row of three dropdowns: the category, the permission group, and the access level. Written as `category / group / level`, the rows this configuration needs are:

- `Account / Cloudflare Tunnel / Edit` covers `cloudflare_zero_trust_tunnel_cloudflared` and `cloudflare_zero_trust_tunnel_cloudflared_config`. Some accounts list this group as `Cloudflare One Connector: cloudflared` instead; either is the same thing.
- `Account / Cloudflare Pages / Edit` covers `cloudflare_pages_project` and `cloudflare_pages_domain`.
- `Zone / DNS / Edit` covers `cloudflare_dns_record`.

Under Account Resources include account `128bba3db2913a3022728e0278795ac6`, and under Zone Resources include the specific zone `rampme.site` rather than all zones.

`Zone / Zone / Read` is not required, because `zone_id` is hardcoded in `variables.tf` and no zone lookup happens. Add it only if a plan ever fails resolving the zone.

Use `Read` in place of `Edit` on all three rows for a local token that only ever plans. The token CI holds is a separate one with `Edit`, because CI is the only place that applies.

> [!NOTE]
> A missing scope surfaces as a bare `401 Not authorized` with error code 1001, or a `403` with code 10000, on the API endpoint for the resource being read. Neither mentions permissions, so those errors mean a token scope is missing rather than a resource being absent.

## Supplying the state encryption passphrase

The `pbkdf2` key provider holding the passphrase is intentionally absent from every `.tf` file here. `provider.tf` references `key_provider.pbkdf2.rampme_state` without defining it, and OpenTofu's `TF_ENCRYPTION` environment variable supplies the missing block at run time, merged with the checked-in configuration.

The passphrase itself lives in `encryption.sops.yaml`, encrypted with SOPS for the same age recipient as every other secret in this repository. That is deliberate: it keeps the age key the single root of trust rather than creating a second independent key to escrow. Anyone who can decrypt the cluster secrets can decrypt this, and nobody else can.

Run OpenTofu through `sops exec-env`, which decrypts the file, puts `TF_ENCRYPTION` in the environment of the child process only, and never writes plaintext to disk:

```sh
sops exec-env encryption.sops.yaml 'tofu plan'
sops exec-env encryption.sops.yaml 'tofu apply'
```

> [!WARNING]
> The age private key now protects the OpenTofu state as well as the cluster secrets. Losing it means losing both. The live Cloudflare resources would survive, but regaining management would mean importing every one of them from scratch. Backing up that key is tracked as issue #2.

To set or rotate the passphrase, edit the file through SOPS so the plaintext never touches the working tree:

```sh
sops encryption.sops.yaml
```

The file holds a single key whose value is the key provider block on one line. `key_length` is omitted because 32 is already the `pbkdf2` default and is what `aes_gcm` expects here. The passphrase has a 16 character minimum:

```yaml
TF_ENCRYPTION: 'key_provider "pbkdf2" "rampme_state" { passphrase = "..." }'
```

> [!CAUTION]
> Rotating the passphrase does not re-encrypt the existing state on its own. Change it only alongside a `tofu apply`, or the committed state becomes unreadable by the new passphrase.

## Adding a second maintainer

Add the second person's age public key as an extra recipient in `.sops.yaml` and run `sops updatekeys` over the encrypted files. They can then decrypt the state passphrase and the cluster secrets with their own key, and no passphrase is ever passed between people.

> [!IMPORTANT]
> The state backend, not the key, is what actually blocks a second maintainer. The local backend has no locking, and the state is a committed encrypted blob that git cannot merge. Two people applying in parallel produce a conflict that can only be resolved by discarding one side's work and importing again. Before a second person applies regularly, move the state to a remote backend that supports locking.

## Making changes

Changes go through `.github/workflows/cloudflare.yaml` rather than a local apply. A pull request touching `tofu/` gets a plan in its job summary; merging to `main` runs that exact saved plan behind the manual approval gate on the `production` environment, then commits the resulting state back. Applying the saved plan rather than replanning is what makes the approval meaningful: what runs is what was reviewed.

Running locally still works and is the right thing for exploration:

```sh
sops exec-env encryption.sops.yaml 'tofu plan'
```

Both identifiers the configuration needs, the account id and the zone id, are defaulted in `variables.tf`, so no `-var` is required.

> [!CAUTION]
> A local `tofu apply` bypasses the approval gate and can race the CI apply, because the local backend has no locking. Prefer the pipeline. If a local apply is unavoidable, make sure no workflow run is in flight and commit the resulting state immediately.

CI needs two repository secrets. `SOPS_AGE_KEY` is a dedicated age private key, a different one from the maintainer's, added as a recipient on `tofu/*.sops.yaml` only, so a compromised runner cannot read the cluster secrets. `CLOUDFLARE_API_TOKEN` is a separate token from the local read-only one, carrying Edit rather than Read on the same three permissions, because CI is the only place that applies.

> [!WARNING]
> The tunnel is the dangerous resource. If a plan ever proposes **replacing** `cloudflare_zero_trust_tunnel_cloudflared` rather than updating it in place, do not apply. A replace rotates the tunnel token, and `api.rampme.site` stays down until the `cloudflared-token` secret in `infrastructure/controllers/cloudflared/token-secret.yaml` is re-encrypted with the new token and rolled out.

An unexpected diff usually means the account drifted through the dashboard rather than that the configuration is wrong. Reconcile deliberately: decide which side is correct, and if the dashboard is, edit the `.tf` files to match reality rather than letting an apply overwrite it.

`tofu fmt` and `tofu init -backend=false` followed by `tofu validate` need no credentials and touch nothing remote, so they are safe to run at any time.

## Related documentation

The [fleet wiki Operations page](https://github.com/rangelovkiril/fleet/wiki/Operations) describes the Cloudflare account in the context of the whole request path, including the tunnel identifiers and the parts that live in the cluster instead.
