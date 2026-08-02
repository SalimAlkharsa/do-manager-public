die() { echo "$*" >&2; exit 1; }

confirm() { read -rp "$1 (yes/no): " r; [ "$r" = yes ]; }

mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null; }

droplet_id() {
  doctl compute droplet list --format ID,Name --no-header |
    awk -v n="$DROPLET_NAME" '$2 == n {print $1}'
}

droplet_ip() {
  doctl compute droplet list --format Name,PublicIPv4 --no-header |
    awk -v n="$DROPLET_NAME" '$1 == n {print $2}'
}

snapshot_id() {
  doctl compute snapshot list --format ID,Name --no-header |
    awk -v n="$1" '$2 == n {print $1}'
}

on_box() { ssh -o ConnectTimeout=10 "$DROPLET_NAME" bash -s -- "$@"; }
