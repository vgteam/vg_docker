#!/bin/bash

# log in to quay.io
set +x # avoid leaking encrypted password into travis log
docker login -u="vgteam+travis" -p="$QUAY_PASSWORD" quay.io

set -ex -o pipefail

# detect the desired git revision of vg from the submodule in this repo
git -C vg fetch --tags origin
vg_git_revision=$(git -C vg rev-parse HEAD)
image_tag_prefix="quay.io/vgteam/vg:$(git -C vg describe --long --always --tags)-t${TRAVIS_BUILD_NUMBER}"

# make a docker image vg:xxxx-build from the fully-built source tree; details in Dockerfile.build
docker pull ubuntu:16.04
docker build --no-cache --build-arg "vg_git_revision=${vg_git_revision}" -t "${image_tag_prefix}-build" - < Dockerfile.build
docker run -t "${image_tag_prefix}-build" vg version # sanity check

# check that the compiled executable does not have AVX2 instructions, for portability
exit_code=0
docker run --rm "${image_tag_prefix}-build" /bin/bash -e -c 'objdump -d /vg/bin/vg | grep vperm2i128' || exit_code=$?
if (( exit_code == 0 )); then
    echo "PORTABILITY REGRESSION DETECTED: the vg executable has AVX2 instructions (vperm2i128) incompatible with slightly older CPUs. Check -march/-mtune compiler flags for vg and submodules."
    exit 1
fi

# run full test suite
# we do this outside of Dockerfile.build so that the image doesn't get cluttered with
# filesystem debris generated by the test suite
docker run -t "${image_tag_prefix}-build" make test || exit_code=$?
if (( exit_code != 0 )); then
    # tests failed...re-tag and push image for debugging
    docker tag "${image_tag_prefix}-build" "${image_tag_prefix}-TESTFAIL"
    docker push "${image_tag_prefix}-TESTFAIL"
    exit $exit_code
fi

# now make a separate docker image with just the binaries, scripts, and minimal runtime dependencies:
# - copy binaries & scripts out of the previous image into a directory we'll use as a build context for the new image
mkdir -p ctx/vg/
temp_container_id=$(docker create "${image_tag_prefix}-build")
docker cp "${temp_container_id}:/vg/bin/" ctx/vg/bin/
docker cp "${temp_container_id}:/vg/scripts/" ctx/vg/scripts/
# - synthesize a Dockerfile for a new image with that stuff along with the minimal apt dependencies
echo "FROM ubuntu:16.04
MAINTAINER vgteam
RUN apt-get -qq update && apt-get -qq install -y curl wget pigz dstat pv jq samtools tabix parallel
ADD http://mirrors.kernel.org/ubuntu/pool/universe/b/bwa/bwa_0.7.15-2_amd64.deb /tmp/bwa.deb
RUN dpkg -i /tmp/bwa.deb && rm /tmp/bwa.deb
RUN apt-get clean
COPY vg/ /vg/
" > ctx/Dockerfile
ls -lR ctx
# - build image from this synthesized context
docker build --no-cache -t "${image_tag_prefix}-run-preprecursor" ctx/
# - flatten the image, to further reduce its deploy size, and set up the runtime ENV/WORKDIR etc.
temp_container_id=$(docker create "${image_tag_prefix}-run-preprecursor")
docker export "$temp_container_id" | docker import - "${image_tag_prefix}-run-precursor"
echo "FROM ${image_tag_prefix}-run-precursor" '
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/vg/bin
WORKDIR /vg
CMD /bin/bash' | docker build -t "${image_tag_prefix}-run" -
# sanity check
docker run -t "${image_tag_prefix}-run" vg version

# push images
docker push "${image_tag_prefix}-build"
docker push "${image_tag_prefix}-run"
