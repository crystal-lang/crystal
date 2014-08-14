FROM ubuntu:12.04

RUN \
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E0190A89 && \
  echo "deb http://ppa.launchpad.net/manastech/crystal/ubuntu precise main" > /etc/apt/sources.list.d/manastech-crystal.list && \
  apt-get update && \
  apt-get install -y curl gcc libpcre3-dev libunwind7-dev libgc-dev llvm-3.3-dev libpcl1-dev libssl-dev libstdc++6-4.6-dev && \
  apt-get clean && \

  curl https://s3.amazonaws.com/crystal-lang/crystal-linux64-latest.tar.gz | tar xz -C /opt

WORKDIR /opt/crystal

CMD ["bash"]
