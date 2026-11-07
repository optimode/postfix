#!/bin/sh
# Container entrypoint (PID 1): service selection, then runsvdir under a
# graceful shutdown trap.
#
# Service selection at container start:
#   ENABLE_SASLAUTHD=0   do not start saslauthd (e.g. dovecot provides
#                        SASL authentication)
#   ENABLE_OPENDKIM=0    do not start opendkim (e.g. rspamd signs DKIM,
#                        or opendkim runs in its own container)
#   ENABLE_OPENDKIM=1    force opendkim even if no config is detected
# A disabled service gets a "down" marker: runsv starts it in the down
# state - it stays supervised and can be started any time with
#   sv up /etc/service/<name>
#
# opendkim defaults to "auto": it starts only when its configuration is
# present and valid (checked with "opendkim -n"), since it cannot run
# without config and keys. The Alpine package ships an example config
# that fails this check until real config and keys are mounted.
# saslauthd defaults to enabled.
#
# runsvdir exits immediately on SIGTERM without stopping its services, so
# "docker stop" would leave postfix mid-shutdown (or hard-killed after the
# 10s timeout). The shutdown therefore stops runsvdir FIRST - otherwise
# its 5-second scan would respawn services that are exited below, racing
# with the "sv exit" commands (a lost command stalls until its timeout).
# "sv exit" then stops each service properly (TERM to the service,
# ./finish runs, runsv exits) and waits.
#
# Shutdown order: rsyslog last, so the shutdown messages of the other
# services still reach the log files.
set -u

OPENDKIM_CONF=/etc/opendkim/opendkim.conf

enable_service() {
    rm -f "/etc/service/$1/down"
    echo "$1: enabled"
}

disable_service() {
    touch "/etc/service/$1/down"
    echo "$1: disabled ($2)"
}

case "${ENABLE_SASLAUTHD:-1}" in
    0 | false | no | off) disable_service saslauthd "ENABLE_SASLAUTHD=0" ;;
    *)                    enable_service saslauthd ;;
esac

case "${ENABLE_OPENDKIM:-auto}" in
    0 | false | no | off)
        disable_service opendkim "ENABLE_OPENDKIM=0"
        ;;
    1 | true | yes | on)
        enable_service opendkim
        ;;
    *)
        mkdir -p /run/opendkim
        if [ -f "$OPENDKIM_CONF" ] \
            && /usr/sbin/opendkim -n -x "$OPENDKIM_CONF" >/dev/null 2>&1
        then
            enable_service opendkim
        else
            disable_service opendkim "no valid $OPENDKIM_CONF"
        fi
        ;;
esac

runsvdir_pid=

shutdown() {
    trap - TERM INT
    if [ -n "$runsvdir_pid" ]; then
        kill -TERM "$runsvdir_pid" 2>/dev/null
        wait "$runsvdir_pid" 2>/dev/null
    fi
    # sv runs multi-service commands in parallel. rsyslog is stopped last
    # so the shutdown messages of the other services are still logged.
    # When adding a service, list it in the first command.
    sv -w7 exit /etc/service/opendkim /etc/service/postfix /etc/service/saslauthd 2>/dev/null || true
    sv -w7 exit /etc/service/rsyslog 2>/dev/null || true
    exit 0
}
trap shutdown TERM INT

runsvdir -P /etc/service &
runsvdir_pid=$!
wait "$runsvdir_pid"
exit 0
