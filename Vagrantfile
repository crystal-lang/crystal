# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"
  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", 4096]
  end

  config.vm.provision :shell, :inline => %(
    apt-get update
    apt-get install -y build-essential git libpcre3-dev libunwind7-dev

    if [ ! -a crystal ]; then
      git clone /vagrant crystal
      chown vagrant:vagrant -R crystal
    fi
  )
end
