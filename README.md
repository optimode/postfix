# docker-postfix

Alpine-based [Postfix](https://www.postfix.org/) MTA Docker image with
LMDB/MySQL/SQLite/PCRE lookup table support and Cyrus SASL.

The container runs Postfix in the foreground (`postfix start-fg`), which makes
it suitable for Docker and Kubernetes. Configuration is mounted at
`/etc/postfix`, the mail queue lives in `/var/spool/postfix` and logs go to
`/data/log`.

## Versions

This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for
its git tags (e.g. `v1.0.0`); every release is tagged in git. The table shows
exactly which Alpine and Postfix versions each Docker image has and when it was
built.

| Git tag | Alpine | Postfix | Build date | Docker image |
|---|---|---|---|---|
| — (not tagged) | 3.22.0 | 3.10.2 | 2025-06-30 | `ghcr.io/optimode/postfix:3.10.2-alpine` |
| `v1.0.0` | 3.24.2 | 3.11.7 | 2026-10-29 | `ghcr.io/optimode/postfix:3.11.7-alpine` |

Notes:

- The `3.10.2` image predates the git tagging scheme of this repository and is
  listed for reference only.
- Besides the exact version tag (e.g. `3.11.7-alpine`) each build produces two
  moving tags: `3.11-alpine` (latest patch level of Postfix 3.11) and
  `latest-alpine`. For reproducible deployments use the exact version tag.

## Usage

```sh
docker run -d --name postfix \
  -p 25:25 -p 465:465 -p 587:587 \
  -v ./etc:/etc/postfix \
  -v ./certs:/etc/ssl/postfix:ro \
  -v ./log:/data/log \
  -v postfix-spool:/var/spool/postfix \
  ghcr.io/optimode/postfix:3.11.7-alpine
```

See [docker-compose.yml](docker-compose.yml) for a commented compose sample.

### Configuration notes

- **Configuration** is expected at `/etc/postfix` (`main.cf`, `master.cf`,
  lookup tables). Postfix only loads dynamic map modules (lmdb, mysql, pcre,
  sqlite) from root-owned `dynamicmaps.cf` files — make sure the mounted files
  are owned by root (`chown -R root:root ./etc`).
- **Logging**: set `maillog_file = /data/log/postfix.log` and
  `maillog_file_prefixes = /data/log` to log into the mounted log directory.
- **TLS**: mount your certificates and point `smtpd_tls_cert_file` /
  `smtpd_tls_key_file` to the mounted paths. All three submission ports are
  exposed: 25 (SMTP), 465 (SMTPS wrappermode), 587 (submission).
- **SASL**: the image contains Cyrus SASL; Dovecot SASL authentication is
  supported through `smtpd_sasl_type = dovecot` with
  `smtpd_sasl_path = inet:...` or a mounted auth socket.

## Building

```sh
make build                      # build with the default versions
make build push                 # build and push all tags
make build POSTFIX_VERSION=3.11.8 ALPINE_VERSION=3.24.3
make help                       # list targets and variables
```

The build is reproducible by design:

- `ALPINE_VERSION` selects the exact Alpine base image (default: `3.24.2`).
- `POSTFIX_VERSION` (default: `3.11.7`) is pinned in the Dockerfile for all
  four postfix packages (`postfix`, `postfix-mysql`, `postfix-sqlite`,
  `postfix-pcre`). The `~=` pin accepts Alpine package rebuilds of the same
  upstream version (`3.11.7-rX`) but rejects any other version.
- A build-time check fails the build loudly if the planned Postfix version was
  not installed.

### Image metadata

The image carries [OCI](https://github.com/opencontainers/image-spec/blob/master/annotations.md)
labels with the build metadata:

| Label | Content |
|---|---|
| `org.opencontainers.image.version` | Postfix version (e.g. `3.11.7`) |
| `org.opencontainers.image.created` | build date (RFC 3339) |
| `org.opencontainers.image.revision` | git revision the image was built from |
| `org.opencontainers.image.base.name` | base image (e.g. `alpine:3.24.2`) |
| `org.opencontainers.image.url`, `.source` | project and source repository |
| `org.opencontainers.image.authors`, `.vendor`, `.licenses` | authors, vendor, license |

Inspect them with:

```sh
docker inspect ghcr.io/optimode/postfix:3.11.7-alpine \
  --format '{{json .Config.Labels}}' | python3 -m json.tool
```

## License

MIT — see [LICENSE](LICENSE).
