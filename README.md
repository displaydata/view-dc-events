# view-dc-events

A docker compose setup that allows Displaydata customers to ingest Dynamic Central User Events to view and review with a default set of visualisations.

Events can be ingested directly from a running instance of Dynamic Solution (using Filebeat) or by reading a set of log files exported from a running instance of Dynamic Solution.

Logs are ingested using logstash and written to an elasticsearch volume that can be backuped and restored.

This setup is aimed primarily at customers trialing Dynamic Solution.

It can also be used by Displaydata customers (who are in the rollout stage) as a starting point from which to develop their own customised dashboards and monitoring.

**WARNING**: This Elasticsearch setup does not guard against data loss and is only configured for a single node so is not suitable for production environments.

**NOTE:** This set of containers only supports Elasticsearch's 7.5 release.

Be aware that dashboards exported from this setup and imported into earlier or later Elasticsearch instances may not render properly.

## Pre-requisites

Ubuntu or Debian host machine (Minimum 4Gb RAM, >12Gb disk space) with the following installed:

* docker
* docker compose

Also follow the 'post installation steps for Linux' section here:
https://docs.docker.com/install/linux/linux-postinstall/

This setup makes use of apt-get and bash scripts so cannot be run on Windows or non Ubuntu/Debian hosts.

If you're copying the files from a Windows machine rather than cloning direct from the repository on Github you need to make sure that the following files are executable in the linux environment:

* develop.sh

```shell
sudo chmod +x <filename>
```

### Cloud provider image options

Azure: https://azuremarketplace.microsoft.com/en-us/marketplace/apps/debian.debian-10?tab=Overview

AWS: https://aws.amazon.com/marketplace/pp/B073HW9SP3?qid=1571395555537&sr=0-1&ref_=srh_res_product_title

## Overview

The repo consists of a docker-compose configuration file that uses off-the-shelf elasticsearch containers from https://www.docker.elastic.co

The docker host runs a seperate container for each of; elasticsearch, kibana &
logstash and mounts the configuration files and any data from the repo directory.

A seperate docker volume is created for the elastic and logstash services. The
elastic volume is mapped to the elasticsearch node data and contains the elastic
indexes etc. The logstash volume is mapped to the logstatsh data directory and
contains the information on what files have been processed and ingested into
elastic.

Container volumes have been mounted externally so that the data (documents indexed into Elasticsearch) and settings will survive container upgrades or the container instances being removed. Running `./develop.sh clear` will purge EVERYTHING, including the Elasticsearch database so should only be run to achieve this specific outcome.

Once the environment is "up" the Kibana UI should be availabe via a browser on _host IP address_:5601

The directory structure of the repo is as follows:

```
.\
 |
 |- dynamic
 |  |
 |  |- elasticsearch
 |  |
 |  |- kibana
 |  |
 |  |- logstash
 |
 |- logs
```

The top level root directory contains the `docker-compose` configuration file
and the scripts for loading and setting up the containers.

The `dynamic` directory contains the spaces, dashboards, visualisations, indexes
& configuration files required to setup the docker host, ingest and visualise
the events being sent from Dynamic Central.

Displaydata's "Monitoring" document explains these dashboards, visualisations
and the format of specific events emitted from Dynamic Central. This document
is available on request from Displaydata Support: <support@displaydata.com>

The `logs` directory is the directory to place the logs provided by the customer
for viewing. The format of this directory can be either of the following:

```shell
.\logs\
  |
  |- user
      |
      |- <user event logs>
```

Or

```shell
.\logs\
  |
  |- <store name>
  |   |- user
  |       |
  |       |- <user event logs>
  |
  |- <store name>
      |- user
          |
          |- <user event logs>
```

**NOTE:** In the second example the user event logs from multiple stores have been
retrieved and are being reviewed. In this case the event data will be augmented
with a `[store]` field that contains the name of `<store name>` directory.
This field can then be used in visualisation filters to view a specific store etc.

### Kibana Spaces

Spaces are a kibana component that enable you to organize your dashboards and
other saved objects into meaningful categories. Each space has its own set of
objects and dashboards.

The default space is always available. Other named spaces are added to present
a clean set of dashboards for a specific category of information e.g. Health,
Alerts, Performance.

The default space must always be present and if no other spaces are created
you will enter the default space when connecting to the kibana UI.

Saved objects are loaded into kibana using the `manage-kibana.ps1` powershell
script. The script uses the kibana API to load any predefined
spaces that appear under the `.../kibana/spaces` directory.
Execute this by running `./develop.sh update` to update the kibana with any
changes you make to the saved objects.

Objects that the script will load are; dashboards, visualisations, searches & index patterns.

**NOTE:** The `./develop.sh ingest` script will start the containers and load
the saved objects. `./develop.sh update` is only required if you wish to update
the saved objects

## Ingesting directly from Dynamic Central

This docker-compose setup can be used for ingesting and analysing Dynamic
Solution's live user events. In this instance there are no saved log files to
ingest from the `logs` directory but logstash listens on port `5044` waiting
for the various filebeat instances to forward the user events generated on
each server.

In order to set up `view-dc-events` to ingest Dynanic Central user events do the
following on a Linux VM instance that already has docker and docker-compose installed:

```bash
$ # Clone the repo
$ git clone https://gitlab.dev.zbddisplays.local/internal/view-dc-events.git
$ # Start the containers
$ cd view-dc-events
$ ./develop.sh ingest
```

Now point your filebeat instances on your Dynamic Central Services at your VM instance e.g.

filebeat.yml:

```yaml
filebeat.config.inputs:
  enabled: true
  path: configs/user.yml
  reload.enabled: true
  reload.period: 10s

tags: ["dynamiccentral", "core"]

output.logstash:
  # The Logstash hosts
  hosts: ["192.168.200.111:5044"]
```

configs/user.yml:

```yaml
- type: log
  paths:
    - C:\Dynamic Central\Working\Logs\User\*.json
    - C:\Dynamic Central\Working\Logs\User\*\*.json
  exclude_files: ['SystemStatus-.*']
  fields:
    type: user
  processors:
    -
      add_locale: ~
```

configs/status.yml:

```yaml
- type: log
  paths:
    - c:\Dynamic Central\Working\Logs\User\SystemStatus-*.json
    - c:\Dynamic Central\Working\Logs\User\*\SystemStatus-*.json
  fields:
    type: status
  processors:
    -
      add_locale: ~
```

### Commands

`./develop.sh down` - Stop the containers

`./develop.sh up` - Start the containers

`./develop.sh clean` - Remove all running containers AND *delete volumes*

`./develop.sh export` - Export all current visualisations, dashboards etc. to
`./dynamic/kibana/spaces` after moving the existing folder to `./dynamic/kibana/spaces~`

## Ingesting user events from saved log files

Save your user event log files to the `logs\user` directory as detailed above.

Login to a Linux VM instance with docker pre-installed. and do the following:

```bash
$ # Clone the repo
$ git clone https://gitlab.dev.zbddisplays.local/elastic-stack/view-dc-events.git
$ # Start the containers
$ cd view-dc-events
$ ./develop.sh ingest
```

The containers will start and immediately begin to ingest the logs saved to the
`logs\user` directory.

### Commands

`./develop.sh ingest` - Start the containers including the facility to pull
customer supplied logs from the 'logs' directory

`./develop.sh down` - Stop the containers

`./develop.sh up` - Start the containers

`./develop.sh clean` - Remove all running containers AND *delete volumes*

`./develop.sh export` - Export all current visualisations, dashboards etc. to
`./dynamic/kibana/spaces` after moving the existing folder to `./dynamic/kibana/spaces~`

## Vagrant file

If you're familiar with Hashicorp's Vagrant there is a Vagrantfile in this repo
with providers for Virtualbox, VMWare Workstation or VMWare Fusion.

This will will bring up a Debian machine with the necessary pre-requisites
installed by running `vagrant up --provider <providername>`
