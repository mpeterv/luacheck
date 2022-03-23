#syntax=docker/dockerfile:1.2

FROM alpine:latest AS luacheck

LABEL org.opencontainers.image.title="CaSILE"
LABEL org.opencontainers.image.description="A containerized version of Luacheck, a tool for linting and static analysis of Lua code"
LABEL org.opencontainers.image.authors="Caleb Maclennan <caleb@alerque.com>"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.url="https://github.com/lunarmodules/luacheck/pkgs/container/luacheck"
LABEL org.opencontainers.image.source="https://github.com/lunarmodules/luacheck"

RUN apk add --no-cache dumb-init lua lua-argparse lua-filesystem

COPY "src/luacheck/" "/usr/share/lua/5.1/luacheck/"
COPY "bin/luacheck.lua" "/usr/bin/luacheck"

WORKDIR /data

ENTRYPOINT ["luacheck", "--no-cache"]
