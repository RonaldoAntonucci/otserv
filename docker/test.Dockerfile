FROM ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates git make python3-minimal systemd \
    && git config --system --add safe.directory /workspace \
    && git config --system --add safe.directory /workspace/server \
    && git config --system --add safe.directory /workspace/client \
    && groupadd --system otserv \
    && useradd --system --gid otserv --home-dir /nonexistent --shell /usr/sbin/nologin otserv \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

ENTRYPOINT ["sh", "tests/run-static.sh"]
