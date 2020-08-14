## General

* Change logstash HealthDashboard config to only reference Assigned displays
* Implement all the points from DS-3939


## Improvements
* Automatically provision filebeat to monitor logstash - make this configurable?
* Logstash needs to be able to cover custom configurations
* Have a container for setting up alerts
* FIXME: Have an intermediate build container that calls the 'Backup/Restore' API's on the 'elasticbase' container and not use FILE/COPY
  * Look at Simon's work on Snapshots