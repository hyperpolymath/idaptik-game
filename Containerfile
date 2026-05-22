# SPDX-License-Identifier: MPL-2.0
# Containerfile — podman-build fallback. Byte-identical to stapeln.toml runtime.

FROM cgr.dev/chainguard/wolfi-base:latest AS build
USER root
RUN apk add --no-cache ocaml opam dune wabt git

RUN opam init --no-setup --disable-sandboxing && \
    opam install -y dune sedlex menhir ppx_deriving cmdliner yojson && \
    git clone --depth 1 https://github.com/hyperpolymath/affinescript /opt/affinescript && \
    cd /opt/affinescript && dune build

WORKDIR /build
COPY . .

RUN /opt/affinescript/_build/default/bin/main.exe compile -o dist/game.wasm src/Main.affine && \
    /opt/affinescript/scripts/assetpack.sh raw-assets/ public/assets/

FROM cgr.dev/chainguard/nginx:latest AS runtime
USER nonroot
COPY --from=build /build/dist /usr/share/nginx/html/dist
COPY --from=build /build/public /usr/share/nginx/html
COPY container/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
