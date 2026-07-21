FROM ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90 AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        libboost-iostreams-dev \
        libboost-json-dev \
        libboost-locale-dev \
        libboost-system-dev \
        libfmt-dev \
        libluajit-5.1-dev \
        libmariadb-dev \
        libmariadb-dev-compat \
        libpugixml-dev \
        libssl-dev \
        ninja-build \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/tfs

COPY server/CMakeLists.txt server/CMakePresets.json ./
COPY server/cmake ./cmake
COPY server/src ./src

RUN cmake --preset default \
        -DBUILD_TESTING=OFF \
        -DSKIP_GIT=ON \
        -DUSE_LUAJIT=ON \
    && cmake --build --preset default --config RelWithDebInfo --parallel 2

FROM ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90 AS runtime

LABEL org.opencontainers.image.source="https://github.com/RonaldoAntonucci/forgottenserver" \
      org.opencontainers.image.revision="098641981400f8ff89959f427f0e8718d9dd22e2" \
      org.opencontainers.image.version="1.6"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        libboost-iostreams1.83.0 \
        libboost-json1.83.0 \
        libboost-locale1.83.0 \
        libboost-system1.83.0 \
        libfmt9 \
        libluajit-5.1-2 \
        libmariadb3 \
        libpugixml1v5 \
        libssl3t64 \
    && groupadd --gid 10001 otserv \
    && useradd --uid 10001 --gid 10001 --home-dir /srv --shell /usr/sbin/nologin otserv \
    && install --directory --owner otserv --group otserv /srv \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/src/tfs/build/RelWithDebInfo/tfs /usr/local/bin/tfs
COPY --chown=otserv:otserv docker/config.lua /srv/config.lua
COPY --chown=otserv:otserv server/schema.sql server/key.pem /srv/
COPY --chown=otserv:otserv server/data /srv/data

USER otserv
WORKDIR /srv

EXPOSE 7171 7172

ENTRYPOINT ["/usr/local/bin/tfs"]
