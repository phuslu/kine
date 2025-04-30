FROM harbor.shopeemobile.com/shopee/golang-base:1.23.7-20 AS builder

COPY . /workspace/kine-ecp

RUN cd /workspace/kine-ecp && \
    go build -v && \
    cp kine /usr/local/bin/

FROM harbor.shopeemobile.com/ecp/nfpm:2.18.0

COPY --from=builder /usr/local/bin/kine /usr/local/bin/
COPY ./.shopee/build/nfpm/ /workspace/nfpm/
COPY ./.shopee/build/overlay/ /

ARG GIT_TAG
RUN cd /workspace/nfpm/ && \
    export PACKAGE_VERSION=$(echo ${GIT_TAG} | sed 's/^v//') && \
    sed -i "s/__PACKAGE_VERSION__/${PACKAGE_VERSION}/g" * && \
    mkdir -p /workspace/releases && \
    for yaml in *.yaml; do nfpm package -f ${yaml} -p deb -t /workspace/releases; done
