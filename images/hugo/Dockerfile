# wyllie/hugo
# Hugo Extended + Dart Sass (standalone) for building Hugo sites (e.g., GitHub Pages docs).
# Intentionally avoids installing Node by using the standalone Dart Sass CLI.

ARG BASE_IMAGE=wyllie/ci-base:alpine3.23.2-1
FROM ${BASE_IMAGE}

ARG HUGO_VERSION=0.161.1
ARG DART_SASS_VERSION=1.97.1

# Provided by BuildKit when building multi-arch (linux/amd64, linux/arm64)
ARG TARGETARCH

# We only need curl here to fetch pinned release artifacts.
RUN apk add --no-cache go curl gcompat libstdc++ libgcc

# Install Hugo Extended (multi-arch)
RUN set -euo pipefail; \
    case "${TARGETARCH:-amd64}" in \
      amd64) HUGO_ARCH=amd64 ;; \
      arm64) HUGO_ARCH=arm64 ;; \
      *) echo "Unsupported TARGETARCH=${TARGETARCH}" >&2; exit 2 ;; \
    esac; \
    curl -fsSL -o /tmp/hugo.tar.gz \
      "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-${HUGO_ARCH}.tar.gz"; \
    tar -xzf /tmp/hugo.tar.gz -C /tmp; \
    install -m 0755 /tmp/hugo /usr/local/bin/hugo; \
    rm -rf /tmp/hugo.tar.gz /tmp/hugo /tmp/LICENSE /tmp/README.md

# Install Dart Sass (standalone CLI, multi-arch)
RUN set -euo pipefail; \
    case "${TARGETARCH:-amd64}" in \
      amd64) SASS_ARCH=x64 ;; \
      arm64) SASS_ARCH=arm64 ;; \
      *) echo "Unsupported TARGETARCH=${TARGETARCH}" >&2; exit 2 ;; \
    esac; \
    curl -fsSL -o /tmp/dart-sass.tar.gz \
      "https://github.com/sass/dart-sass/releases/download/${DART_SASS_VERSION}/dart-sass-${DART_SASS_VERSION}-linux-${SASS_ARCH}.tar.gz"; \
    tar -xzf /tmp/dart-sass.tar.gz -C /tmp; \
    rm -rf /opt/dart-sass; \
    mv /tmp/dart-sass /opt/dart-sass; \
    ln -sf /opt/dart-sass/sass /usr/local/bin/sass; \
    rm -rf /tmp/dart-sass.tar.gz

WORKDIR /work

CMD ["/bin/bash"]
