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
# The vagrant machines will be provisined with a native crystal
# package or with the targz version downloaded from github.
# Set `INSTALL_GITHUB_TARGZ` to download .tar.gz files from github.
#
# ```
# $ INSTALL_GITHUB_TARGZ=true vagrant up xenial64
# ```
#
# Configuration via environment variables
#
# * `INSTALL_GITHUB_TARGZ=true|false` native package vs github tar.gz installation
# * `VM_CPUS=N` number of cpus (default: 2)
# * `VM_MEMORY_MB=N` megabytes of ram for vm (default: 4096)
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
# * alpine is unable to to use the github .tar.gz compiler
#

INSTALL_GITHUB_TARGZ = ENV.fetch("INSTALL_GITHUB_TARGZ", false) == "true"

GITHUB_URL = "https://github.com/crystal-lang/crystal/releases/download/0.27.0/crystal-0.27.0-1"
CRYSTAL_LINUX64_TARGZ = "#{GITHUB_URL}-linux-x86_64.tar.gz"
CRYSTAL_LINUX32_TARGZ = "#{GITHUB_URL}-linux-i686.tar.gz"

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

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = ENV.fetch("VM_CPUS", "2").to_i

    # Keep time synced with host
    # vb.customize [ "guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 10000 ]
  end
end

def clone_crystal_from_vagrant(config)
  # use ~/crystal directory instead of /vagrant
  # to have a clean copy of working directory
  # in the native fs of the vm
  config.vm.provision :shell, privileged: false, inline: %(
    git clone /vagrant crystal
  )
end

def setup_memory(config, bits)
  memory = ENV.fetch("VM_MEMORY_MB", "4096").to_i
  memory = [memory, 4096].min if bits == 32

  config.vm.provider "virtualbox" do |vb|
    vb.memory = memory
  end
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

# instructions to install crystal binary on all platforms
def install_crystal(c, family, dist:, bits:, github_targz:)
  if github_targz
    fail "github .tar.gz installation method for #{family} is not supported" unless family == "ubuntu" || family == "debian"

    targz_url = bits == 64 ? CRYSTAL_LINUX64_TARGZ : CRYSTAL_LINUX32_TARGZ

    c.vm.provision :shell, inline: %(
      mkdir -p /opt/crystal
      echo '#{targz_url}'
      curl -sSL '#{targz_url}' | tar xz -C /opt/crystal --strip-component=1 -f -

      echo 'export LIBRARY_PATH=/opt/crystal/lib/crystal/lib/:${LIBRARY_PATH}' >> /etc/profile.d/crystal.sh
      echo 'export PATH=/opt/crystal/bin:$PATH' >> /etc/profile.d/crystal.sh
    )
  else
    case family
    when "ubuntu"
      register_crystal_key =
        if dist == "precise" || dist == "trusty"
          %(
            apt-key adv --keyserver keys.gnupg.net --recv-keys 09617FD37CC06B54
          )
        end

      c.vm.provision :shell, inline: %(
        #{register_crystal_key}

        curl -s https://dist.crystal-lang.org/apt/setup.sh | sh
        apt-get install -y crystal

        echo 'export LIBRARY_PATH="/usr/lib/crystal/lib/"' >> /etc/profile.d/crystal.sh
      )
    when "debian"
      register_crystal_key =
        if dist == "stretch"
          %(
            apt-key adv --keyserver keys.gnupg.net --recv-keys 09617FD37CC06B54
          )
        end

      c.vm.provision :shell, inline: %(
        #{register_crystal_key}

        curl -s https://dist.crystal-lang.org/apt/setup.sh | sh
        apt-get install -y crystal

        echo 'export LIBRARY_PATH="/usr/lib/crystal/lib/"' >> /etc/profile.d/crystal.sh
      )
    when "freebsd"
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
    when "alpine"
      c.vm.provision :shell, inline: %(
        apk add --no-cache crystal shards \
          || echo "WARNING: apk failed (ignored)"
      )
    end
  end
end

# define a ubuntu box with the given *name*
# *llvm* values: 6.0, 7, (empty), Hash with {url:, path:}
def define_ubuntu(config, name:, dist:, bits:, llvm: nil, github_targz: INSTALL_GITHUB_TARGZ)
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

  config.vm.define(name) do |c|
    c.vm.box = "ubuntu/#{dist}#{bits}"

    setup_memory(config, bits)

    libevent_ver =
      if dist == "bionic"
        "2.1-6"
      else
        "2.0-5"
      end

    c.vm.provision :shell, inline: %(
      echo '' > /etc/profile.d/crystal.sh

      apt-get install -y apt-transport-https curl build-essential git
      apt-get install -y libxml2-dev libyaml-dev libreadline-dev libgmp3-dev libssl-dev libpcre3-dev \
        libevent-dev libevent-core-#{libevent_ver} libevent-extra-#{libevent_ver} libevent-openssl-#{libevent_ver} libevent-pthreads-#{libevent_ver}

      #{install_llvm(dist, llvm)}

      #{install_cxx}
    )

    install_crystal(c, "ubuntu", dist: dist, bits: bits, github_targz: github_targz)

    clone_crystal_from_vagrant(c)
  end
end

# define a ubuntu box with the given *name*
# *llvm* values: 6.0, 7, (empty), Hash with {url:, path:}
def define_debian(config, name:, dist:, bits:, llvm: nil, github_targz: INSTALL_GITHUB_TARGZ)
  config.vm.define(name) do |c|
    c.vm.box = "debian/#{dist}#{bits}"

    setup_memory(config, bits)

    c.vm.provision :shell, inline: %(
      echo '' > /etc/profile.d/crystal.sh

      apt-get install -y software-properties-common apt-transport-https dirmngr curl build-essential git pkg-config
      apt-get install -y zlib1g-dev libxml2-dev libyaml-dev libreadline-dev libgmp3-dev libssl-dev libpcre3-dev \
        libevent-dev libevent-core-2.0-5 libevent-extra-2.0-5 libevent-openssl-2.0-5 libevent-pthreads-2.0-5

      #{install_llvm(dist, llvm)}
    )

    install_crystal(c, "debian", dist: dist, bits: bits, github_targz: github_targz)

    clone_crystal_from_vagrant(c)
  end
end

def define_freebsd(config, name:, box:)
  config.vm.define name do |c|
    c.ssh.shell = "sh"
    c.vm.box = "freebsd/FreeBSD-#{box}"
    setup_memory(config, 64)

    c.vm.hostname = name
    c.vm.base_mac = "6658695E16F0"

    c.vm.network "private_network", type: "dhcp"
    c.vm.synced_folder ".", "/vagrant", type: "nfs"

    c.vm.provision :shell, inline: %(
      mkdir -p /etc/profile.d
      echo '' > /etc/profile.d/crystal.sh
      echo '. /etc/profile.d/crystal.sh' >> /etc/profile

      pkg install -y git gmake pkgconf
      pkg install -y libyaml gmp libunwind libevent pcre boehm-gc-threaded
      pkg install -y llvm60
    )

    install_crystal(c, "freebsd", dist: nil, bits: 64, github_targz: false)

    clone_crystal_from_vagrant(c)
  end
end

def define_alpine(config, name:, bits:, llvm: '4')
  config.vm.define name do |c|
    c.vm.box = "alpine/alpine#{bits}"

    setup_memory(config, bits)

    c.vm.provision :shell, inline: %(
      echo '' > /etc/profile.d/crystal.sh

      echo 'export FLAGS="--target x86_64-linux-musl --link-flags=-no-pie --static"' >> /etc/profile.d/crystal.sh

      apk update

      apk add --no-cache \
        tar curl git gcc g++ make automake libtool autoconf bash coreutils paxmark \
        zlib-dev yaml-dev pcre-dev libxml2-dev gmp-dev readline-dev libressl-dev libatomic_ops libevent-dev gc-dev \
        || echo "WARNING: apk failed (ignored)"

      echo 'export LLVM_CONFIG=llvm#{llvm}-config' >> /etc/profile.d/crystal.sh
      apk add --no-cache llvm#{llvm}-dev llvm#{llvm}-static \
        || echo "WARNING: apk failed (ignored)"
    )

    install_crystal(c, "alpine", dist: nil, bits: bits, github_targz: false)

    clone_crystal_from_vagrant(c)
  end
end

