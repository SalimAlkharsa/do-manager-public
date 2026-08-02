# do-manager

A disposable DigitalOcean dev box. Spin a droplet up from a snapshot, work on
it, destroy it. Billing is per-second, so you only pay for active time; the
snapshot sits at rest for pennies. A 3-hour session costs about a nickel
instead of $12/month for a box that idles.

The catch with ephemeral machines is state: the moment you tear one down is
exactly the moment you're tired and forget the uncommitted repo, the token
that only lives on that disk, the firewall rule that never made it into the
image. This tool automates the loop — and, more importantly, **refuses to
tear down a box in a state you'd regret**. You can't remember the checklist,
so the box asserts it.

`up.sh` / `down.sh` / `status.sh` run on your laptop. `box/` runs on the
droplet (the snapshot carries a checkout of this repo).

## Daily use

```bash
./up.sh          # create from snapshot, write ~/.ssh/config.d/do-box
ssh dev-box
./down.sh        # doctor → secrets staleness check → optional snapshot → destroy
```

## What down.sh refuses to do

Before anything is destroyed, `box/doctor.sh` runs on the droplet and fails
teardown if:

- any repo under the dev user's home has uncommitted or unpushed work
- any file in your secrets manifest is missing or empty
- any tool you listed has fallen off the PATH (`gh` must also be authenticated)
- swap is off, the firewall is down, or port 22 isn't allowed
- a reboot is pending (you'd snapshot a half-updated box)

Then it asks the droplet whether any secret is **newer** than your local
encrypted bundle, and stops if that check can't complete — staleness is the
failure that would otherwise be silent, so it fails closed.

## Snapshot safety

The new snapshot is created and verified to exist before the old one is
deleted. If the new ID doesn't come back, nothing is deleted and the droplet
stays up. `down.sh` rewrites `SNAPSHOT_ID` in your `config.sh`.

## Setup

Prerequisites: [`doctl`](https://docs.digitalocean.com/reference/doctl/)
authenticated, [`age`](https://github.com/FiloSottile/age), an SSH key
uploaded to DigitalOcean.

```bash
cp config.example.sh config.sh              # your droplet settings
cp box/manifest.example.sh box/manifest.sh  # your secrets + tools inventory
```

Both copies are gitignored: `config.sh` is per-machine state that `down.sh`
rewrites, and the manifest is a map of where your credentials live — neither
belongs in a public fork.

**First box (no snapshot yet):** set `SNAPSHOT_ID` to a distro slug like
`ubuntu-24-04-x64`, run `./up.sh`, then on the box: create your dev user,
install your toolchain, clone this repo, and run `bash box/provision.sh`.
Back up secrets with `bash box/secrets.sh push`, fetch the bundle to your
laptop, and run `./down.sh` — its snapshot step turns `SNAPSHOT_ID` into a
real snapshot ID. Every later boot starts from that image.

## Secrets

The `SECRETS` array in `box/manifest.sh` is the manifest: ssh keys, tokens,
`.env` files. On the box, `push` tars them and encrypts with `age -p`;
`pull` restores them, so one passphrase bootstraps a fresh box from a bare
image. `provision.sh` only pulls when a manifest file is actually missing,
so re-running it on a healthy box never prompts.

```bash
bash box/secrets.sh push      # on the box, when a secret changes
scp dev-box:do-manager/secrets.age .   # then fetch it to your laptop
bash box/secrets.sh verify    # rehearse the passphrase without extracting
```

**The bundle is gitignored and must stay out of git.** A published ciphertext
can be brute-forced offline forever and can never be un-published. Keep
`secrets.age` somewhere private with its own durability story (set
`SECRETS_BUNDLE` in `config.sh` to point at it) — that store, and the
passphrase in your head, are the real single points of failure.

**There is no recovery.** `age` has no escrow: lose the passphrase and the
bundle is permanently unreadable.

`push` and `pull` need a real terminal — `age -p` reads `/dev/tty` and
rejects piped input, so the passphrase can't be supplied by a script or
captured in a log.

## The box itself

- The dev user (default `dev`, override with `DEV=`) gets **passwordless
  sudo**. This is a single-user throwaway machine, not a hardened server —
  the firewall and your SSH key are the boundary. Don't reuse this setup for
  anything shared.
- Enabling ufw over SSH is how you lock yourself out, so `provision.sh` arms
  a **dead-man switch**: the firewall disables itself after 5 minutes unless
  you confirm you still have a session (`systemctl stop ufw-deadman.timer`).
- `clean.sh` strips caches, logs, and the swapfile (~5GB) before snapshotting;
  `first-boot.sh` recreates swap via cloud-init on every create.
- `provision.sh` normalizes a box that already has your toolchain on it — a
  repair script, not a from-scratch bootstrap.

## Extending

Drop your own scripts in `box/files/local/` (gitignored) and `provision.sh`
installs them to `/usr/local/bin` — see `examples/` for a split-tunnel VPN
wrapper. List them in `TOOLS` in the manifest and `doctor.sh` will assert
they survive every snapshot.

## Costs

| | |
|---|---|
| Droplet running | $0.018/hr, $12/mo cap |
| Snapshot at rest | $0.06/GiB/mo |
| 3hr session | ~$0.05 |

## License

MIT
