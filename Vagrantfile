# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.define "precise32" do |c|
    c.vm.box = "precise32"
    c.vm.box_url = "http://files.vagrantup.com/precise32.box"
  end

  config.vm.define "precise64" do |c|
    c.vm.box = "precise64"
    c.vm.box_url = "http://files.vagrantup.com/precise64.box"
  end

  config.vm.define("trusty32") { |c| c.vm.box = "ubuntu/trusty32" }
  config.vm.define("trusty64") { |c| c.vm.box = "ubuntu/trusty64" }

  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", 4096]
  end

  config.vm.provision :shell, :privileged => false, :inline => %(
    sudo apt-get update
    sudo apt-get install -y build-essential git libpcre3-dev libunwind7-dev libgc-dev curl llvm-3.3-dev

    git clone /vagrant crystal
    cd crystal
    bin/crystal --setup
  )
end
