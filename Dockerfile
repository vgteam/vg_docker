
## Use a base ubuntu install
FROM ubuntu:14.04
MAINTAINER vgteam

## Download dependencies for vg, pretty standard fare
#RUN sed 's/main$/main universe/' -i /etc/apt/sources.list
RUN apt-get update && apt-get install -y software-properties-common \
    gcc-4.9-base \
    g++ \
    ncurses-dev \
    pkg-config \
    build-essential \
    libjansson-dev \
    automake \
    libevent-2.0-5 \
    libevent-pthreads-2.0-5 \
    libpomp-dev \
    libtool \
    curl \
    unzip \
    wget \
    libbz2-dev \
    gzip \
    git \
    cmake \
    libsnappy-dev \
    libgflags-dev \
    zlib1g-dev

    #python-dev \
    #protobuf-compiler \
    #libprotoc-dev \
    
    #RUN apt-get update

## Set CXXFLAGS and CFLAGS for gcc to use SSE4.1
#ENV CXXFLAGS "-O2 -g march=corei7 -mavx -fopenmp -std=c++11"
#ENV CXXFLAGS "$CXXFLAGS -march=corei7 -mavx"

## Download VG and its git dependencies
RUN git clone --recursive https://github.com/edawson/vg.git /home/vg
RUN cd /home/vg && . ./source_me.sh && make
#RUN cd /home/vg; make
#RUN cp -r /home/vg/include/* /usr/local/include/
ENV LIBRARY_PATH /home/vg/lib:$LIBRARY_PATH
ENV LD_LIBRARY_PATH /home/vg/lib:$LD_LIBRARY_PATH
ENV LD_INCLUDE_PATH /home/vg/include:$LD_INCLUDE_PATH
ENV C_INCLUDE_PATH /home/vg/include:$C_INCLUDE_PATH
ENV CPLUS_INCLUDE_PATH /home/vg/include:$CPLUS_INCLUDE_PATH
ENV INCLUDE_PATH /home/vg/include:$INCLUDE_PATH
ENV PATH /home/vg/bin:$PATH
#RUN cp -r /home/vg/lib/* /usr/local/lib
#RUN ln -s "/home/vg/bin/vg" "/usr/bin/vg"
#CMD cd /home/vg/ && . ./source_me.sh && vg
#ENTRYPOINT vg
