#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source config.sh
source lib/common.sh

if [ -n "$(droplet_id)" ]; then
  echo "$DROPLET_NAME already up at $(droplet_ip)"
  exit 0
fi

doctl compute droplet create "$DROPLET_NAME" \
  --size "$DROPLET_SIZE" \
  --image "$SNAPSHOT_ID" \
  --region "$REGION" \
  --ssh-keys "$SSH_KEY_ID" \
  --user-data-file box/first-boot.sh \
  --wait >/dev/null

IP=$(droplet_ip)
[ -n "$IP" ] || die "created $DROPLET_NAME but no IP came back"

mkdir -p ~/.ssh/config.d
cat > ~/.ssh/config.d/do-box <<EOF
Host $DROPLET_NAME
  HostName $IP
  User root
  IdentityFile $SSH_KEY_PATH
  UserKnownHostsFile ~/.ssh/known_hosts.do-box
  StrictHostKeyChecking accept-new
EOF

if ! grep -qsF 'Include config.d/do-box' "$SSH_CONFIG"; then
  { echo 'Include config.d/do-box'; cat "$SSH_CONFIG" 2>/dev/null || true; } > "$SSH_CONFIG.new"
  mv "$SSH_CONFIG.new" "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
fi

echo "$DROPLET_NAME up at $IP — ssh $DROPLET_NAME"
