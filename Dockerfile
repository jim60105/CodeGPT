# syntax=docker/dockerfile:1
ARG UID=1001

########################################
# Build stage
########################################
FROM --platform=${BUILDPLATFORM:-linux/amd64} golang:1.22 AS build

# RUN mount cache for multi-arch: https://github.com/docker/buildx/issues/549#issuecomment-1788297892
ARG TARGETARCH
ARG TARGETVARIANT

ARG TARGETOS

RUN --mount=source=.,target=.,rw \
    # Install codegpt
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags="-w -s" -o /codegpt ./cmd/codegpt

########################################
# Compress stage
########################################
FROM debian:bookworm-slim AS compress

# RUN mount cache for multi-arch: https://github.com/docker/buildx/issues/549#issuecomment-1788297892
ARG TARGETARCH
ARG TARGETVARIANT

ARG TARGETOS

ARG VERSION
RUN --mount=type=cache,id=apt-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,id=aptlists-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/var/lib/apt/lists \
    --mount=source=/codegpt,target=/app,from=build \
    # Install upx
    echo 'deb http://deb.debian.org/debian bookworm-backports main' > /etc/apt/sources.list.d/backports.list && \
    apt-get update && apt-get install -y --no-install-recommends upx-ucl && \
    # Compress codegpt
    upx --best --lzma -o /codegpt /app || true; \
    # Remove upx
    apt-get purge -y upx-ucl

########################################
# Binary stage
# How to: docker build --output=. --target=binary .
########################################
FROM scratch AS binary

ARG NAME=codegpt
COPY --link --chown=0:0 --chmod=777 --from=compress /${NAME} /${NAME}
