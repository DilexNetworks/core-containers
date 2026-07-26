# wyllie/cdk
# AWS CDK deployment image (Node + AWS CLI via base image)

ARG BASE_IMAGE=wyllie/aws-cli:awscli2.32.7-alpine3.23.2-1
FROM ${BASE_IMAGE}

ARG CDK_VER=2.1100.3

# Install core tooling: Node.js + npm, then install AWS CDK
RUN apk add --no-cache \
      nodejs \
      npm  \
      && npm install -g aws-cdk@${CDK_VER}

WORKDIR /work

CMD ["/bin/bash"]
