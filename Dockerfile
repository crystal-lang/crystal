FROM ubuntu:14.04.4
MAINTAINER crystal-devs <crystal-lang@googlegroups.com>

RUN apt-get update && apt-get update && apt-get install -y apt-transport-https curl build-essential \
pkg-config libssl-dev llvm-3.6 libedit-dev libgmp-dev \
libxml2-dev libyaml-dev libreadline-dev git-core libevent-dev && \
curl https://dist.crystal-lang.org/apt/setup.sh | bash && \
apt-get update && apt-get install -y crystal && \
apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD . /opt/crystal-head

WORKDIR /opt/crystal-head
ENV CRYSTAL_CONFIG_VERSION HEAD
ENV CRYSTAL_CONFIG_PATH libs:/opt/crystal-head/src:/opt/crystal-head/libs
ENV LIBRARY_PATH /opt/crystal/embedded/lib
ENV PATH /opt/crystal-head/bin:/opt/llvm-3.5.0-1/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN make clean crystal release=1
