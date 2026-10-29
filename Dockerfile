ARG BASE_IMAGE=alpine:3.24.2

FROM $BASE_IMAGE

# Reproducibility: the installed Postfix version is pinned.
# The "~=" component-wise match accepts Alpine package rebuilds of the same
# upstream version (3.11.7-rX) but rejects 3.11.8 / 3.11.70 / 3.1.x, so a
# later rebuild is guaranteed to install the planned Postfix version or fail
# loudly. All four postfix packages are pinned because the dict modules
# (postfix-lmdb.so in the main package, postfix-mysql/pcre/sqlite.so in the
# subpackages) must share the same ABI.
ARG POSTFIX_VERSION=3.11.7

RUN apk update && \
    apk add \
    cyrus-sasl \
    cyrus-sasl-crammd5 \
    cyrus-sasl-digestmd5 \
    cyrus-sasl-login \
    cyrus-sasl-scram \
    postfix~=${POSTFIX_VERSION} \
    postfix-mysql~=${POSTFIX_VERSION} \
    postfix-sqlite~=${POSTFIX_VERSION} \
    postfix-pcre~=${POSTFIX_VERSION} \
    mailutils \
    && rm -rf /var/cache/apk/*

# Safety net: the build fails loudly if the planned Postfix version was not
# installed (e.g. when the version pins are changed later by mistake)
RUN test "$(postconf -h mail_version)" = "${POSTFIX_VERSION}" \
    || { echo "ERROR: expected Postfix ${POSTFIX_VERSION}, got: $(postconf -h mail_version)"; exit 1; }


ARG URL
ARG SOURCE
ARG BUILD_DATE
ARG AUTHORS
ARG VENDOR
ARG REVISION
ARG OS_VERSION
ARG BASE_IMAGE
#ARG BASE_DIGEST

# https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL "org.opencontainers.image.title"="Postfix MTA Server"
LABEL "org.opencontainers.image.description"="Postfix MTA server $POSTFIX_VERSION on $OS_VERSION"
LABEL "org.opencontainers.image.url"="$URL"
LABEL "org.opencontainers.image.source"="$SOURCE"
LABEL "org.opencontainers.image.version"="$POSTFIX_VERSION"
LABEL "org.opencontainers.image.revision"="$REVISION"
LABEL "org.opencontainers.image.licenses"="MIT"
LABEL "org.opencontainers.image.created"="$BUILD_DATE"
LABEL "org.opencontainers.image.authors"="$AUTHORS"
LABEL "org.opencontainers.image.vendor"="$VENDOR"
LABEL "org.opencontainers.image.base.name"="$BASE_IMAGE"
#LABEL "org.opencontainers.image.base.digest"="$BASE_DIGEST"

VOLUME ["/data"]
EXPOSE 25 465 587

CMD ["/usr/sbin/postfix", "start-fg"]
