# Free-plan Bot Fight Mode. Zone-wide, no per-route scoping available at
# this plan tier — Bot Fight Mode runs outside the Ruleset Engine, so no
# skip/custom rule can exempt /ramp/* from it (Super Bot Fight Mode, Pro
# plan, supports that; tracked as a deferred upgrade in fleet#17).
#
# Accepted risk: Cloudflare's own docs say Bot Fight Mode "may challenge
# API or mobile app traffic," which could in principle hit /ramp/reserve.
# Mitigated operationally, not architecturally: verify the live
# reservation flow immediately after this applies, and roll back by
# flipping fight_mode to false if it interferes — see
# rampme-software's openspec/changes/cloudflare-bot-mitigation.
resource "cloudflare_bot_management" "ramp" {
  zone_id    = var.zone_id
  fight_mode = true
}
