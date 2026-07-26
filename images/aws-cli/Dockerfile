ARG BASE_IMAGE=wyllie/ci-base:alpine3.23.2-1
FROM ${BASE_IMAGE}

ARG AWSCLI_VERSION

RUN apk add --no-cache aws-cli=${AWSCLI_VERSION}

CMD ["/bin/bash"]
