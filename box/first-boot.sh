#!/bin/bash
swapon --show --noheadings | grep -q . && exit 0
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
