#!/bin/bash
DEV="${DEV:-dev}"
fail=0
check() {
  if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}

check "$DEV in sudo group"      "id -nG $DEV | grep -qw sudo"
check "$DEV can sudo"           "sudo -u $DEV sudo -n true"
check "swap active"             'swapon --show --noheadings | grep -q .'
check "firewall active"         'ufw status | grep -q "Status: active"'
check "ssh not firewalled off"  'ufw status | grep -q "^22/tcp .*ALLOW"'
check "tmux config installed"   '[ -f /etc/tmux.conf ]'
check "no pending reboot"       '[ ! -f /var/run/reboot-required ]'

# SECRETS/TOOLS come from box/manifest.sh when run from a checkout; a caller
# piping this script over ssh prepends the manifest to the stream instead.
if [ -z "${SECRETS+x}" ]; then
  d="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
  [ -f "$d/manifest.sh" ] && source "$d/manifest.sh"
fi

if [ -n "${TOOLS+x}" ]; then
  for t in "${TOOLS[@]}"; do
    check "$t on $DEV PATH" "sudo -iu $DEV command -v $t"
  done
  case " ${TOOLS[*]} " in
    *" gh "*) check "gh authenticated" "sudo -iu $DEV gh auth status" ;;
  esac
fi

if [ -n "${SECRETS+x}" ] && [ "${#SECRETS[@]}" -gt 0 ]; then
  for f in "${SECRETS[@]}"; do
    check "secret ${f#/}" "[ -s $f ]"
  done
else
  echo "FAIL secrets manifest missing — nothing asserts your keys exist"
  fail=1
fi

if ! dirty=$(sudo -u "$DEV" -H bash -c '
for g in "$HOME"/*/.git; do
  [ -d "$g" ] || continue
  d=${g%/.git}
  n=${d##*/}
  git -C "$d" remote get-url origin >/dev/null 2>&1 || { echo "$n: no remote"; continue; }
  [ -z "$(git -C "$d" status --porcelain)" ] || echo "$n: uncommitted changes"
  git -C "$d" fetch -q origin 2>/dev/null
  [ -z "$(git -C "$d" log --branches --not --remotes --oneline)" ] || echo "$n: unpushed commits"
done'); then
  echo "FAIL repo check did not run"
  fail=1
elif [ -n "$dirty" ]; then
  echo "$dirty" | sed 's/^/FAIL /'
  fail=1
else
  echo "ok   all repos clean and pushed"
fi

exit $fail
