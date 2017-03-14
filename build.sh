#!/bin/bash
set -ex -o pipefail

# detect the desired git revision of vg from the submodule in this repo
git -C vg fetch --tags origin
vg_git_revision=$(git -C vg rev-parse HEAD)
image_tag_prefix="quay.io/vgteam/vg:$(git -C vg describe --long --always --tags)"

# make a docker image vg:xxxx-build from the fully-built source tree; details in Dockerfile.build
sudo docker pull ubuntu:16.04
sudo docker build --no-cache --build-arg "vg_git_revision=${vg_git_revision}" -t "${image-tag-prefix}-build" - < Dockerfile.build
sudo docker run -t "${image-tag-prefix}-build" vg version # sanity check

# run full test suite - disabled temporarily pending investigation of some problems
# we do this outside of Dockerfile.build so that the image doesn't get cluttered with
# filesystem debris generated by the test suite
# sudo docker run -t "${image-tag-prefix}-build" make test

# now make a separate docker image with just the binaries, scripts, and minimal runtime dependencies:
# - copy binaries & scripts out of the previous image into a directory we'll use as a build context for the new image
mkdir -p ctx/vg/
temp_container_id=$(sudo docker create "${image-tag-prefix}-build")
sudo docker cp "${temp_container_id}:/vg/bin/" ctx/vg/bin/
sudo docker cp "${temp_container_id}:/vg/scripts/" ctx/vg/scripts/
# - synthesize a Dockerfile for a new image with that stuff along with the minimal apt dependencies
echo "FROM ubuntu:16.04
MAINTAINER vgteam
RUN apt-get -qq update && apt-get -qq install -y curl wget jq samtools
RUN apt-get clean
COPY vg/ /vg/
" > ctx/Dockerfile
ls -lR ctx
# - build image from this synthesized context
sudo docker build --no-cache -t "${image-tag-prefix}-run-preprecursor" ctx/
# - flatten the image, to further reduce its deploy size, and set up the runtime ENV/WORKDIR etc.
temp_container_id=$(sudo docker create "${image-tag-prefix}-run-preprecursor")
sudo docker export "$temp_container_id" | sudo docker import - "${image-tag-prefix}-run-precursor"
echo "FROM ${image-tag-prefix}-run-precursor" '
ENV PATH /vg/bin:$PATH
WORKDIR /vg' | sudo docker build -t "${image-tag-prefix}-run" -
# sanity check
sudo docker run -t "${image-tag-prefix}-run" vg version

# log in to quay.io
set +x # IMPORTANT: avoids leaking encrypted password into travis log
sudo docker login -u="vgteam+travis" -p="$QUAY_PASSWORD" quay.io
set -x

# push images
sudo docker push "${image-tag-prefix}-build"
sudo docker push "${image-tag-prefix}-run"
