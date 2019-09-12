Vagrant.configure("2") do |config|
    config.vm.box = "debian/buster64"

    config.vm.provider :virtualbox do |vb|
        vb.memory = 6144
        vb.cpus = 4
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    config.vm.network "private_network", ip: "192.168.56.17"

    config.vm.synced_folder ".", "/vagrant"

    config.vm.provision "install-docker", type: "shell", inline: <<-SCRIPT
    sudo apt-get update 
    sudo apt-get install -yq apt-transport-https ca-certificates curl gnupg2 software-properties-common
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -yq docker-ce docker-ce-cli containerd.io
    SCRIPT
    
    config.vm.provision "install-docker-compose", type: "shell", inline: <<-SCRIPT
    sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    SCRIPT

    config.vm.provision "create containers", type: "shell", inline: <<-SCRIPT
    sudo usermod -aG docker $USER
    newgrp docker
    cd /vagrant/
    ./develop.sh ingest
    docker --version
    docker-compose --version
    echo "vagrant ssh - to access the debian host for the containers"
    echo "192.168.56.17:5601 - to access Kibana UI via a browser"
    SCRIPT
  
    # TODO: networking is probably not working in all scenarios yet!
    # TODO: check networking/box works without access to Displaydata domain
    # TODO: check vagrant up works entirely offline, once initial provisioning has taken place - this is for demo purposes by Sales/Pre-Sales etc.
    # TODO: check vmware_provider works 

    ["vmware_workstation", "vmware_fusion"].each do |vmware_provider|
        config.vm.provider(vmware_provider) do |vmware|
            vmware.gui = false
            vmware.vmx["memsize"] = 6144
            vmware.vmx["numvcpus"] = 4
            vmware.vmx["vhv.enable"] = "TRUE"
            vmware.vmx["ethernet1.virtualdev"] = "vmxnet3"
        end
    end
end