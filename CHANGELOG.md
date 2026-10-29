# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The Alpine and Postfix versions of every published Docker image are listed in
the version table in [README.md](README.md).

## [Unreleased]

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

[Unreleased]: https://github.com/optimode/postfix/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/optimode/postfix/releases/tag/v1.0.0
