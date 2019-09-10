Vagrant.configure("2") do |config|
    config.vm.box = "debian/buster64"

    config.vm.provider :virtualbox do |vb|
        vb.memory = 4096
        vb.cpus = 2
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    config.vm.network "private_network", ip: "192.168.56.17"

    config.vm.synced_folder ".", "/vagrant"

    # TODO: add packages list
    # TODO: apt-get update
    # TODO: Install Docker
    # TODO: Add Docker to sudoers
    # TODO: Install docker-compose
    # TODO: run ./develop ingest w/o sudo

    # FIXME: networking is probably not working in all scenarios yet!

end