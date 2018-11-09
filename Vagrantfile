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
# * precise32 is unable to build std_spec due to outdated libxml2. ~> 2.9.0 is required
# * precise32 will fail running std_spec related to reuse_port & ipv6

def clone_crystal_from_vagrant(config)
  # use ~/crystal directory instead of /vagrant
  # to have a clean copy of working directory
  # in the native fs of the vm
  config.vm.provision :shell, privileged: false, inline: %(
    git clone /vagrant crystal
  )
end

# define a ubuntu box with the given *name*
# *llvm* values: 6.0, 7, (empty), Hash with {url:, path:}
def define_ubuntu(config, name:, dist:, bits:, llvm: "6.0")
  install_llvm =
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

      #{install_llvm}

      #{install_cxx}

      #{register_crystal_key}

      curl -s https://dist.crystal-lang.org/apt/setup.sh | sh
      apt-get install -y crystal

      echo 'export LIBRARY_PATH="/usr/lib/crystal/lib/"' >> /etc/profile.d/crystal.sh
    )

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

  [[:jessie, '3.5'], [:stretch, '3.9']].product([32, 64]).each do |(dist, ver), bits|
    box_name = "#{dist}#{bits}"

    config.vm.define(box_name) do |c|
      c.vm.box = "debian/#{box_name}"

      c.vm.provision :shell, inline: %(
        apt-get -y install apt-transport-https dirmngr
        apt-key adv --keyserver keys.gnupg.net --recv-keys 09617FD37CC06B54
        echo 'deb https://dist.crystal-lang.org/apt crystal main' > /etc/apt/sources.list.d/crystal.list
        apt-get update
        apt-get -y install crystal curl git libgmp3-dev zlib1g-dev libedit-dev libxml2-dev libssl-dev libyaml-dev libreadline-dev g++ llvm-#{ver} llvm-#{ver}-dev
        echo 'export LIBRARY_PATH="/opt/crystal/embedded/lib"' > /etc/profile.d/crystal.sh
      )

      clone_crystal_from_vagrant.call(c)
    end
  end

  config.vm.define "freebsd" do |c|
    c.ssh.shell = "csh"
    c.vm.box = "freebsd/FreeBSD-10.2-RELEASE"

    c.vm.network "private_network", type: "dhcp"
    c.vm.synced_folder ".", "/vagrant", type: "nfs"

    # to build boehm-gc from git repository:
    #c.vm.provision :shell, inline: %(
    #  pkg install -y libtool automake autoconf libatomic_ops
    #)

    c.vm.provision :shell, inline: %(
      pkg install -y git gmake pkgconf pcre libunwind clang36 libyaml gmp libevent2
    )

    clone_crystal_from_vagrant(c)
  end

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 6*1024
    vb.cpus = 2

    # Keep time synced with host
    # vb.customize [ "guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 10000 ]
  end
end
