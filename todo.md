## General

* decide whether this 'could' also include alerting settings
* where does the automated (set up alerts code go more generally)
* create another branch just for the logstash display-state index changes
* ulimately remove the top level 'docker' folder 'cause it's not needed  
* consider how to tackle logstash and custom configs like vodafone
* rename files and restructure logs
* FIXME: Have an intermediate build container that calls the 'Backup/Restore' API's on the 'elasticbase' container and not use FILE/COPY

## Fix folder structure

* FIXME: remove un-necessary powershell commands (manage-elastic/manage-kibana) develop.sh
* does the develop.sh ingest command still have value?
* change file structure within elasticsearch UP

## Fix Powershell bits
* FIXME: put powershell commands into a module & address issues of common code between Manage-kibana and manage-elasticsearch
* Put manage-elasticsearch and manage-powershell scripts into their own containers
* Have an init container which goes looking for settings and applies them on startup

## KIBANA container
* Init wait for elasticsearch to be available before start add this to the Dockerfile before reach CMD entrypoint

## Logstash
* Automatically provision filebeat to monitor logstash - make this configurable?