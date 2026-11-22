# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The Alpine and Postfix versions of every published Docker image are listed in
the version table in [README.md](README.md).

## [Unreleased]

## [2.0.0] - 2026-11-22

Major release: the single image is split into `postfix` and
`postfix-auth`, and the image tag scheme changes in a backward-incompatible
way. Update your image references when upgrading (see the migration notes
in the Changed section below).

### Added

- New `ghcr.io/optimode/postfix` image: Postfix with the Cyrus SASL libraries
  and the LMDB/MySQL/SQLite/PCRE lookup table modules only — a single
  `postfix start-fg` process, no supervisor and no sidecar services. Built
  from `Dockerfile`, compose sample in `compose.yml`.
- Makefile targets for the two-image layout: `build-auth` / `push-auth` for
  the `postfix-auth` image (built from `Dockerfile.auth`) and `build-all` /
  `push-all` to build and push both images.

### Changed

- **Breaking:** the existing all-in-one image is renamed
  `ghcr.io/optimode/postfix-auth`. It is built from `Dockerfile.auth` (the
  former `Dockerfile`) and its compose sample is now `compose.auth.yml` (the
  former `docker-compose.yml`); the contents are unchanged.
- **Breaking:** image tags no longer carry the `-alpine` OS suffix, because
  both images are Alpine-based. `3.11.7-alpine` is now `3.11.7`, `3.11-alpine`
  is `3.11` and `latest-alpine` is `latest` (each for both images).
- Migration notes: replace `ghcr.io/optimode/postfix:<version>-alpine`
  references with `ghcr.io/optimode/postfix-auth:<version>` (or with
  `ghcr.io/optimode/postfix:<version>` if you only need Postfix itself).
- The Alpine base image is updated to `3.24.4`; the Postfix version stays
  `3.11.7`.
- The `postfix-auth` image now carries OCI labels that reflect the auth
  stack: `org.opencontainers.image.title` is "Postfix MTA Server (Cyrus SASL
  authentication)" and the description mentions saslauthd, OpenDKIM and
  rsyslog under runit.

## [1.2.1] - 2026-11-07

### Fixed

- Per-service svlogd logs now really capture each service's stderr: runsv
  only pipes stdout to the `./log` service, so stderr ended up in
  `docker logs` although the docs promised
  `/data/log/<service>/` (e.g. saslauthd debug output). The run scripts
  now merge stderr into stdout (`exec 2>&1`).

## [1.2.0] - 2026-11-07

### Added

- OpenDKIM runs as a managed service (previously it was only installed).
- Service selection at container start: `ENABLE_SASLAUTHD=0` and
  `ENABLE_OPENDKIM=0` disable services; opendkim is auto-enabled when a
  valid configuration is present at `/etc/opendkim/opendkim.conf`
  (`ENABLE_OPENDKIM=1` forces it). A disabled service starts in the `down`
  state and can be started at runtime with `sv up`.
- Per-service stderr logs via runit's svlogd under `/data/log/<service>/`
  with built-in size-based rotation.

### Changed

- Process management is now runit (`runsvdir`) instead of supervisord —
  the image no longer carries a Python interpreter.
- Postfix runs as `exec master -s` instead of `postfix start-fg`: the
  wrapper only execs master when it is PID 1 and swallowed the shutdown
  signal under a supervisor.

### Fixed

- Postfix no longer leaves an orphaned master process behind on container
  shutdown: `docker stop` now terminates runsvdir first and then stops the
  services gracefully via `sv exit` (rsyslog last).

## [1.1.0] - 2026-11-07

### Added

- `saslauthd` (Cyrus SASL, `sasldb` backend) as a managed service alongside
  Postfix and rsyslog.
- OpenDKIM packages (`opendkim`, `opendkim-utils`) and port `8891` exposed for
  a DKIM milter.
- Automatic size-based log rotation: rsyslog rotates each log stream in
  `/data/log` at 50 MiB and keeps 7 gzip-compressed archives
  (`/usr/local/sbin/rsyslog-rotate`, retention count configurable per call).

### Changed

- The container is now managed by supervisord (PID 1) and runs three
  processes: postfix, saslauthd and rsyslog. This reintroduces the
  supervisor-managed layout that v1.0.0 retired in favour of a single
  `postfix start-fg` process.
- Logging goes through rsyslog into `/data/log/mail.log` (postfix, opendkim),
  `/data/log/auth.log` (saslauthd) and `/data/log/syslog` (everything else)
  instead of a single Postfix `maillog_file`. If `maillog_file` is set in
  `main.cf`, Postfix still writes its own file — do not route the same
  messages to rsyslog as well, or they are logged twice.

### Fixed

- Log timestamps are now written in local time (honouring the `TZ`
  environment variable or a mounted `/etc/localtime`) instead of UTC: the
  `tzdata` package was missing, so Alpine's musl libc silently fell back to
  UTC for every daemon.
- rsyslog no longer rate-limits the local log socket, so message bursts on a
  busy MTA are not silently dropped.

## [1.0.0] - 2026-10-29

First versioned release. The image is published as
`ghcr.io/optimode/postfix:3.11.7-alpine`, together with the moving
`3.11-alpine` and `latest-alpine` tags.

### Added

- `docker-compose.yml` sample for running the image with a mounted Postfix
  configuration, TLS certificates, log directory and a persistent mail queue.
- Build-time verification of the planned Postfix version: the image build fails
  loudly if a different Postfix version would be installed.
- OCI image labels carrying the build metadata (version, build date, git
  revision, base image, source repository).
- README version table mapping each release to its exact Alpine and Postfix
  versions, build date and Docker image name.

### Changed

- The image is now built on `alpine:3.24.2` with Postfix `3.11.7` from Alpine
  packages, replacing the previous Debian/supervisor based image. All four
  postfix packages (`postfix`, `postfix-mysql`, `postfix-sqlite`,
  `postfix-pcre`) are version-pinned so that a rebuild installs the planned
  Postfix version or fails.
- The container now runs Postfix in the foreground (`postfix start-fg`),
  as recommended for containers. Logging goes to `/data/log` through
  `maillog_file` instead of rsyslog.
- The published image name is now `ghcr.io/optimode/postfix` (previously
  `optimode/docker-postfix`).
- The Makefile builds and pushes versioned image tags
  (`3.11.7-alpine`, `3.11-alpine`, `latest-alpine`) with configurable
  `POSTFIX_VERSION` and `ALPINE_VERSION` variables and complete OCI metadata.

### Removed

- `rootfs/` supervisor and rsyslog configuration: the supervisor-managed image
  layout is retired.

## Earlier development (unversioned)

Repository history from before the first versioned release. No version numbers
are assigned to these changes; they were built and published as Docker images
at the time.

- 2025-06-30 (`897c75e`): add Dockerfile, Makefile and configuration files for
  the Postfix setup — the original Debian-based image managed by supervisor,
  with rsyslog logging.
- 2025-06-30 (`50f0512`): initial commit with the repository scaffolding
  (license, `.gitignore`).

[Unreleased]: https://github.com/optimode/postfix/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/optimode/postfix/compare/v1.2.1...v2.0.0
[1.2.1]: https://github.com/optimode/postfix/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/optimode/postfix/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/optimode/postfix/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/optimode/postfix/releases/tag/v1.0.0
