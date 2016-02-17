# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  %w(precise trusty vivid).product([32, 64]).each do |dist, bits|
    box_name = "#{dist}#{bits}"
    config.vm.define(box_name) { |c| c.vm.box = "ubuntu/#{box_name}" }
  end

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 4096
    vb.cpus = 2
  end

  config.vm.provision :shell, inline: %(
    curl -s http://dist.crystal-lang.org/apt/setup.sh | bash
    apt-get install -y crystal git libgmp3-dev zlib1g-dev libedit-dev libxml2-dev libssl-dev libyaml-dev libreadline-dev g++
    curl -s http://crystal-lang.s3.amazonaws.com/llvm/llvm-3.5.0-1-linux-`uname -m`.tar.gz | tar xz -C /opt
    echo 'export LIBRARY_PATH="/opt/crystal/embedded/lib"' > /etc/profile.d/crystal.sh
    echo 'export PATH="$PATH:/opt/llvm-3.5.0-1/bin"' >> /etc/profile.d/crystal.sh
  )

  config.vm.provision :shell, privileged: false, inline: %(
    git clone /vagrant crystal
  )
end
