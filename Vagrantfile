# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"

  config.vm.provision :shell, :inline => %(
    apt-get update
    apt-get install -y ruby1.9.3 build-essential git llvm-3.1-dev clang libpcre3-dev
    update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-3.1 31
    update-alternatives --install /usr/bin/llc llc /usr/bin/llc-3.1 31
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
