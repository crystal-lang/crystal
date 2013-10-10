# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"
  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", 2048]
  end

  config.vm.provision :shell, :inline => %(
    wget --progress=bar:force -O - https://s3.amazonaws.com/crystal-lang/llvm-3.3.tar.gz | tar xz --strip-components=1 -C /usr
    apt-get update
    apt-get install -y ruby1.9.3 build-essential git libpcre3-dev libunwind7-dev
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
