#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source config.sh
source lib/common.sh

BUNDLE="${SECRETS_BUNDLE:-secrets.age}"

ID=$(droplet_id)
[ -n "$ID" ] || { echo "No droplet running."; exit 0; }

confirm "Destroy $DROPLET_NAME ($ID)?" || exit 0

# The manifest is prepended to the piped scripts: they run on the droplet,
# where a gitignored file in this checkout does not exist.
{ cat box/manifest.sh 2>/dev/null || true; cat box/doctor.sh; } | on_box ||
  confirm "doctor failed. Snapshot and destroy anyway?" || exit 1

if [ ! -s "$BUNDLE" ] || [ ! -f box/manifest.sh ]; then
  confirm "no local secrets bundle or manifest — staleness can't be checked. Continue?" || exit 1
else
  cat box/manifest.sh box/secrets.sh | on_box stale "$(mtime "$BUNDLE")" ||
    confirm "Secrets above changed since your local $BUNDLE — run 'secrets.sh push' on the box and fetch it first. Continue?" || exit 1
fi

if confirm "Snapshot first?"; then
  on_box < box/clean.sh
  doctl compute droplet-action power-off "$ID" --wait

  NAME="$DROPLET_NAME-$(date +%Y%m%d-%H%M)"
  doctl compute droplet-action snapshot "$ID" --snapshot-name "$NAME" --wait

  NEW=$(snapshot_id "$NAME")
  [ -n "$NEW" ] || die "snapshot $NAME not found — old snapshot and droplet left intact"

  sed -i.tmp "s/^SNAPSHOT_ID=.*/SNAPSHOT_ID=\"$NEW\"/" config.sh && rm -f config.sh.tmp
  [ "$NEW" = "$SNAPSHOT_ID" ] || doctl compute snapshot delete "$SNAPSHOT_ID" --force
  echo "Snapshot $NAME ($NEW) saved to config.sh."
fi

doctl compute droplet delete "$ID" --force
echo "Destroyed."
