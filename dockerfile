FROM alpine:3.18 as builder

ARG OPENWRT_SDK_URL

# Install build dependencies
RUN apk add --no-cache \
    bash \
    curl \
    tar \
    xz \
    coreutils \
    findutils \
    gcc \
    g++ \
    make \
    perl \
    python3 \
    git \
    musl-dev \
    openssl-dev \
    libc-dev

# Download and extract OpenWrt SDK
RUN mkdir -p /openwrt
WORKDIR /openwrt

RUN if [ -n "$OPENWRT_SDK_URL" ]; then \
    echo "Downloading SDK from: $OPENWRT_SDK_URL" && \
    curl -L -o sdk.tar.xz "$OPENWRT_SDK_URL" && \
    tar -xf sdk.tar.xz --strip-components=1 && \
    rm sdk.tar.xz; \
    else \
    echo "Using local SDK files"; \
    fi

# Copy package source
COPY . /openwrt/package/kid-control

# Build the package
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install -a && \
    make defconfig && \
    make package/kid-control/compile V=s

# Copy the built IPK
RUN mkdir -p /output && \
    find ./bin -name "kid-control*.ipk" -exec cp {} /output/ \;

FROM scratch as output
COPY --from=builder /output/ /
