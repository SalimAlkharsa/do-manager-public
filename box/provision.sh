#!/bin/bash
set -euo pipefail
[ "$EUID" = 0 ] || exec sudo "$0" "$@"
cd "$(dirname "$0")"
DEV="${DEV:-dev}"

id "$DEV" >/dev/null 2>&1 ||
  { echo "user $DEV does not exist — create it before provisioning" >&2; exit 1; }

usermod -aG sudo "$DEV"
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$DEV" > /etc/sudoers.d/10-devbox
chmod 440 /etc/sudoers.d/10-devbox

cat > /etc/profile.d/devbox.sh <<'EOF'
export PATH="$HOME/.local/bin:$HOME/.local/node/bin:$PATH"
EOF

install -m644 files/tmux.conf /etc/tmux.conf

# Anything you drop in files/local/ (gitignored) lands on the box's PATH —
# VPN wrappers, site-specific helpers. See examples/ for starting points.
for f in files/local/*; do
  [ -f "$f" ] && install -m755 "$f" /usr/local/bin/
done

apt-get install -y age

source secrets.sh
need_manifest
if [ ! -f "$BUNDLE" ]; then
  echo "no secrets.age yet — create it with: bash $PWD/secrets.sh push"
elif secrets_missing; then
  bash secrets.sh pull
fi

bash first-boot.sh
grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab

systemd-run --on-active=5min --unit=ufw-deadman ufw disable >/dev/null

ufw allow 22/tcp
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

echo "ufw on. It disables itself in 5min unless you confirm you still have SSH:"
echo "  systemctl stop ufw-deadman.timer"

bash doctor.sh
