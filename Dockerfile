#syntax=docker/dockerfile:1.2

FROM alpine:latest AS luacheck

LABEL maintainer="Caleb Maclennan <caleb@alerque.com>"

RUN apk add --no-cache dumb-init lua lua-argparse lua-filesystem

COPY "src/luacheck/" "/usr/share/lua/5.1/luacheck/"
COPY "bin/luacheck.lua" "/usr/bin/luacheck"

WORKDIR /data

ENTRYPOINT ["luacheck"]
