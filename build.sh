#!/bin/bash
set -ex -o pipefail

# detect the desired git revision of vg from the submodule in this repo
vg_git_revision=$(git -C vg rev-parse HEAD)
vg_git_tag="vgteam/vg:$(git -C vg describe --long --always --tags)"

# build a docker image from it
sudo docker build --build-arg "vg_git_revision=${vg_git_revision}" -t "$vg_git_tag" .
# sanity check
sudo docker run "$vg_git_tag" version
# full test suite
sudo docker run --entrypoint /bin/bash "$vg_git_tag" make test

# TODO: also generate a slim image with just the static vg executable
