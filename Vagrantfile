# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "hashicorp/precise32"
  config.vm.box_url = "http://files.vagrantup.com/precise32.box"

	config.vm.provider :virtualbox do |vb|
	  vb.customize ["modifyvm", :id, "--memory", "2048"]
	end

	 config.vm.provision :shell, :path => "install-rvm.sh",  :args => "stable"
     config.vm.provision :shell, :path => "install-ruby.sh", :args => "2.0.0"
     config.vm.provision :shell, :path => "install-ruby.sh", :args => "2.0.0 rake sinatra haml json"
end
