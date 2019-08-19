# view-dc-logs

A docker compose setup that allows to the user to ingest a set of Dynamic Central User and Audit logs to view and review with a default set of visualisations


## Components

The repo consists of a docker-compose configuration file that uses OTS elasticsearch
containers from https://www.docker.elastic.co

The docker host runs a seperate container for each of; elasticsearch, kibana &
logstash and mounts the configuration files and data from the repo directory.

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