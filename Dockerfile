FROM ubuntu:16.04
MAINTAINER vgteam
ARG vg_git_revision=master

# Make sure the en_US.UTF-8 locale exists, since we need it for tests
RUN locale-gen en_US en_US.UTF-8 && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales

# install apt dependencies
RUN apt-get -qq update && apt-get -qq install -y \
    pkg-config \
    sudo \
    curl \
    wget \
    unzip \
    bsdmainutils \
    build-essential \
    make \
    automake \
    cmake \
    libtool \
    bison \
    flex \
    git \
    zlib1g-dev \
    libbz2-dev \
    libncurses5-dev \
    libgoogle-perftools-dev \
    libjansson-dev \
    librdf-dev \
    jq \
    bc \
    rs \
    redland-utils \
    raptor2-utils \
    rasqal-utils \
    samtools

# fetch the desired git revision of vg
RUN git clone https://github.com/vgteam/vg.git /vg
WORKDIR /vg
RUN git checkout "$vg_git_revision" && git submodule update --init --recursive

# Build
RUN . ./source_me.sh && make -j$(nproc) && make static

# Set up entrypoint
ENV PATH /vg/bin:$PATH
ENTRYPOINT ["/vg/bin/vg"]
