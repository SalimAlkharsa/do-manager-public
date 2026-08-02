#!/bin/bash
# Copy to box/manifest.sh (gitignored) and make it yours. This file is the
# inventory of your box: it is deliberately not committed, because it maps
# exactly where your credentials live.

# Files secrets.sh backs up into the encrypted bundle, and doctor.sh asserts
# exist before teardown. Absolute paths on the droplet.
SECRETS=(
  /root/.ssh/id_ed25519
  /home/dev/.ssh/id_ed25519
  /home/dev/.config/gh/hosts.yml
  /home/dev/.gitconfig
  /home/dev/myproject/.env
)

# Commands doctor.sh asserts are on the dev user's PATH. If "gh" is listed,
# doctor also asserts it is authenticated.
TOOLS=(node gh)
