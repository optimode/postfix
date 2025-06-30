ARG BASE_IMAGE=malinal/supervisor:latest

FROM optimode/docker-supervisor:latest

ENV DEBIAN_FRONTEND="noninteractive"

# Install packages
RUN set -x && \
  export DEBIAN_FRONTEND=noninteractive && \
  apt-get update && \
  echo 'postfix postfix/main_mailer_type select No configuration' | debconf-set-selections && \
  apt-get install -y --no-install-recommends --no-install-suggests \
  rsyslog \
  postfix \
  postfix-mysql \
  postfix-pcre \
  ca-certificates \
  ssl-cert \
  mailutils \
  curl \
  procps \
  mc \
  libdbi-perl \
  libdbd-mysql-perl \
  libmime-encwords-perl \
  libmime-charset-perl \
  libemail-valid-perl \
  libemail-sender-perl \
  libemail-simple-perl \
  liblog-log4perl-perl \
  liblog-dispatch-perl \
  libtry-tiny-perl \
  libgetopt-argvfile-perl \
  libnet-dns-perl && \
  mv /etc/postfix/main.cf.proto /etc/postfix/main.cf && \
  groupadd -g 5000 vmail && \
  useradd -u 5000 -g 5000 vmail -d /srv/vmail && \
  passwd -l vmail && \
  mkdir /srv/vmail && \
  chown vmail:vmail /srv/vmail && \
  make-ssl-cert generate-default-snakeoil && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

COPY rootfs /

ARG URL
ARG SOURCE
ARG BUILD_DATE
ARG AUTHORS
ARG VENDOR
ARG REVISION

# https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL "org.opencontainers.image.title"="Postfix MTA"
LABEL "org.opencontainers.image.description"="Postfix MTA server with Supervisor"
LABEL "org.opencontainers.image.url"="$URL"
LABEL "org.opencontainers.image.source"="$SOURCE"
LABEL "org.opencontainers.image.version"="latest"
LABEL "org.opencontainers.image.revision"="$REVISION"
LABEL "org.opencontainers.image.licenses"="MIT"
LABEL "org.opencontainers.image.created"="$BUILD_DATE"
LABEL "org.opencontainers.image.authors"="$AUTHORS"
LABEL "org.opencontainers.image.vendor"="$VENDOR"
LABEL "org.opencontainers.image.base.name"="optimode/docker-supervisor:latest"
LABEL "org.opencontainers.image.ref.name"="latest"

VOLUME ["/data"]

EXPOSE 25 587
