#syntax=docker/dockerfile:1.2

FROM akorn/luarocks:lua5.4-alpine AS builder

RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing \
	dumb-init gcc libc-dev

COPY ./ /src
WORKDIR /src

RUN luarocks --tree /pkgdir/usr/local make
RUN find /pkgdir -type f -exec sed -i -e 's!/pkgdir!!g' {} \;

FROM akorn/lua:5.4-alpine AS final

RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing \
	dumb-init

LABEL org.opencontainers.image.title="Luacheck"
LABEL org.opencontainers.image.description="A containerized version of Luacheck, a tool for linting and static analysis of Lua code"
LABEL org.opencontainers.image.authors="Caleb Maclennan <caleb@alerque.com>"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.url="https://github.com/lunarmodules/luacheck/pkgs/container/luacheck"
LABEL org.opencontainers.image.source="https://github.com/lunarmodules/luacheck"

COPY --from=builder /pkgdir /
RUN luacheck --version

WORKDIR /data

ENTRYPOINT ["luacheck", "--no-cache"]
