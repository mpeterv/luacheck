#syntax=docker/dockerfile:1.2

FROM alpine:edge AS luacheck

LABEL org.opencontainers.image.title="Luacheck"
LABEL org.opencontainers.image.description="A containerized version of Luacheck, a tool for linting and static analysis of Lua code"
LABEL org.opencontainers.image.authors="Caleb Maclennan <caleb@alerque.com>"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.url="https://github.com/lunarmodules/luacheck/pkgs/container/luacheck"
LABEL org.opencontainers.image.source="https://github.com/lunarmodules/luacheck"

RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing dumb-init lua lua-argparse lua-filesystem lua-lanes

COPY "src/luacheck/" "/usr/share/lua/5.1/luacheck/"
COPY "bin/luacheck.lua" "/usr/bin/luacheck"

WORKDIR /data

ENTRYPOINT ["luacheck", "--no-cache"]
