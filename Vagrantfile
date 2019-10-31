elk_mem = 6144
elk_cpus = 4
network_ip = "192.168.56.17"
elasticsearch_port = 9200
kibana_port = 5601

Vagrant.configure("2") do |config|
    config.vm.box = "generic/debian10"

    config.vm.network "private_network", ip: "#{network_ip}"

    config.vm.synced_folder ".", "/vagrant"

    config.vm.provision "install-docker", type: "shell", inline: <<-SCRIPT
    sudo apt-get update
    sudo apt-get install -yq apt-transport-https ca-certificates curl gnupg2 software-properties-common
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -yq docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker vagrant
    sudo gpasswd -a vagrant docker
    SCRIPT

    config.vm.provision "install-docker-compose", type: "shell", inline: <<-SCRIPT
    sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    SCRIPT

    config.vm.provision "create containers", type: "shell", inline: <<-SCRIPT
    cd /vagrant
    ./develop.sh ingest
    docker --version
    docker-compose --version
    echo "vagrant ssh - to access the debian host for the containers"
    echo "192.168.56.17:5601 - to access Kibana UI via a browser"
    SCRIPT

    # Settings here are to: change memory size, number of cpus and whether to show the VM console
    # Default ELK Vagrant Box values are: 512MByte, 1 CPU
    config.vm.provider "virtualbox" do |vb|
        vb.memory = elk_mem.to_i
        vb.cpus = elk_cpus.to_i
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    # Same as above, but for VMware Workstation & VMware Fusion
    ["vmware_workstation", "vmware_fusion"].each do |vmware_provider|
        config.vm.provider(vmware_provider) do |vmware|
            vmware.gui = false
            vmware.vmx["memsize"] = "#{elk_mem.to_s}"
            vmware.vmx["numvcpus"] = "#{elk_cpus.to_i}"
            vmware.vmx["vhv.enable"] = "TRUE"
        end
    end

    # TODO: networking may not be working in all scenarios yet!
    # TODO: check networking/box works without access to Displaydata domain
    # TODO: once initial provisioning has taken place, check vagrant up works entirely offline - this is for demo purposes by Sales/Pre-Sales etc.
end