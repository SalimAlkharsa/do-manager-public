# do-manager
As code agents got more powerful, I felt more comfortable giving them more autonomy however I did not want them running unrestricted on my personal machine nor did I want to babysit them and keep my laptop on. I decided a cheap disposable VPS was the best solution for my problem. However, I did not want to pay monthly on demand prices so I created this repository to solve my problem.

The general idea is to have a single control plane for spinning up and then destroying boxes. The key feature here is that on every destroy a snapshot of the machine is stored so that my settings transfer across sessions (ie tmux config, git set up, firewalls etc). 

One future improvement on my mind is the ability to use multiple boxes at once for several tasks or configuring the size of the box depending on the task. I have not made such improvements yet because I have not experienced this problem yet. The bigger feature on my mind is the ability to use DO Apps to track issue requests on my GitHub projects and have an autonomous agent try to maintain my projects. I am still thinking through the architecture of that problem and trying to zone in on what quality of life improvement I am going for.

# General Directory
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
encrypted bundle, and stops if that check can't complete.

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

**The bundle is gitignored and must stay out of git.** 
^ Treat this as a light-weight secrets manager (keep in mind I am only using this for low risk projects)!

## The box itself

- The dev user (default `dev`, override with `DEV=`) gets **passwordless
  sudo**. This is a single-user throwaway machine.
- Enabling ufw over SSH is how you lock yourself out, so `provision.sh` arms
  a **dead-man switch**: the firewall disables itself after 5 minutes unless
  you confirm you still have a session (`systemctl stop ufw-deadman.timer`). --> An appropriate TODO is to automate that.
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
