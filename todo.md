## ToDo

* Failure codes are being added into the events so add this in
* It may be possible to have an email per hit (i.e. per communicator) for alerts if needed
* Rather than an email action, alerts should post HTTP requests to the Salesforce API

## Improvements
* Logstash "health" decision making doesn't take into account multiple pages
  * This will make the painless scripting very complex so need to look at Apache Flink to see if we can simplify this.
* Have a 'last updated successfully timestamp' in the display-state-* index to be able to help debugging as well as be able to plot a histogram of when displays started failing
  * This would need some sort of resetting counter to track concurrent failures before saying that a display is DEFINITELY failing to update. This also needs to be resettable if somehow a display then comes back into range
* Automatically provision filebeat to monitor logstash - make this configurable?
* Logstash needs to be able to cover custom configurations
* Have a container for setting up alerts
* FIXME: Have an intermediate build container that calls the 'Backup/Restore' API's on the 'elasticbase' container and not use FILE/COPY
  * Look at Simon's work on Snapshots

[//]: # (TODO: should we define customers here or use Ansible/templating for this?

[//]: # ("50E7RwWclzJqhPUzBcyk3wzQ" test system password)