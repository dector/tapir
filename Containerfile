FROM docker.io/oven/bun:1 AS builder

RUN bun add -g @mariozechner/pi-coding-agent

FROM docker.io/debian:bookworm-slim AS runtime

ARG APP_DIR=/project

ENV BUN_INSTALL="/root/.bun"
ENV PATH="${BUN_INSTALL}/bin:/usr/local/bin:${PATH}"

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates git \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/bun /usr/local/bin/bun
COPY --from=builder /root/.bun /root/.bun

WORKDIR ${APP_DIR}

CMD ["pi", "--help"]
