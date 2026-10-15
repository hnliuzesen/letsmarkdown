FROM rust:alpine AS backend
WORKDIR /home/rust/src
RUN apk --no-cache add musl-dev openssl-dev
COPY Cargo.toml Cargo.lock ./
COPY letsmarkdown-server letsmarkdown-server
COPY letsmarkdown-wasm letsmarkdown-wasm
RUN cargo test --release --locked -p letsmarkdown-server
RUN cargo build --release --locked -p letsmarkdown-server

# The prebuilt ARM wasm-bindgen CLI requires glibc.
FROM --platform=$BUILDPLATFORM rust:slim AS wasm
WORKDIR /home/rust/src
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh
COPY Cargo.toml Cargo.lock ./
COPY letsmarkdown-server letsmarkdown-server
COPY letsmarkdown-wasm letsmarkdown-wasm
RUN wasm-pack build --target web letsmarkdown-wasm --locked

FROM --platform=$BUILDPLATFORM node:lts-alpine AS frontend
WORKDIR /usr/src/app
COPY package.json package-lock.json ./
COPY --from=wasm /home/rust/src/letsmarkdown-wasm/pkg letsmarkdown-wasm/pkg
RUN npm ci
COPY . .
RUN npm run test:wasm
RUN npm run build

FROM scratch
COPY --from=frontend /usr/src/app/dist dist
COPY --from=backend /home/rust/src/target/release/letsmarkdown-server .
USER 1000:1000
CMD [ "./letsmarkdown-server" ]
