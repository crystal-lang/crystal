# -*- mode: ruby -*-
# vi: set ft=ruby :

# Usage
#
# ```
# $ vagrant up xenial64
# $ vagrant ssh xenial64
# vagrant@ubuntu-xenial:~$ cd ~/crystal/
# vagrant@ubuntu-xenial:~$ make std_spec
# ```
#
# The working directory is also available at /vagrant
# but using the clone in ~/crystal helps isolating the binaries
# from each platform and it can be faster on some circumstances
# where files are shared with host since the clone is in the
# native fs.
#
# To use Makefile targets on some machines the `FLAGS=--no-debug`
# might be needed to reduce the memory footprint.
#
# Notes:
# * Running specs from /vagrant directly might cause some failures in
#   specs related to permissions.
# * bionic64 std_spec fails #6577
# * xenial32 FLAGS=--no-debug is unable to run compiler_spec.
# * trusty64 FLAGS=--no-debug is unable to build the compiler.
# * precise32 is unable to build std_spec due to outdated libxml2. ~> 2.9.0 is required.
# * precise32 will fail running std_spec related to reuse_port & ipv6.
# * freebsd needs post install manual scripts in order to install crystal.
# * alpine provisionning is failing due to openssl libressl issues.
# * there is no crystal pre built package for alpine32
#

def clone_crystal_from_vagrant(config)
  # use ~/crystal directory instead of /vagrant
  # to have a clean copy of working directory
  # in the native fs of the vm
  config.vm.provision :shell, privileged: false, inline: %(
    git clone /vagrant crystal
  )
end

# *llvm* values: 6.0, 7, (empty), Hash with {url:, path:}
def install_llvm(dist, llvm)
  llvm ||= "6.0"

  if llvm.is_a?(Hash)
    %(
      curl -s #{llvm[:url]} | tar xz -C /opt
      echo 'export PATH="$PATH:/opt/#{llvm[:path]}/bin"' >> /etc/profile.d/crystal.sh
    )
  else
    llvm_suffix = llvm != "" ? "-#{llvm}" : ""

    %(
      add-apt-repository "deb http://apt.llvm.org/#{dist}/ llvm-toolchain-#{dist}#{llvm_suffix} main"
      curl -sSL https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
      apt-get update
      apt-get install -y llvm#{llvm_suffix}-dev
    )
  end
end

# define a ubuntu box with the given *name*
# *llvm* values: 6.0, 7, (empty), Hash with {url:, path:}
def define_ubuntu(config, name:, dist:, bits:, llvm: nil)
  install_cxx =
    if dist == "precise"
      # llvm 3.9 requires g++ 4.7 or greater and is not the one shipped in precise
      %(
        add-apt-repository ppa:ubuntu-toolchain-r/test
        apt-get update
        apt-get install -y g++-4.7
        echo 'export CXX=g++-4.7' >> /etc/profile.d/crystal.sh
      )
    end

  register_crystal_key =
    if dist == "precise" || dist == "trusty"
      %(
        apt-key adv --keyserver keys.gnupg.net --recv-keys 09617FD37CC06B54
      )
    end

  config.vm.define(name) do |c|
    c.vm.box = "ubuntu/#{dist}#{bits}"

    if bits == 32
      config.vm.provider "virtualbox" do |vb|
        vb.memory = 4*1024
      end
    end

    c.vm.provision :shell, inline: %(
      echo '' > /etc/profile.d/crystal.sh

      apt-get install -y apt-transport-https curl build-essential git
      apt-get install -y libxml2-dev libyaml-dev libreadline-dev libgmp3-dev libssl-dev
      apt-get install -y

      #{install_llvm(dist, llvm)}

      #{install_cxx}

      #{register_crystal_key}

      curl -s https://dist.crystal-lang.org/apt/setup.sh | sh
      apt-get install -y crystal

      echo 'export LIBRARY_PATH="/usr/lib/crystal/lib/"' >> /etc/profile.d/crystal.sh
    )

    clone_crystal_from_vagrant(c)
  end
end

# define a ubuntu box with the given *name*
# *llvm* values: 6.0, 7, (empty), Hash with {url:, path:}
def define_debian(config, name:, dist:, bits:, llvm: nil)
  register_crystal_key =
    if dist == "stretch"
      %(
        apt-key adv --keyserver keys.gnupg.net --recv-keys 09617FD37CC06B54
      )
    end

  config.vm.define(name) do |c|
    c.vm.box = "debian/#{dist}#{bits}"

    c.vm.provision :shell, inline: %(
      echo '' > /etc/profile.d/crystal.sh

      apt-get install -y software-properties-common apt-transport-https dirmngr curl build-essential git
      apt-get install -y libxml2-dev libyaml-dev libreadline-dev libgmp3-dev libssl-dev
      apt-get install -y

      #{install_llvm(dist, llvm)}

      #{register_crystal_key}

      curl -s https://dist.crystal-lang.org/apt/setup.sh | sh
      apt-get install -y crystal

      echo 'export LIBRARY_PATH="/usr/lib/crystal/lib/"' >> /etc/profile.d/crystal.sh
    )

    clone_crystal_from_vagrant(c)
  end
end

def define_freebsd(config, name:, box:)
  config.vm.define name do |c|
    c.ssh.shell = "sh"
    c.vm.box = "freebsd/FreeBSD-#{box}"

    c.vm.hostname = name
    c.vm.base_mac = "6658695E16F0"

    c.vm.network "private_network", type: "dhcp"
    c.vm.synced_folder ".", "/vagrant", type: "nfs"

    c.vm.provision :shell, inline: %(
      pkg install -y git gmake pkgconf
      pkg install -y libyaml gmp libunwind libevent pcre boehm-gc-threaded
      pkg install -y llvm60
    )

    c.vm.post_up_message = <<-MSG

    To install crystal from sources:

    $ sudo portsnap fetch extract
    $ sudo make -C/usr/ports/lang/crystal/ reinstall clean BATCH=yes
    $ sudo make -C/usr/ports/devel/shards/ reinstall clean BATCH=yes

    To install pre-built crystal:

    $ sudo pkg install -y crystal shards

    Compile crystal with:

    $ cd ~/crystal
    $ gmake crystal

    MSG

    clone_crystal_from_vagrant(c)
  end
end

def define_alpine(config, name:, bits:)
  config.vm.define name do |c|
    c.vm.box = "alpine/alpine#{bits}"

    if bits == 32
      config.vm.provider "virtualbox" do |vb|
        vb.memory = 4*1024
      end
    end

    c.vm.provision :shell, inline: %(
      apk add --no-cache \
        git gcc g++ make automake libtool autoconf bash coreutils \
        zlib-dev yaml-dev pcre-dev libxml2-dev readline-dev openssl-dev \
        llvm4-dev llvm4-static \
        crystal shards
    )

    c.vm.post_up_message = <<-MSG
    Before building crystal will need to select set LLVM_CONFIG

    $ export LLVM_CONFIG=llvm4-config

    if profision failed, you might need to clone /vagrant manually

    $ git clone /vagrant crystal

    MSG

    clone_crystal_from_vagrant(c)
  end
end

Vagrant.configure("2") do |config|
  define_ubuntu config, name: 'bionic64', dist: 'bionic', bits: 64
  define_ubuntu config, name: 'xenial64', dist: 'xenial', bits: 64
  define_ubuntu config, name: 'xenial32', dist: 'xenial', bits: 32
  # llvm packages > 3.8 are not available for precise/trusty. Using pre built packages
  define_ubuntu config, name: 'trusty64', dist: 'trusty', bits: 64, llvm: { url: "http://crystal-lang.s3.amazonaws.com/llvm/llvm-3.9.1-1-linux-x86_64.tar.gz", path: "llvm-3.9.1-1" }
  define_ubuntu config, name: 'trusty32', dist: 'trusty', bits: 32, llvm: { url: "http://crystal-lang.s3.amazonaws.com/llvm/llvm-3.9.1-1-linux-i686.tar.gz", path: "llvm-3.9.1-1" }
  define_ubuntu config, name: 'precise64', dist: 'precise', bits: 64, llvm: { url: "http://crystal-lang.s3.amazonaws.com/llvm/llvm-3.9.1-1-linux-x86_64.tar.gz", path: "llvm-3.9.1-1" }
  define_ubuntu config, name: 'precise32', dist: 'precise', bits: 32, llvm: { url: "http://crystal-lang.s3.amazonaws.com/llvm/llvm-3.9.1-1-linux-i686.tar.gz", path: "llvm-3.9.1-1" }

  define_debian config, name: 'stretch64', dist: 'stretch', bits: 64
  define_debian config, name: 'jessie64', dist: 'jessie', bits: 64

  define_freebsd config, name: 'freebsd11', box: '11.2-STABLE'

  define_alpine config, name: 'alpine64', bits: 64
  define_alpine config, name: 'alpine32', bits: 32

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 6*1024
    vb.cpus = 2

    # Keep time synced with host
    # vb.customize [ "guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 10000 ]
  end
end
