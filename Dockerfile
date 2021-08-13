FROM oasisprotocol/oasis-core-dev:master as builder

RUN apt-get update -y \
  && apt-get install -y	llvm-dev libclang-dev clang software-properties-common cmake libboost-all-dev liblld-10-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /usr/src

ENV OASIS_UNSAFE_SKIP_AVR_VERIFY="1"
ENV OASIS_UNSAFE_SKIP_KM_POLICY="1"
#ENV OASIS_BADGER_NO_JEMALLOC="1"

ARG CORE_VERSION

RUN git -c advice.detachedHead=false clone --depth=1 -b $CORE_VERSION https://github.com/oasisprotocol/oasis-core.git && \
    cd oasis-core && \
    make

ARG SSVMRUNTIME_VERSION

RUN git -c advice.detachedHead=false clone --depth=1 -b $SSVMRUNTIME_VERSION https://github.com/second-state/oasis-ssvm-runtime.git && \
    cd oasis-ssvm-runtime && \
    rustup target add x86_64-fortanix-unknown-sgx && \
    make symlink-artifacts OASIS_CORE_SRC_PATH=../oasis-core && \
    make

ARG EVMC_VERSION
ARG WASMEDGE_VERSION

RUN git -c advice.detachedHead=false clone --depth=1 -b $EVMC_VERSION https://github.com/second-state/WasmEdge-evmc.git && \
    git -c advice.detachedHead=false clone --depth=1 -b $WASMEDGE_VERSION https://github.com/WasmEdge/WasmEdge.git && \
    cmake -DSSVM_CORE_PATH=WasmEdge -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=ON -DBUILD_TOOLS=OFF -DSSVM_DISABLE_AOT_RUNTIME=ON ./WasmEdge-evmc && \ 
    make

RUN git clone --depth 1 https://github.com/oasisprotocol/metadata-registry-tools.git && \
    cd metadata-registry-tools && \
    make build

FROM ubuntu:20.04

ARG CORE_VERSION
ARG SSVMRUNTIME_VERSION
ARG EVMC_VERSION
ARG WASMEDGE_VERSION

LABEL oasis-core-version="${CORE_VERSION}"
LABEL oasis-ssvmruntime-version="${SSVMRUNTIME_VERSION}"
LABEL oasis-evmc-version="${EVMC_VERSION}"
LABEL oasis-wasmedge-version="${WASMEDGE_VERSION}"

COPY --from=builder /usr/local/lib/libjemalloc* /usr/local/lib/
RUN ldconfig
COPY --from=builder /usr/src/oasis-core/go/oasis-node/oasis-node /usr/local/bin/
COPY --from=builder /usr/src/oasis-core/target/default/debug/oasis-core-runtime-loader /usr/local/bin/
COPY --from=builder /usr/src/oasis-core/go/oasis-remote-signer/oasis-remote-signer /usr/local/bin/
COPY --from=builder /usr/src/oasis-core/go/oasis-net-runner/oasis-net-runner /usr/local/bin/
COPY --from=builder /usr/src/oasis-ssvm-runtime/target/default/debug/gateway /usr/local/bin/
COPY --from=builder /usr/src/oasis-ssvm-runtime/target/default/debug/oasis-ssvm-runtime /usr/local/bin/
COPY --from=builder /usr/src/tools/ssvm-evmc/libssvm-evmc.so /ssvm/libssvm-evmc.so 
COPY --from=builder /usr/src/metadata-registry-tools/oasis-registry/oasis-registry /usr/local/bin/

# Worker client, Worker P2P, Tendermint P2P
EXPOSE 9100 9200 26656 26657

CMD ["oasis-node"]
