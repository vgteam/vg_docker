# vg_docker

[![Build Status](https://travis-ci.org/vgteam/vg_docker.svg?branch=master)](https://travis-ci.org/vgteam/vg_docker)

This repository works in concert with [Travis CI](https://travis-ci.org/vgteam/vg_docker) and [Quay](https://quay.io/repository/vgteam/vg?tab=tags) to build Docker images for [vg](https://github.com/vgteam/vg) in an automated and transparent fashion.

Above, a specific revision of vg is recorded as a git submodule. Updating this repository - particularly the vg submodule revision - causes the generation of a pair of Docker images in Quay:

[![quay.io/vgteam/vg](https://pbs.twimg.com/media/C62UiihUwAE99R3.jpg:large)](https://quay.io/repository/vgteam/vg?tab=tags)](https://quay.io/repository/vgteam/vg?tab=tags)

In this example pair, each image derives from vg git revision [`37f68b6e`](https://github.com/vgteam/vg/commit/37f68b6e0852e9931d54b3082060dd32748b78da). (v1.4.0 is the most recent tag on the lineage leading to that revision, and said lineage has 2,425 commits following tag v1.4.0.)
* The `-run` image contains the statically linked vg executable and a few useful scripts and tools, suitable for low-overhead runtime deployment.
* The `-build` image contains the fully compiled source tree of vg in which the aforementioned executable was built from scratch, thereafter useful for fiddling with the build or test suite in a clean environment. 

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

The whole vg source tree, including its many nested submodule dependencies, is built from scratch on each update according to the recipe found in [Dockerfile.build](https://github.com/vgteam/vg_docker/blob/master/Dockerfile.build). This process is fairly complementary to the [vg repository's Travis CI setup](https://travis-ci.org/vgteam/vg), which takes advantage of Travis CI caching to speed up builds and provide rapid feedback, but can occasionally allow statefulness/dependency problems to fester (this has bitten us a few times).

