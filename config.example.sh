#!/bin/bash
# Copy to config.sh (gitignored) and fill in your values.

# The image the droplet boots from. For your first box, before any snapshot
# exists, use a distro slug like "ubuntu-24-04-x64"; after your first
# `down.sh` snapshot this becomes a numeric ID that down.sh rewrites for you.
# List yours:  doctl compute snapshot list
SNAPSHOT_ID="ubuntu-24-04-x64"

# The DO ssh key injected for root on create:  doctl compute ssh-key list
SSH_KEY_ID="12345678"

DROPLET_SIZE="s-1vcpu-2gb"
REGION="nyc1"
DROPLET_NAME="dev-box"
SSH_KEY_PATH="~/.ssh/id_ed25519"
SSH_CONFIG="$HOME/.ssh/config"

# Where the encrypted secrets bundle lives on this machine. Defaults to
# ./secrets.age (gitignored). Point it somewhere private and backed up.
# SECRETS_BUNDLE="$HOME/Private/do-box-secrets.age"
