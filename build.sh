#!/bin/bash

# log in to quay.io
set +x # avoid leaking encrypted password into travis log
docker login -u="vgteam+travis" -p="$QUAY_PASSWORD" quay.io

set -ex -o pipefail

# detect the desired git revision and URL for vg from the submodule in this repo
git -C vg fetch --tags origin
vg_git_revision=$(git -C vg rev-parse HEAD)
# This will be "" unless we are building a tag, in which case it will be the tag
vg_release_tag=$(git -C vg describe --exact-match --tags HEAD 2>/dev/null || true)
vg_git_url=$(git -C vg remote get-url origin)

if [[ "${TRAVIS_BRANCH}" == "master" && -z "${TRAVIS_PULL_REQUEST_BRANCH}" ]]; then
    # This is a push build of the master branch
     dev_tag=""
else
    # This is a custom build
    # TODO: push to a different Quay repo
    dev_tag="dev-"
fi

image_repo="quay.io/vgteam/vg"
image_tag_prefix="${image_repo}:${dev_tag}$(git -C vg describe --long --always --tags)-t${TRAVIS_BUILD_NUMBER}"
if [[ ! -z "${vg_release_tag}" ]] ; then
    image_release_with_tag="${image_repo}:${dev_tag}${vg_release_tag}"
else
    image_release_with_tag=""
fi

# make a docker image vg:xxxx-build from the fully-built source tree; details in Dockerfile.build
docker pull ubuntu:16.04
mkdir ctx/
cp Dockerfile.build ctx/Dockerfile
cp -R deps ctx/
ls -lR ctx 
docker build --no-cache --build-arg "vg_git_revision=${vg_git_revision}" --build-arg "vg_git_url=${vg_git_url}" -t "${image_tag_prefix}-build" ctx/
rm -Rf ctx/
docker run -t "${image_tag_prefix}-build" vg version # sanity check

# check that the compiled executable does not have AVX2 instructions, to ensure it
# can be used on moderately old (Ivy Bridge) CPUs. See Dockerfile.build for how we
# tune the compilation; this is a regression check.
exit_code=0
docker run --rm "${image_tag_prefix}-build" /bin/bash -e -c 'objdump -d /vg/bin/vg | grep vperm2i128' || exit_code=$?
if (( exit_code == 0 )); then
    echo "PORTABILITY REGRESSION: the vg executable has AVX2 instructions (vperm2i128) incompatible with slightly older CPUs. Check -march/-mtune compiler flags for vg and submodules."
    exit 1
fi

# run full test suite
# we do this outside of Dockerfile.build so that the image doesn't get cluttered with
# filesystem debris generated by the test suite
exit_code=0
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
cp -R deps/ ctx/deps
# - synthesize a Dockerfile for a new image with that stuff along with the minimal apt dependencies
echo "FROM ubuntu:16.04
MAINTAINER vgteam
RUN apt-get -qq update && apt-get -qq install -y curl wget pigz dstat pv jq samtools tabix parallel fontconfig-config
ADD deps/bwa_0.7.15-5_amd64.deb /tmp/bwa.deb
RUN dpkg -i /tmp/bwa.deb && rm /tmp/bwa.deb
RUN apt-get clean
COPY vg/ /vg/
" > ctx/Dockerfile
ls -lR ctx
# - build image from this synthesized context
docker build --no-cache -t "${image_tag_prefix}-run-preprecursor" ctx/
rm -Rf ctx/
# - flatten the image, to further reduce its deploy size, and set up the runtime ENV/WORKDIR etc.
temp_container_id=$(docker create "${image_tag_prefix}-run-preprecursor")
docker export "$temp_container_id" | docker import - "${image_tag_prefix}-run-precursor"
echo "FROM ${image_tag_prefix}-run-precursor" '
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/vg/bin
WORKDIR /vg
CMD /bin/bash' | docker build -t "${image_tag_prefix}-run" -
# sanity check
docker run -t "${image_tag_prefix}-run" vg version

# push images to quay.io
docker push "${image_tag_prefix}-build"
docker push "${image_tag_prefix}-run"

if [ -n "${image_release_with_tag}" ] && [ -z "${dev_tag}" ] ; then
    # We just built a release. Tag it as such
    docker tag "${image_tag_prefix}-run" "${image_release_with_tag}"
    docker push "${image_release_with_tag}"

    # mirror release images to Docker Hub too
    set +x
    docker login -u="vgdockerci" -p="$VGDOCKERCI_PASSWORD"
    docker tag "${image_tag_prefix}-run" "variantgraphs/vg:${vg_release_tag}"
    docker push "variantgraphs/vg:${vg_release_tag}"
    docker tag "${image_tag_prefix}-run" "variantgraphs/vg"
    docker push "variantgraphs/vg"
fi
