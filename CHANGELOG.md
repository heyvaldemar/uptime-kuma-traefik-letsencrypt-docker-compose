# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **CI had never run the restore script.** The test restored with its own
  copy of the commands. The script read `DATA_PATH` and `DATA_BACKUPS_PATH`
  from the shell that ran it rather than from `.env` or the stack, so a path
  set in `.env` was not the one it listed or cleared, and it cleared with
  `rm -rf dir/*`, which leaves every dotfile of the newer state in place. It
  now takes every path and name from the running backups container, accepts
  the backup file name as an argument, starts the application again whatever
  happens, and CI runs it: a file written before a backup and deleted after it
  must be back once that backup is restored.

### Changed

- **The freshness check has its own workflow, Pin Freshness.** It ran inside Deployment Verification, whose badge is the one at the top of this README. Across the fleet, nine red runs in ten were a pin one version behind - which the fleet's triage moves within the day - and a reader cannot tell that from a stack that does not boot. The badge now says whether the stack boots. The job itself is unchanged.

## [1.0.5] - 2026-09-21

### Security

- **`traefik:3.7` was rebuilt upstream**; the pin moved from `sha256:1c32e7c36820…` to `sha256:24841fe2de73…`. Same version, same tag, a rebuilt base image — the usual shape of a security fix in a base layer.

## [1.0.4] - 2026-09-19

### Security

- **`alpine:3.22` was rebuilt upstream**; the pin moved from `sha256:365499d9dccb…` to `sha256:5291449c3df7…`. Same version, same tag, a rebuilt base image — the usual shape of a security fix in a base layer.

## [1.0.3] - 2026-09-18

### Security

- **`alpine:3.22` was rebuilt upstream**; the pin moved from `sha256:14358309a308…` to `sha256:365499d9dccb…`. Same version, same tag, a rebuilt base image — the usual shape of a security fix in a base layer.
- **`traefik:3.7` was rebuilt upstream**; the pin moved from `sha256:f86a2cab1b5c…` to `sha256:1c32e7c36820…`. Same version, same tag, a rebuilt base image — the usual shape of a security fix in a base layer.

## [1.0.2] - 2026-09-17

### Changed

- **`louislam/uptime-kuma:2.5.4` moved to `louislam/uptime-kuma:2.5.5`.** The freshness check reported the lag; the deploy job booted the stack on the new image before this landed.

## [1.0.1] - 2026-09-11

### Changed

- **`louislam/uptime-kuma:2.5.3` moved to `louislam/uptime-kuma:2.5.4`.** The freshness check reported the lag; the deploy job booted the stack on the new image before this landed.

## [1.0.0] - 2026-09-10

First release. A production deployment of Uptime Kuma behind Traefik, built to
the fleet standard established in
[keycloak-traefik-letsencrypt-docker-compose](https://github.com/heyvaldemar/keycloak-traefik-letsencrypt-docker-compose).

### Added

- **Uptime Kuma 2.5.3 behind Traefik with Let's Encrypt TLS.** Three images
  pinned by `tag@sha256:<digest>` in the compose `x-images` block: the
  application, Traefik, and a plain alpine for the backups sidecar, which needs
  tar and nothing else.
- **A backup loop that reads its own archive back before naming it a backup.**
  Each cycle writes `.partial`, verifies it with `tar -tzf`, and only then
  renames; a failure leaves a `.failed` file with the evidence. The read-back
  is the point: BusyBox tar returns exit code 1 both for "a file changed while
  I read it" and for "I could not write the output at all", so the exit code
  alone would rename an empty file into place and log it as OK.
- **A restore script that stops the application first.** SQLite is written on
  every heartbeat, and replacing the file under a running process is how a
  database ends up half old and half new.
- **Deployment Verification workflow.** shellcheck and actionlint, Trivy scans
  of all three images, a daily freshness check, and a deploy job requiring the
  API to answer its setup state through Traefik, an archive to be produced and
  to carry the data directory, seven backup and restore scenarios to pass, and
  the application to come back on the data directory the restore replaced.
- **`update.sh`** moves between release tags, refuses to cross a major
  unattended, refuses to run over local changes, and names any variable that
  became required since the deployed version.
- **Container hardening**: `no-new-privileges` everywhere, `cap_drop: [ALL]`
  with a named add-back list on the proxy and the sidecar, resource limits and
  reservations on all three services, and a sixty-second `stop_grace_period` on
  the application so a SQLite checkpoint is not cut short by SIGKILL.

### Notes

- **The Docker socket is not mounted.** Uptime Kuma's Docker Container monitor
  type needs it, and it is the only way to watch something with no HTTP
  endpoint — but `:ro` on that socket is cosmetic, the API is root-equivalent,
  and mounting it is a decision that belongs to whoever accepts it. The README
  says what to add and what it costs.
- **There is no password to set before first boot.** Uptime Kuma has no
  credentials until the first account exists and gives that account to whoever
  reaches the setup page first, so the deploy instructions say to register
  immediately rather than leaving it as an implied step.

[Unreleased]: https://github.com/heyvaldemar/uptime-kuma-traefik-letsencrypt-docker-compose/compare/v1.0.5...HEAD
[1.0.5]: https://github.com/heyvaldemar/uptime-kuma-traefik-letsencrypt-docker-compose/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/heyvaldemar/uptime-kuma-traefik-letsencrypt-docker-compose/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/heyvaldemar/uptime-kuma-traefik-letsencrypt-docker-compose/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/heyvaldemar/uptime-kuma-traefik-letsencrypt-docker-compose/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/heyvaldemar/uptime-kuma-traefik-letsencrypt-docker-compose/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/heyvaldemar/uptime-kuma-traefik-letsencrypt-docker-compose/releases/tag/v1.0.0
