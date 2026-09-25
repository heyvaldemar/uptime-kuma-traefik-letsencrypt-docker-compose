# Uptime Kuma + Traefik + Let's Encrypt on Docker Compose

[![Deployment Verification](https://github.com/heyvaldemar/uptime-kuma-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/uptime-kuma-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/14857/badge)](https://www.bestpractices.dev/projects/14857)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This repository deploys Uptime Kuma (self-hosted monitoring for HTTP, TCP, ping, DNS, keyword and certificate-expiry checks, with status pages and ninety notification channels) behind Traefik with automatic Let's Encrypt TLS, with scheduled backups of everything it knows and a companion restore script.

## Getting started

```bash
# 1. Clone
git clone https://github.com/heyvaldemar/uptime-kuma-traefik-letsencrypt-docker-compose
cd uptime-kuma-traefik-letsencrypt-docker-compose

# 2. Create the two Docker networks the stack expects
docker network create traefik-network
docker network create uptime-kuma-network

# 3. Copy the environment template and fill in required values
cp .env.example .env
$EDITOR .env
# ^ Required: UPTIME_KUMA_HOSTNAME, TRAEFIK_HOSTNAME,
#   TRAEFIK_ACME_EMAIL, TRAEFIK_BASIC_AUTH.

# 4. Deploy
docker compose -f uptime-kuma-traefik-letsencrypt-docker-compose.yml -p uptime-kuma up -d
```

**Open the site and create the administrator account immediately.** Uptime Kuma has no credentials until the first account exists, and it hands that account to whoever reaches the setup page first. The dashboard is a map of the infrastructure it watches.

### What success looks like

```bash
docker compose -f uptime-kuma-traefik-letsencrypt-docker-compose.yml -p uptime-kuma ps
curl -sk "https://${UPTIME_KUMA_HOSTNAME}/api/entry-page"
# Expected on a fresh deployment: {"type":"setup-database"}
```

`ps` shows `uptime-kuma` and `traefik` healthy, and `backups` running with no health check of its own.

### Common first-deploy issues

- **The dashboard is reachable and asks nobody for a password.** That is not a bug, that is the first-run state. Register before somebody else does.
- **Cert issuance fails.** DNS has not propagated, or port 80 is not reachable from the internet.
- **Networks not found.** Step 2 was skipped.
- **A monitor cannot resolve a container by name.** Uptime Kuma reaches a container by hostname only on a network it shares. Put it on that network, or use the Docker Container monitor type, which asks the daemon instead — and see the note below before mounting the socket.

## Probing from inside is the point

Attaching this stack to the network of the thing it watches lets a monitor probe `http://service:port` directly rather than going out to the public hostname and back. That distinction is worth having: an internal probe separates "the application died" from "the tunnel died", and those are very different evenings.

An external probe through the public name is still worth keeping for one or two services, because it is the only check that exercises the certificate and the proxy chain. Both kinds, not one.

## The Docker socket, deliberately not mounted

Uptime Kuma's Docker Container monitor type asks the daemon whether a container is healthy, which is the only way to watch something that has no HTTP endpoint at all — a bare database, a queue.

It needs `/var/run/docker.sock` mounted, and this template does not mount it. `:ro` on a Docker socket is cosmetic: the API is root-equivalent, and anything that can talk to it can start a privileged container. Adding it is a deliberate decision, and it belongs to whoever accepts that this dashboard now has root on the host:

```yaml
    volumes:
      - uptime-kuma-data:/app/data
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

If you add it, put the dashboard behind an identity proxy rather than a password form.

## Updating

`./update.sh` moves this checkout to the latest release tag — a combination this repository's CI has booted, upgraded from the previous release on the same volumes, and smoke-tested — and then runs `docker compose up -d`. It refuses to cross a major version unattended, refuses to run over local changes, and names any variable that became required since your version before anything has moved. `./update.sh --dry-run` says what would happen. Every release cut by fleet triage also carries what upstream changed, read from its release notes against this compose file.

## Supply chain trust

Three images pinned to `tag@sha256:<digest>` as interpolation defaults in the compose `x-images` block:

- [`louislam/uptime-kuma`](https://hub.docker.com/r/louislam/uptime-kuma): the application, latest stable (2.5.5)
- [`traefik`](https://hub.docker.com/_/traefik): reverse proxy
- [`alpine`](https://hub.docker.com/_/alpine): the backups sidecar, which needs tar and nothing else

`git pull` alone delivers the tested combination; an `*_IMAGE_TAG` variable in `.env` overrides deliberately.

Two override levels exist per image. `<PREFIX>_IMAGE_VERSION` in `.env` swaps only the version of that image (Compose then pulls the tag, without a digest) and leaves every other pin as tested; `<PREFIX>_IMAGE_TAG` replaces the whole reference, digest included. Nested defaults need Docker Compose v2.5 or newer (2022).

The daily `check-pin-freshness` CI job re-resolves each pin against its registry and compares the pinned Uptime Kuma and Traefik versions against the latest upstream releases. GitHub Actions are pinned by commit SHA; Dependabot keeps those fresh.

### Verify what you deploy

Every release from v1.0.6 on carries three files made on GitHub's runner with a short-lived identity and no stored key: `uptime-kuma-traefik-letsencrypt-docker-compose-<tag>.tar.gz`, a `git archive` of exactly the tree the tag points at; `uptime-kuma-traefik-letsencrypt-docker-compose-<tag>.tar.gz.sigstore.json`, a keyless [Sigstore](https://www.sigstore.dev/) signature over it; and `uptime-kuma-traefik-letsencrypt-docker-compose-<tag>.intoto.jsonl`, [SLSA](https://slsa.dev/) build provenance from the SLSA generator. To check them with nothing from this repository trusted:

```bash
cosign verify-blob uptime-kuma-traefik-letsencrypt-docker-compose-<tag>.tar.gz \
  --bundle uptime-kuma-traefik-letsencrypt-docker-compose-<tag>.tar.gz.sigstore.json \
  --certificate-identity-regexp '^https://github.com/heyvaldemar/uptime-kuma-traefik-letsencrypt-docker-compose/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

slsa-verifier verify-artifact uptime-kuma-traefik-letsencrypt-docker-compose-<tag>.tar.gz \
  --provenance-path uptime-kuma-traefik-letsencrypt-docker-compose-<tag>.intoto.jsonl \
  --source-uri github.com/heyvaldemar/uptime-kuma-traefik-letsencrypt-docker-compose
```

Add `--source-tag <tag>` for a release published after 24 September 2026, which is signed by the run that published it. The five releases before that date were signed by a run started by hand on `main`, so their provenance names the branch, not the tag; the archive is still the tag's tree, and the signature still belongs to this repository's workflow. The workflow that makes them is [`release-assets.yml`](.github/workflows/release-assets.yml).

## Production checklist

- [ ] **Register the administrator account immediately after deploy.**
- [ ] **Turn on two-factor authentication.** It is in the profile menu, and this dashboard lists your hostnames.
- [ ] **Regenerate the Traefik dashboard hash.** The one in `.env.example` is a placeholder.
- [ ] **Host-mount the backup volume.** By default the archives land in a named volume: if the host dies, they die with it.
- [ ] **Keep one external probe.** Every monitor pointed at an internal address leaves the certificate and the proxy chain untested.
- [ ] **Decide about the Docker socket deliberately**, per the section above.
- [ ] **Uptime Kuma cannot monitor itself.** Point something outside this host at it — a free external checker is enough.

## Backups and restore

Everything this service knows is one directory: a SQLite file holding every monitor, notification channel, status page, maintenance window and 2FA secret, plus the uploads. The `backups` container archives it on a loop — a 30-minute warm-up, a 24-hour interval, 7-day retention, all overridable in `.env`.

Each archive is written to a `.partial` name, **read back with `tar -tzf`**, and only then renamed. The read-back is not decoration: BusyBox tar, which is what an alpine image ships, returns exit code 1 both for "a file changed while I was reading it" and for "I could not write the output at all". Trusting the exit code alone renames an empty file into place and calls it a backup. This loop refuses to.

Restore with the interactive script:

```bash
chmod +x ./*.sh
./uptime-kuma-restore-data.sh
```

It lists the backups and asks, or takes a file name as its argument; it reads every path from the running backups container, and CI runs it on every push.

It stops the application first. SQLite is written on every heartbeat, and replacing the file under a running process is how a database ends up half old and half new. A live archive still has a small chance of catching a checkpoint mid-write; if that matters to you, stop the container for the three seconds the tar takes.

## Resource limits

Every service carries memory and CPU limits plus reservations as compose-level defaults: the same values CI boots the stack under. A few hundred monitors fit inside the default — each is a scheduled job and a row per heartbeat. Override any of them in `.env` and the override survives every `git pull`. If a service is OOM-killed, `docker inspect <container> --format '{{.State.OOMKilled}}'` says so.

## Container hardening

Every service runs with `security_opt: no-new-privileges:true`. The reverse proxy and the backups sidecar run with `cap_drop: [ALL]` and add back only what they need: `NET_BIND_SERVICE` for Traefik to bind :80/:443, and the three ownership capabilities the sidecar uses to write archives. The application keeps the default capability set on purpose: upstream images assume it, and a wrong guess there is a boot loop in production rather than a hardening win. CI boots the stack under exactly these settings on every push.

## Testing

The [Deployment Verification](https://github.com/heyvaldemar/uptime-kuma-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and every day at 06:00 UTC: shellcheck and actionlint, Trivy scans of all three pinned images, the daily freshness check, and a deploy job that boots the stack with ephemeral credentials and then requires the API to answer its setup state through Traefik, an archive to be produced and to carry the data directory, the seven backup and restore scenarios to pass, and Uptime Kuma to come back up on the data directory the restore test replaced underneath it.

### Backup and restore, proven

`tests/e2e-backup-restore.sh` runs against the live stack and is what CI executes after the smoke test. Two scenarios carry the weight. The restore roundtrip writes a file, waits for the archive that contains it, deletes it, restores, and asserts it came back. The failure test blocks the destination the loop is about to write to and asserts the loop says FAILED and leaves nothing behind that is named like a backup and does not open.

```bash
chmod +x tests/e2e-backup-restore.sh
./tests/e2e-backup-restore.sh
```

Run it on a staging copy, not on production: it stops the application and empties the data directory.

## Security notes

- Credentials are read from `.env` at deploy time; `.env` is gitignored and compose fails fast on missing required variables.
- Uptime Kuma has no registration gate before the first account exists.
- The Docker socket is not mounted. See the section above for what adding it costs.

---

## About the maintainer

<div align="center">

**Maintained by [Vladimir Mikhalev](https://github.com/heyvaldemar)** · Docker Captain · IBM Champion · AWS Community Builder

[YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1) · [Blog](https://heyvaldemar.com) · [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)

</div>
