# docker-postfix

Alpine-based [Postfix](https://www.postfix.org/) MTA Docker images with
LMDB/MySQL/SQLite/PCRE lookup table support and Cyrus SASL. Two variants are
published:

| Image | Contents | Processes in the container | Use it when |
|---|---|---|---|
| `ghcr.io/optimode/postfix` | Postfix, Cyrus SASL libraries, lookup table modules (`postfix-mysql`, `postfix-sqlite`, `postfix-pcre`) | Postfix only (`postfix start-fg`) | you run authentication, DKIM signing and logging yourself (sidecar containers, external services) and want the smallest possible image |
| `ghcr.io/optimode/postfix-auth` | everything in `postfix`, plus `saslauthd`, OpenDKIM, rsyslog and runit | runit (`runsvdir`) as PID 1 supervising Postfix (`master -s`), `saslauthd`, OpenDKIM (when configured) and rsyslog | you want an all-in-one MTA with Cyrus SASL authentication, DKIM signing and file-based logging out of the box |

Both images are Alpine-based and built from the same Postfix version. The
build files are `Dockerfile` + `compose.yml` for `postfix` and
`Dockerfile.auth` + `compose.auth.yml` for `postfix-auth`.

## Tags

The tags carry the Postfix version only — there is no OS suffix (the former
`-alpine` suffix is gone), because both images are Alpine-based:

| Tag | Meaning |
|---|---|
| `3.11.7` | exact Postfix version — use this for reproducible deployments |
| `3.11` | moving tag: latest patch level of Postfix 3.11 |
| `latest` | moving tag: the most recent build |

Every build produces all three tags for both images:
`ghcr.io/optimode/postfix:3.11.7`, `…:3.11`, `…:latest` and
`ghcr.io/optimode/postfix-auth:3.11.7`, `…:3.11`, `…:latest`.

## Versions

This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for
its git tags (e.g. `v1.0.0`); every release is tagged in git. The table shows
exactly which Alpine and Postfix versions each Docker image has and when it was
built.

| Git tag | Alpine | Postfix | Build date | `postfix` image | `postfix-auth` image |
|---|---|---|---|---|---|
| — (not tagged) | 3.22.0 | 3.10.2 | 2025-06-30 | `ghcr.io/optimode/postfix:3.10.2-alpine` | — |
| `v1.0.0` | 3.24.2 | 3.11.7 | 2026-10-29 | `ghcr.io/optimode/postfix:3.11.7-alpine` | — |
| `v1.1.0` | 3.24.2 | 3.11.7 | 2026-11-07 | `ghcr.io/optimode/postfix:3.11.7-alpine` | — |
| `v1.2.0` | 3.24.2 | 3.11.7 | 2026-11-07 | `ghcr.io/optimode/postfix:3.11.7-alpine` | — |
| `v1.2.1` | 3.24.2 | 3.11.7 | 2026-11-07 | `ghcr.io/optimode/postfix:3.11.7-alpine` | — |
| `v2.0.0` | 3.24.4 | 3.11.7 | 2026-11-22 | `ghcr.io/optimode/postfix:3.11.7` | `ghcr.io/optimode/postfix-auth:3.11.7` |

Notes:

- The `3.10.2` image predates the git tagging scheme of this repository and is
  listed for reference only.
- Up to `v1.2.1` a single image was published as
  `ghcr.io/optimode/postfix:3.11.7-alpine` (with the `-alpine` suffix). That
  image is now published as `ghcr.io/optimode/postfix-auth` and the tags no
  longer carry the `-alpine` suffix; the plain `postfix` image is new (see
  [CHANGELOG.md](CHANGELOG.md)).
- The Docker image tag reflects the Postfix version, not the git tag: several
  releases can rebuild the same `3.11.7` tag with different image contents.

## Image 1: `postfix`

Postfix with the Cyrus SASL libraries and the LMDB/MySQL/SQLite/PCRE lookup
table modules, nothing else: no supervisor, no rsyslog, no saslauthd, no
OpenDKIM. The container runs a single process — Postfix in the foreground
(`postfix start-fg`) — and Postfix is PID 1, so `docker stop` shuts it down
cleanly.

### Usage

```sh
docker run -d --name postfix \
  -e TZ=Europe/Budapest \
  -p 25:25 -p 465:465 -p 587:587 \
  -v ./etc:/etc/postfix \
  -v ./certs:/etc/ssl/postfix:ro \
  -v ./log:/data/log \
  -v postfix-spool:/var/spool/postfix \
  ghcr.io/optimode/postfix:3.11.7
```

See [compose.yml](compose.yml) for a commented compose sample.

### Configuration notes

- **Configuration** is expected at `/etc/postfix` (`main.cf`, `master.cf`,
  lookup tables). Postfix only loads dynamic map modules (lmdb, mysql, pcre,
  sqlite) from root-owned `dynamicmaps.cf` files — make sure the mounted files
  are owned by root (`chown -R root:root ./etc`).
- **Logging**: the image contains no syslog daemon, so configure Postfix's own
  logging via `maillog_file` in `main.cf`:
  - `maillog_file = /dev/stdout` — logs go to `docker logs` (the pattern
    recommended by the [Postfix MAILLOG_README](https://www.postfix.org/MAILLOG_README.html)
    for containers), or
  - `maillog_file = /data/log/postfix.log` with
    `maillog_file_prefixes = /data/log` — logs go to a file in the mounted
    `/data` volume. `/data` is declared as a volume; rotate the file yourself
    (logrotate) if you use a file.
- **Timezone**: the `tzdata` package is included, so both the `TZ`
  environment variable (e.g. `TZ=Europe/Budapest`) and a mounted
  `/etc/localtime` are honoured; log timestamps are written in local time.
  If you use both, make sure they point to the same zone (`TZ` wins).
- **TLS**: mount your certificates and point `smtpd_tls_cert_file` /
  `smtpd_tls_key_file` to the mounted paths. All three submission ports are
  exposed: 25 (SMTP), 465 (SMTPS wrappermode), 587 (submission).
- **SASL**: the Cyrus SASL libraries are installed (plain, login, crammd5,
  digestmd5, scram), but there is no `saslauthd` service in this image.
  Authenticate against Dovecot (`smtpd_sasl_type = dovecot` with
  `smtpd_sasl_path = inet:...` or a mounted auth socket), or use the
  `postfix-auth` image if you want Cyrus SASL `saslauthd` in the same
  container.
- **MySQL lookups**: the `postfix-mysql` map module is included, so
  `mysql:` maps in `main.cf` work with a mounted `mysql_*.cf` table file.

## Image 2: `postfix-auth`

Everything the `postfix` image contains, plus the authentication and logging
stack: `saslauthd` (Cyrus SASL), OpenDKIM, rsyslog and runit. Configuration is
mounted at `/etc/postfix`, the mail queue lives in `/var/spool/postfix` and
logs go to `/data/log` where rsyslog writes and rotates them.

### Usage

```sh
docker run -d --name postfix \
  -e TZ=Europe/Budapest \
  -p 25:25 -p 465:465 -p 587:587 \
  -v ./etc:/etc/postfix \
  -v ./certs:/etc/ssl/postfix:ro \
  -v ./log:/data/log \
  -v postfix-spool:/var/spool/postfix \
  ghcr.io/optimode/postfix-auth:3.11.7
```

See [compose.auth.yml](compose.auth.yml) for a commented compose sample.

### Configuration notes

- **Configuration** is expected at `/etc/postfix` (`main.cf`, `master.cf`,
  lookup tables), exactly as for the `postfix` image (root-owned files).
- **Logging**: rsyslog writes the logs of all container processes into the
  mounted log directory: `/data/log/mail.log` (postfix, opendkim),
  `/data/log/auth.log` (saslauthd) and `/data/log/syslog` (everything else).
  Each stream is rotated automatically at 50 MiB and 7 gzip-compressed
  archives are kept. Alternatively Postfix can log to its own file via
  `maillog_file = /data/log/postfix.log` with
  `maillog_file_prefixes = /data/log` — but do not combine the two, or every
  Postfix message is logged twice. Each service additionally keeps its own
  stderr in `/data/log/<service>/` via runit's svlogd (built-in size-based
  rotation).
- **Timezone**: the `tzdata` package is included, so both the `TZ`
  environment variable (e.g. `TZ=Europe/Budapest`) and a mounted
  `/etc/localtime` are honoured; log timestamps are written in local time.
  If you use both, make sure they point to the same zone (`TZ` wins).
- **TLS**: mount your certificates and point `smtpd_tls_cert_file` /
  `smtpd_tls_key_file` to the mounted paths. All three submission ports are
  exposed: 25 (SMTP), 465 (SMTPS wrappermode), 587 (submission). Port 8891 is
  exposed for an OpenDKIM milter.
- **SASL**: the image contains Cyrus SASL and runs `saslauthd` with the
  `sasldb` backend; Dovecot SASL authentication is supported through
  `smtpd_sasl_type = dovecot` with `smtpd_sasl_path = inet:...` or a mounted
  auth socket.
- **Processes**: runit (`runsvdir`) is PID 1 and supervises the services
  under `rootfs/etc/service/` (see below).

### Services

runit supervises one directory per service under
`rootfs/etc/service/`. Which services start can be controlled at container
start with environment variables:

| Service | Default | Control |
|---|---|---|
| `rsyslog`, `postfix` | always on | — |
| `saslauthd` | on | `ENABLE_SASLAUTHD=0` |
| `opendkim` | auto: starts when `/etc/opendkim/opendkim.conf` is present and valid (`opendkim -n`) | `ENABLE_OPENDKIM=0` (off), `ENABLE_OPENDKIM=1` (force on) |

Typical profiles (via `environment` in compose.auth.yml):

- **Standalone smtp-only MTA**: no variables needed — opendkim starts as
  soon as a valid config and keys are mounted at `/etc/opendkim`.
- **Bigger ecosystem** (dovecot provides SASL, rspamd signs DKIM) or
  **OpenDKIM in its own container**:

```yaml
services:
  postfix:
    environment:
      - TZ=Europe/Budapest
      # dovecot provides SASL, rspamd signs DKIM:
      - ENABLE_SASLAUTHD=0
      # rspamd signs DKIM, or opendkim runs in its own container:
      - ENABLE_OPENDKIM=0
```

A disabled service is not removed: it starts in the `down` state and stays
supervised. Services can also be controlled at runtime with `sv`:

```sh
docker exec postfix sv status /etc/service/*
docker exec postfix sv up /etc/service/opendkim
docker exec postfix sv down /etc/service/saslauthd
```

## Building

Both images are built with the Makefile; `build` builds `postfix` from
`Dockerfile`, `build-auth` builds `postfix-auth` from `Dockerfile.auth`:

```sh
make build                      # build ghcr.io/optimode/postfix
make build-auth                 # build ghcr.io/optimode/postfix-auth
make build-all push-all         # build and push both images
make build push                 # build and push all postfix tags
make build POSTFIX_VERSION=3.11.8 ALPINE_VERSION=3.24.5
make help                       # list targets and variables
```

The build is reproducible by design:

- `ALPINE_VERSION` selects the exact Alpine base image (default: `3.24.4`).
- `POSTFIX_VERSION` (default: `3.11.7`) is pinned in the Dockerfiles for all
  four postfix packages (`postfix`, `postfix-mysql`, `postfix-sqlite`,
  `postfix-pcre`). The `~=` pin accepts Alpine package rebuilds of the same
  upstream version (`3.11.7-rX`) but rejects any other version.
- A build-time check fails the build loudly if the planned Postfix version was
  not installed.

### Image metadata

The images carry [OCI](https://github.com/opencontainers/image-spec/blob/master/annotations.md)
labels with the build metadata:

| Label | Content |
|---|---|
| `org.opencontainers.image.version` | Postfix version (e.g. `3.11.7`) |
| `org.opencontainers.image.created` | build date (RFC 3339) |
| `org.opencontainers.image.revision` | git revision the image was built from |
| `org.opencontainers.image.base.name` | base image (e.g. `alpine:3.24.4`) |
| `org.opencontainers.image.url`, `.source` | project and source repository |
| `org.opencontainers.image.authors`, `.vendor`, `.licenses` | authors, vendor, license |

Inspect them with:

```sh
docker inspect ghcr.io/optimode/postfix:3.11.7 \
  --format '{{json .Config.Labels}}' | python3 -m json.tool
```

## License

MIT — see [LICENSE](LICENSE).
