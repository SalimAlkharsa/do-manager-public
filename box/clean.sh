#!/bin/bash
set -eu

apt-get clean
journalctl --vacuum-size=50M
find /var/log -type f -name '*.gz' -delete
find /var/log -type f -name '*.[0-9]' -delete
rm -rf /root/.cache /home/dev/.cache /home/dev/.npm/_cacache

swapoff -a
rm -f /swapfile

df -h /
