# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG WORK_VERSION

RUN pip install --no-cache-dir \
    "git+https://github.com/DilexNetworks/core-work.git@v${WORK_VERSION}"

WORKDIR /work

ENTRYPOINT ["work"]
CMD ["--help"]
