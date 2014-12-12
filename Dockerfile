FROM manastech/crystal

RUN apt-get update && \
    apt-get install -y build-essential curl

RUN curl http://crystal-lang.s3.amazonaws.com/llvm/llvm-3.5.0-1-linux-x86_64.tar.gz | tar xz -C /opt

ADD . /opt/crystal-head

WORKDIR /opt/crystal-head
ENV CRYSTAL_CONFIG_VERSION head
ENV CRYSTAL_CONFIG_PATH libs:/opt/crystal-head/src:/opt/crystal-head/libs

RUN PATH=$PATH:/opt/llvm-3.5.0-1/bin crystal build --release src/compiler/crystal.cr

ENV LIBRARY_PATH /opt/crystal/embedded/lib
ENV PATH /opt/crystal-head:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
