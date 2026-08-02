# examples/

Optional pieces that are useful but not part of the core loop.

Anything here (or any script of your own) can be dropped into `box/files/local/`
— which is gitignored — and `provision.sh` will install it to `/usr/local/bin`
on the box. Add matching entries to `TOOLS` in `box/manifest.sh` if you want
`doctor.sh` to assert it survived the snapshot.

| File | What it is |
|---|---|
| `split-vpn` | Split-tunnel openconnect wrapper (e.g. a university VPN). Only listed subnets route over the tunnel, so the SSH session that starts it survives. Password/MFA prompts happen interactively. |
