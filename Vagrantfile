# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  %w(precise64 trusty64).each do |box|
    config.vm.define(box) { |c| c.vm.box = "ubuntu/#{box}" }
  end

  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", 4096]
  end

  config.vm.provision :shell, inline: %(
    curl -s http://dist.crystal-lang.org/apt/setup.sh | bash
    apt-get install -y crystal git libgmp3-dev zlib1g-dev libedit-dev libxml2-dev libssl-dev libyaml-dev libreadline-dev
    curl -s http://crystal-lang.s3.amazonaws.com/llvm/llvm-3.5.0-1-linux-x86_64.tar.gz | tar xz -C /opt
    echo 'export LIBRARY_PATH="/opt/crystal/embedded/lib"' > /etc/profile.d/crystal.sh
    echo 'export PATH="$PATH:/opt/llvm-3.5.0-1/bin"' >> /etc/profile.d/crystal.sh
  )

  config.vm.provision :shell, privileged: false, inline: %(
    git clone /vagrant crystal
  )
end
