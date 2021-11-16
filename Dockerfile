ARG DEV_IMAGE_VERSION
FROM oasisprotocol/oasis-core-dev:${DEV_IMAGE_VERSION} as builder

RUN apt-get update -y \
  && apt-get install -y	llvm-dev libclang-dev clang software-properties-common cmake libboost-all-dev liblld-10-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /usr/src

RUN git clone --depth 1 https://github.com/oasisprotocol/metadata-registry-tools.git && \
    cd metadata-registry-tools && \
    make build

RUN git clone --depth 1 https://github.com/oasisprotocol/tools.git && \
    cd tools/proposal-results && \
    go build && \
    cd ../runtime-stats && \
    go build

ENV OASIS_UNSAFE_SKIP_AVR_VERIFY="1"
ENV OASIS_UNSAFE_SKIP_KM_POLICY="1"
#ENV OASIS_BADGER_NO_JEMALLOC="1"

ARG CORE_VERSION

RUN git -c advice.detachedHead=false clone --depth=1 -b $CORE_VERSION https://github.com/oasisprotocol/oasis-core.git && \
    cd oasis-core && \
    make


ARG CIPHER_VERSION

RUN git clone -c advice.detachedHead=false --depth 1 -b $CIPHER_VERSION https://github.com/oasisprotocol/cipher-paratime.git && \
    cd cipher-paratime && \
    cargo build --release


ARG EMERALD_VERSION

RUN git clone -c advice.detachedHead=false --depth 1 -b $EMERALD_VERSION https://github.com/oasisprotocol/emerald-paratime.git && \
    cd emerald-paratime && \
    cargo build --release

FROM ubuntu:20.04

RUN apt-get update -y \
  && apt-get install -y bubblewrap libssl1.1 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG CORE_VERSION
ARG CIPHER_VERSION
ARG EMERALD_VERSION

LABEL oasis-core-version="${CORE_VERSION}"
LABEL oasis-cipher-version="${CIPHER_VERSION}"
LABEL oasis-emerald-version="${EMERALD_VERSION}"

COPY --from=builder /usr/local/lib/libjemalloc* /usr/local/lib/
RUN ldconfig
COPY --from=builder /usr/src/oasis-core/go/oasis-node/oasis-node /usr/local/bin/
COPY --from=builder /usr/src/oasis-core/target/default/debug/oasis-core-runtime-loader /usr/local/bin/
COPY --from=builder /usr/src/oasis-core/go/oasis-remote-signer/oasis-remote-signer /usr/local/bin/
COPY --from=builder /usr/src/oasis-core/go/oasis-net-runner/oasis-net-runner /usr/local/bin/
COPY --from=builder /usr/src/metadata-registry-tools/oasis-registry/oasis-registry /usr/local/bin/
COPY --from=builder /usr/src/tools/runtime-stats /usr/local/bin/
COPY --from=builder /usr/src/tools/proposal-results /usr/local/bin/
COPY --from=builder /usr/src/cipher-paratime/target/release/cipher-paratime /usr/local/bin/
COPY --from=builder /usr/src/emerald-paratime/target/release/emerald-paratime /usr/local/bin/

# Worker client, Worker P2P, Tendermint P2P
EXPOSE 9100 9200 26656 26657

CMD ["oasis-node"]
