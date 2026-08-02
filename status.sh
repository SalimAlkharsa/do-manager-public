#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source config.sh
source lib/common.sh

if [ -n "$(droplet_id)" ]; then
  doctl compute droplet list --format ID,Name,PublicIPv4,Status,Memory,Disk --no-header |
    awk -v n="$DROPLET_NAME" '$2 == n'
else
  echo "No droplet running."
fi

echo
doctl compute snapshot list --format ID,Name,Size,Created --no-header |
  awk -v id="$SNAPSHOT_ID" '{print ($1 == id ? "* " : "  ") $0}'

echo
doctl billing history list | head -5
