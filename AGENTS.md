# fleet - agent & contributor guide

This is the canonical guide for anyone working in this repository, human or AI agent. It is tool-neutral on purpose: `CLAUDE.md` is a symlink to this file, and other agents (Cursor, Codex, and future ones) read `AGENTS.md` directly, so everyone works from the same instructions with no quality drop.

## What is this

`fleet` is the Flux GitOps repository for a single-node k3s cluster on a Hetzner VPS. That cluster runs the RampMe backend: a live public transport map for Sofia whose core feature is wheelchair ramp reservation, a rider near a stop requests a ramp, and hardware on the vehicle deploys it over MQTT when the vehicle arrives.

The system spans three repositories:

- **`fleet`** (this repo) declares everything that runs in the cluster. Flux reconciles the live state to match what is committed here.
- **`rampme-software`** (https://github.com/rangelovkiril/rampme-software) holds the backend and frontend application code. Only the backend runs in this cluster; the frontend is a static site on Cloudflare Pages, outside the cluster entirely.
- **`rampme-hardware`** (https://github.com/rangelovkiril/rampme-hardware) is the Raspberry Pi ramp firmware, reachable only through the ramp MQTT protocol.

See `README.md` for the directory layout and the reconcile chain in more detail.

## Documentation lives in the wiki

The [fleet wiki](https://github.com/rangelovkiril/fleet/wiki) is the authoritative infrastructure documentation: cluster bootstrap, Flux, secrets, Cloudflare account and tunnel identifiers, the backend runtime, and recovery procedures. This file and `README.md` describe the repository and how to work in it; the wiki describes the running system.

> [!IMPORTANT]
> When unsure about anything infrastructure-related, consult the wiki rather than assuming. The [rampme-software wiki](https://github.com/rangelovkiril/rampme-software/wiki) covers the application side (architecture, threat model, the ramp MQTT protocol, contributing) and is worth checking when a change touches both sides of the system.

## Working rules

- **Keep docs in sync with reality, immediately.** If a change alters infrastructure, deployment, configuration, or a documented contract, update the wiki in the same change. Stale docs are the exact problem these files exist to prevent; do not reintroduce it.
- **When unsure, consult the wikis** rather than assuming.
- **Use tools according to availability.** Do not assume a fixed toolchain; adapt to what the environment actually has. Prefer `bunx <pkg>` over a globally installed package.
- **Conventional Commits**, matching the existing history (`feat(scope): ...`, `fix(scope): ...`, `chore(scope): ...`, `refactor: ...`).
- **Branch plus PR is the norm, but the maintainer currently commits directly to `main`.** Ask before committing, and ask again before pushing. Never do either unprompted.
- **Do not hand-edit Flux-managed image tags.** The `# {"$imagepolicy": "rampme:rampme-backend"}` marker in `apps/rampme/backend/deployment.yaml` is owned by the ImageUpdateAutomation controller; a manual edit will be overwritten or conflict with its next commit.
- **Never commit plaintext secrets.** Check every diff to `apps/rampme/backend/secret.yaml`; it must only ever be committed SOPS-encrypted, never with plaintext `stringData`.
- **Do not state a fact that has not been verified.** If something is missing, an exact command, an identifier, a path, say so explicitly and mark it TODO rather than filling it with a plausible guess.

## Tooling (MCP)

`.mcp.json` in the repo root declares four servers. Two need no credentials and should be treated as ordinary tools:

- **`context7`** provides current library documentation, launched through `bunx`. Consult it before writing OpenTofu, Cloudflare provider or Flux configuration from memory; these move faster than model training data and the exact resource and attribute names change between major versions.
- **`cloudflare-docs`** is the public Cloudflare documentation, over HTTP, no authentication.

The other two are account-scoped and reach the live Cloudflare account:

- **`cloudflare-graphql`** returns real traffic analytics, which is what turns WAF rate limits into measurements rather than guesses.
- **`cloudflare-auditlogs`** answers who changed what in the dashboard, which is how configuration drift away from `tofu/` gets attributed.

> [!IMPORTANT]
> Only the maintainer can authorize the account-scoped servers, through an OAuth flow in an interactive session. They are therefore optional, never a prerequisite. Do not stop work, refuse a task, or ask for them to be enabled before starting. Do the part that can be done without them, and where one would genuinely have helped, say which server it was and what question it would have answered, so the choice to enable it is informed rather than a blanket request.

> [!NOTE]
> MCP servers are started by the editor or host, never by an agent. Check what is actually present in the session rather than assuming `.mcp.json` reflects it. When something is missing and it matters, the enabling step is `/mcp` in an interactive Claude Code session. Never fill the gap by guessing at Cloudflare state or presenting a plausible answer as fact.

For local, one-off Cloudflare work outside of MCP, `bunx wrangler login` authenticates the Wrangler CLI.

## Hazards

> [!CAUTION]
> **1. `apps/rampme/backend/secret.yaml` ships `REPLACE_ME` placeholders in plaintext `stringData`.** Real MQTT credentials must be filled in and SOPS-encrypted (`sops -e -i apps/rampme/backend/secret.yaml`) before any commit. Check every diff touching this file.

> [!WARNING]
> **2. Never hand-edit the image tag in `apps/rampme/backend/deployment.yaml`.** The `# {"$imagepolicy": "rampme:rampme-backend"}` marker is managed by Flux's image automation, which commits tag updates back to `main` on its own.

> [!NOTE]
> **3. The tunnel's ingress hostname mapping is not in the Kubernetes manifests.** Reading only the YAML in `infrastructure/controllers/cloudflared` will not reveal that `api.rampme.site` routes to `eg-envoy`. That mapping is declared in OpenTofu, in `tofu/tunnel.tf`, which is applied by hand and never by Flux.

> [!CAUTION]
> **4. The SOPS age private key has no backup.** It exists only on the maintainer's machine. Losing it means every encrypted secret in this repository becomes unrecoverable, including the passphrase in `tofu/encryption.sops.yaml` that decrypts the committed OpenTofu state. It is not something to regenerate or move around casually. Backing it up is tracked as issue #2.
