#!/bin/bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
BUNDLE="${SECRETS_BUNDLE:-$(dirname "$HERE")/secrets.age}"

# SECRETS (and TOOLS) come from box/manifest.sh, which is gitignored — it is
# your machine's inventory, not the tool's. When this script is piped over
# ssh, the caller prepends the manifest to the stream instead.
if [ -z "${SECRETS+x}" ] && [ -f "$HERE/manifest.sh" ]; then
  source "$HERE/manifest.sh"
fi

need_manifest() {
  [ -n "${SECRETS+x}" ] && [ "${#SECRETS[@]}" -gt 0 ] ||
    { echo "no manifest — copy box/manifest.example.sh to box/manifest.sh and edit it" >&2; exit 1; }
}

secrets_missing() {
  local f
  for f in "${SECRETS[@]}"; do [ -s "$f" ] || return 0; done
  return 1
}

# Sourced by provision.sh and down.sh for SECRETS/BUNDLE — stop before the
# dispatch so their own "$@" is never read as a subcommand.
(return 0 2>/dev/null) && return

need_age() {
  command -v age >/dev/null ||
    { echo "age not installed — 'brew install age' or 'apt install age'" >&2; exit 1; }
}

case "${1:-}" in
  push)
    need_manifest
    need_age
    present=()
    for f in "${SECRETS[@]}"; do [ -s "$f" ] && present+=("$f"); done
    [ ${#present[@]} -gt 0 ] ||
      { echo "none of the manifest paths exist here — run push on the droplet" >&2; exit 1; }
    # Write beside the bundle and rename, so a failed push cannot leave an
    # empty secrets.age that still looks real.
    trap 'rm -f "$BUNDLE.new"' EXIT
    tar -cz "${present[@]}" 2>/dev/null | age -p > "$BUNDLE.new"
    mv "$BUNDLE.new" "$BUNDLE"
    chown --reference="$(dirname "$BUNDLE")" "$BUNDLE"
    echo "encrypted ${#present[@]} of ${#SECRETS[@]} files to $BUNDLE"
    echo "fetch it to your laptop and keep it somewhere private and durable — never commit it"
    ;;
  pull)
    need_age
    [ -f "$BUNDLE" ] || { echo "no $BUNDLE" >&2; exit 1; }
    age -d "$BUNDLE" | tar -xz -C /
    echo "restored from $BUNDLE"
    ;;
  verify)
    need_age
    [ -f "$BUNDLE" ] || { echo "no $BUNDLE" >&2; exit 1; }
    # Count into a variable first: in a pipeline the success message would
    # print before bash ever evaluated whether age exited non-zero.
    n=$(age -d "$BUNDLE" | tar -tz | wc -l)
    [ "$n" -gt 0 ] || { echo "bundle decrypted to nothing" >&2; exit 1; }
    echo "passphrase works, $n files readable"
    ;;
  stale)
    need_manifest
    # A missing file makes find exit nonzero; fold that into the same failure
    # path as a modified one so the check can never pass silently.
    out=$(find "${SECRETS[@]}" -newermt "@${2:?timestamp required}" 2>&1) && [ -z "$out" ] ||
      { echo "$out"; exit 1; }
    ;;
  *)
    echo "usage: secrets.sh <push|pull|verify|stale EPOCH>" >&2
    exit 1
    ;;
esac
