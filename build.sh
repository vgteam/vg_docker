#!/bin/bash
set -ex -o pipefail

# detect the desired git revision of vg from the submodule in this repo
git -C vg fetch --tags origin
vg_git_revision=$(git -C vg rev-parse HEAD)
vg_git_tag="vgteam/vg:$(git -C vg describe --long --always --tags)"

# build a docker image from it
sudo docker build --build-arg "vg_git_revision=${vg_git_revision}" -t "$vg_git_tag" .
# sanity check
sudo docker run -t "$vg_git_tag" version
# full test suite - disabled temporarily pending investigation
# sudo docker run -t --entrypoint=/bin/bash "$vg_git_tag" -c "make test"

# TODO: also generate a slim image with just the static vg executable

# log in to quay.io
sudo docker login -u="mlin" -p="$QUAY_PASSWORD" quay.io
sudo docker push "$vg_git_tag"
