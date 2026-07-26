ARG BASE_IMAGE=wyllie/ci-base:alpine3.23.2-1
FROM ${BASE_IMAGE}

RUN apk add --no-cache \
      python3 \
      py3-pip \
      py3-virtualenv

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

RUN python3 -m venv "${VIRTUAL_ENV}" \
    && pip install --no-cache-dir --upgrade pip

WORKDIR /work

CMD ["/bin/bash"]
