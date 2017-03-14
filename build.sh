#!/bin/bash
set -ex -o pipefail

# detect the desired git revision of vg from the submodule in this repo
git -C vg fetch --tags origin
vg_git_revision=$(git -C vg rev-parse HEAD)
image_tag_prefix="quay.io/vgteam/vg:$(git -C vg describe --long --always --tags)"

# make a docker image vg:xxxx-build from the fully-built source tree (Dockerfiles/build)
sudo docker pull ubuntu:16.04
sudo docker build --no-cache --build-arg "vg_git_revision=${vg_git_revision}" -t "${image-tag-prefix}-build" - < Dockerfiles/build
sudo docker run -t "${image-tag-prefix}-build" vg version # sanity check

# run full test suite - disabled temporarily pending investigation of some problems
# sudo docker run -t "${image-tag-prefix}-build" make test

# make a second docker image vg:xxxx-run with just the binaries, scripts, and minimal runtime dependencies (Dockerfiles/run)
mkdir -p ctx/vg/
cp Dockerfiles/run ctx/Dockerfile
temp_container_id=$(sudo docker create "${image-tag-prefix}-build")
sudo docker cp "${temp_container_id}:/vg/bin/" ctx/vg/bin/
sudo docker cp "${temp_container_id}:/vg/scripts/" ctx/vg/scripts/
tree ctx
sudo docker build --no-cache -t "${image-tag-prefix}-run" ctx/
sudo docker run -t "${image-tag-prefix}-run" vg version # sanity check

# log in to quay.io
set +x # IMPORTANT: avoids leaking encrypted password into travis log
sudo docker login -u="vgteam+travis" -p="$QUAY_PASSWORD" quay.io
set -x

# push images
sudo docker push "${image-tag-prefix}-build"
sudo docker push "${image-tag-prefix}-run"
