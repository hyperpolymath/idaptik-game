# SPDX-License-Identifier: MPL-2.0
set shell := ["bash", "-uc"]
import? "contractile.just"

default:
    @just --list --unsorted

bootstrap:
    git submodule update --init --recursive
    asdf install
    opam install -y dune sedlex menhir ppx_deriving cmdliner yojson

build:
    affinescript compile -o dist/game.wasm src/Main.affine
    scripts/assetpack.sh raw-assets/ public/assets/

run:
    podman run --rm -p 8080:8080 ghcr.io/hyperpolymath/idaptik-game:latest

dev:
    affinescript watch src/ &
    nginx -p . -c container/nginx.conf -g 'daemon off;'

test:
    affinescript test tests/

clean:
    rm -rf dist target _build public/assets

container:
    podman build -t ghcr.io/hyperpolymath/idaptik-game:latest -f Containerfile .

container-stapeln:
    stapeln build --target development

# UMS-game integration smoke (Recovery PR 4)
ums-game-smoke:
    cd ../ums && just generate-test-fixture
    cp ../ums/dist/generated/test.manifest.json dlc-manifests/
    just dev &
    sleep 5
    curl -f http://localhost:8080/dlc/test/check
    kill %1
