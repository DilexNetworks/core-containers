

# wyllie/ci-base
# Minimal, reproducible CI foundation for derived images.
# Includes: bash, ca-certificates (TLS trust), git, and full-featured tar.

FROM alpine:3.24.1

# Core CI tools
RUN apk add --no-cache \
      bash \
      ca-certificates \
      git \
      openssh-client \
      tar \
    && update-ca-certificates

# A sensible default working directory for CI jobs
WORKDIR /work

# Default shell for interactive use (GitHub Actions steps set their own shell as needed)
CMD ["/bin/bash"]