# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG WORK_VERSION

RUN apk add --no-cache openssh-client \
    && mkdir -p -m 0700 /root/.ssh \
    && ssh-keyscan github.com >> /root/.ssh/known_hosts

RUN --mount=type=ssh \
    pip install --no-cache-dir \
    "git+ssh://git@github.com/Syntelliga/core-work.git@v${WORK_VERSION}"

WORKDIR /work

ENTRYPOINT ["work"]
CMD ["--help"]
