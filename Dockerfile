# SPDX-License-Identifier: MIT
#
# Copyright (C) 2019 Martin Broers <martin.broers@evbox.com>

# For Alpine, latest is actually the latest stable
# hadolint ignore=DL3007
FROM registry.hub.docker.com/library/alpine:latest

LABEL Maintainer="Martin Broers <martin.broers@evbox.com>"

# We want the latest stable version from the repo
# hadolint ignore=DL3018
RUN \
    apk add --no-cache \
        dumb-init \
        lua-argparse \
        lua-filesystem \
        luacheck \
    && \
    rm -rf "/var/cache/apk/"* && \
    for luacheckfile in $(apk info -L luacheck); do \
        if [ -f "/${luacheckfile}" ]; then \
            rm "/${luacheckfile:?}"; \
        fi \
    done

COPY "src/luacheck/" "/usr/share/lua/5.1/luacheck/"
COPY "bin/luacheck.lua" "/usr/bin/luacheck"

COPY "scripts/docker-entrypoint.sh" "/docker-entrypoint.sh"

ENTRYPOINT [ "/docker-entrypoint.sh" ]
