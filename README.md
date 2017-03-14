# vg_docker

[![Build Status](https://travis-ci.org/vgteam/vg_docker.svg?branch=master)](https://travis-ci.org/vgteam/vg_docker)

This repository orchestrates [Travis CI](https://travis-ci.org/vgteam/vg_docker) and [Quay](https://quay.io/repository/vgteam/vg?tab=tags) to build Docker images for [vg](https://github.com/vgteam/vg) automatically and transparently.

Above, a specific revision of vg is recorded as a git submodule. Updating this repository - particularly the vg submodule revision - causes the generation of a pair of Docker images in Quay:

[![quay.io/vgteam/vg](https://pbs.twimg.com/media/C62UiihUwAE99R3.jpg:large)](https://quay.io/repository/vgteam/vg?tab=tags)](https://quay.io/repository/vgteam/vg?tab=tags)

In this example pair, each image is built from vg git revision [`37f68b6e`](https://github.com/vgteam/vg/commit/37f68b6e0852e9931d54b3082060dd32748b78da). (`v1.4.0` is the newest git tag on the lineage leading to that revision, and this lineage has 2,425 commits following that tag.)
* The `-run` image contains the static vg executable and some additional scripts and tools, suitable for low-overhead runtime deployment.
* The far larger `-build` image contains the fully compiled source tree of vg, in which the aforementioned executable was built from scratch, thereafter useful to fiddle with the build or test suite.

[Click through to quay.io/vgteam/vg](https://quay.io/repository/vgteam/vg?tab=tags) to find the most recently built images.

Example pulling and using the `-run` image:

```
$ sudo docker run -it -v $(pwd):/io quay.io/vgteam/vg:v1.4.0-2425-g37f68b6e-run vg version
Unable to find image 'quay.io/vgteam/vg:v1.4.0-2425-g37f68b6e-run' locally
v1.4.0-2425-g37f68b6e-run: Pulling from vgteam/vg
64c2d346debd: Pull complete 
Digest: sha256:7b4ea8f409132e75a82fc7b22370130624547f944c55d3c14e6bc61d9b2ce92e
Status: Downloaded newer image for quay.io/vgteam/vg:v1.4.0-2425-g37f68b6e-run
v1.4.0-2425-g37f68b6
$
```

Using the `-build` image to run the full test suite:

```
$ sudo docker run -it quay.io/vgteam/vg:v1.4.0-2425-g37f68b6e-build make test
```

The vg source tree, and all its submodules, are built from scratch on each update here, according to the recipe in [Dockerfile.build](https://github.com/vgteam/vg_docker/blob/master/Dockerfile.build). This is complementary to the [vg repository's own Travis CI](https://travis-ci.org/vgteam/vg), which takes advantage of Travis caching to speed up builds and provide rapid feedback, but occasionally hides festering statefulness/dependency problems (that's bitten us a few times).

## vg developers: triggering new image builds

Clone this repository locally, then update the vg submodule revision and push back to GitHub:

```
vg_docker$ git -C vg fetch origin
vg_docker$ git -C vg checkout DESIRED_VG_REVISION
vg_docker$ git add vg
vg_docker$ git commit -m 'vg DESIRED_VG_REVISION'
vg_docker$ git push origin
```

If you'll be iterating rapidly, then as a courtesy you could do this on your own branch of vg_docker instead of master.

Once you push the update, monitor the image build progress on [Travis CI](https://travis-ci.org/vgteam/vg_docker), then hopefully find the new images in [quay.io/vgteam/vg](https://quay.io/repository/vgteam/vg?tab=tags) after 30-40 minutes.

## under the hood

When an update to this repository is pushed,

1. Travis CI finds the update and, according to `.travis.yml` above, runs `build.sh` which:
1. uses `docker build` to bake and test the images (on the Travis CI worker)
1. logs in to Quay using an authentication token for the `vgteam+travis` robot account, stored using a Travis secure environment variable.
1. pushes the images to Quay.

Compared to the convenient automatic build features of Quay and Docker Hub, this methodology provides us more control over how the images are prepared, tested, and tagged.
