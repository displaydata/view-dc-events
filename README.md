# view-dc-logs

A docker compose setup that allows to the user to ingest Dynamic Central
User and Audit logs to view and review with a default set of visualisations.
Logs can be ingested directly from a running instance of Dynamic Solution or
by reading a set of log files obtained from a running instance of Dynamic Solution.

Logs are ingested using logstash and written to an elasticsearch volume that can
be backuped and restored.


## Components

The repo consists of a docker-compose configuration file that uses OTS elasticsearch
containers from https://www.docker.elastic.co

The docker host runs a seperate container for each of; elasticsearch, kibana &
logstash and mounts the configuration files and any data from the repo directory.

A seperate docker volume is created for the eleastic and logstash services.

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

The`dynamic` directory contains the dashboards, visualisations, indexes & configuration
files required to setup the docker host, ingest and visualise the events being
sent from Dynamic Central.

The `logs` directory is the directory to place the logs provided by the customer
for viewing. The format of this directory can be either of the following:

```
.\logs\
  |
  |- user
      |
      |- <user event logs>
```

Or

```
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


## Ingesting directly from Dynamic Central
This repo is being used for ingesting and analysing the SoakTest machine's user events.
In this instance there are no saved log files to ingest from the `logs` directory
but logstash listens on port `5044` waiting for the various filebeat instances
runing on the SoakTest setup to forward the user events generated on each server.

In order to set up `view-dc-events` to ingest Dynanic Central user events do the
following on a Linux VM instance that already has docker installed:

```bash
$ # Clone the repo
$ git clone https://gitlab.dev.zbddisplays.local/elastic-stack/view-dc-events.git
$ # Start the containers
$ cd view-dc-events
$ ./develop ingest
```
Now point your filebeat instances at at your VM instance e.g.

filebeat.yml:
```yaml
filebeat.config.inputs:
  enabled: true
  path: configs/user.yml
  reload.enabled: true
  reload.period: 10s

tags: ["dynamiccentral", "core"]

#----------------------------- Logstash output --------------------------------
output.logstash:
  # The Logstash hosts
  hosts: ["192.168.200.111:5044"]
```

user.yml
```yaml
- type: log
  paths:
    - c:\Dynamic Central\Working\Logs\User\*.json
    - c:\Dynamic Central\Working\Logs\User\*\*.json
  fields:
    type: user
  processors:
    -
      add_locale: ~
```


## Ingesting user events from save log files
Save your user event log files to the `logs` directory as detailed above.

Login to a Linux VM instance with docker pre-installed. and do the following:

```bash
$ # Clone the repo
$ git clone https://gitlab.dev.zbddisplays.local/elastic-stack/view-dc-events.git
$ # Start the containers
$ cd view-dc-events
$ ./develop ingest
```

The containers will start and immediately begin to ingest the logs saved to the
`logs` directory.