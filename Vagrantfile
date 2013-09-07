# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"

  config.vm.provision :shell, :inline => %(
    echo "deb http://llvm.org/apt/precise/ llvm-toolchain-precise main" > /etc/apt/sources.list.d/llvm.list
    wget -O - http://llvm.org/apt/llvm-snapshot.gpg.key | apt-key add -
    apt-get update
    apt-get install -y ruby1.9.3 build-essential git llvm-3.3 libpcre3-dev libunwind7-dev
    gem install bundler --no-ri --no-rdoc

    if [ ! -a crystal ]; then
      git clone /vagrant crystal
      cd crystal
      bundle install --path .bundle
      cd ..
      chown vagrant:vagrant -R crystal
    fi
  )
end
