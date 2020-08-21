# Release Notes

Current Supported versions:

* Dynamic Solution >= 1.13.0
* Elastic Stack >= 7.8.1   

These release notes are part of the view-dc-events repo and are currently for internal use only.

Since Elasticsearch is fast becoming more tightly integrated into the Support and Testing workflows keeping track of changes is becoming more important.

Areas of change covered are linked to Elastic Co releasing new features, Displaydata support for more use-cases and changes to what is considered 'standard' i.e. given out to ever customer.

For the most part this document deals with Elastic Cloud but of course some areas are applicable to customers hosting their own Elasticsearch instances.

## Changelog

Introduced a changelog to the view-dc-events repo *after* the release of 1.12.6 which was shipped on 31/06/2020

| Item                | Description                                                                                  |
|---------------------|----------------------------------------------------------------------------------------------|
| Version Update      | Supports Elasticsearch 7.8.1                                                                 |
| Remove Dependency   | Removed Enhanced Table plugin from Kibana                                                    |
| Use Vanilla Kibana  | Kibana Container is pulled direct from Docker Hub, rather than being built                   |
| DS-3893             | Displays that need investigating can be exported from saved searches                         |
| DS-3901             | Change logstash to improve the communicator disconnection alerts in Elasticsearch            |
| DS-3939             | Displays are grouped with dashboards to help manage displays across the entire enterprise    |
| DSAAS-47            | Internal script to create communicator alerts from a csv list of communicator serial numbers |

## Upgrading Elastic Cloud

This section specifically addresses deploying new visualizations/dashboards and changes to index mappings (adding new fields). Improvements are made to allow users, Support Team members and developers to better debug, operate and manage Dynamic Solution via events output to Elasticsearch.

### Testing

Before upgrading the production system it is well worth creating a copy of the customers Elastic Cloud instance and running the upgrade steps on them. 

1. Log on to https://Cloud.Elastic.co
2. Create a new deployment using the *same* provider and region as the one to be upgraded
3. Select the latest Elasticsearch version
4. Select the restore from snapshot option and choose the instance to clone
5. Adjust the deployment parameters if necessary by choosing the 'Customize Deployment' option
   * Usually this involves disabling the APM option as this isn't used
6. Select 'Create Deployment'
7. Make sure to note the Elastic username and password since this is only shown *once*
8. Wait for the deployment to complete
9. Run the upgrade steps below
10. Note any adjustments

Depending on what version of Elastic Cloud the customer is going from-to there may be some issues and breaking changes which need to be taken into account. This is why running an upgrade on a clone from a customer snapshot is so valuable.

### Using PSModule or PSModule container to add new settings

1. Use the DCSetupElastic Module directly or it's container to setup Elasticsearch (indexes) and Kibana 
2. See the README.md in the powershell-modules-container repo for instructions on how to update these settings

### Making modifications to existing state indexes (Dynamic-Display-* or Dynamic-Communicator-*)

Sometimes (usually due to changes in Logstash pipelines) new fields are introduced which also have a corresponding set of visualizations. What this means is that indexes holding documents about the "state" of displays or communicators need to be modified before they will show the relevant data in the associated visualizations.

If this is not done then these visualizations will not be entirely accurate until all the displays (or communicators) in their index have had some action performed on them. In the case of the dynamic-display-state index new fields need to be created using Elastics's _update_by_query API

<!-- TODO: Include an example here based off the logstash pipeline code 

1. Logstash pipeline code excerpt
2. Turning this into a script to run in the dev console
3. Execution

-->

### Re-Indexing if Elasticsearch Index Template mappings have to change

<!-- TODO: copy the "how to do re-indexing" document into here
     TODO: find the "how to do re-indexing" document - is it in the appendix of the monitoring document?

-->