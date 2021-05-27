# Release Notes

Current Supported versions:

* Elastic Stack >= 7.12.0
* Dynamic Solution >= 1.14.0

These release notes are part of the view-dc-events repo and are currently for internal use only.

Since Elasticsearch is fast becoming more tightly integrated into the Support and Testing workflows keeping track of changes is becoming more important.

Areas of change covered are linked to Elastic Co releasing new features, Displaydata support for more use-cases and changes to what is considered 'standard' i.e. given out to ever customer.

For the most part this document deals with Elastic Cloud but of course some areas are applicable to customers hosting their own Elasticsearch instances.

## Changelog

Introduced a changelog to the view-dc-events repo *after* the release of 1.12.6 which was shipped on 31/06/2020

### 2021.5.1

NOTE: Changed to year.month.version release versioning

| Item                | Description
|---------------------|----------------------------------------------------------------------------------------------|
| Update Elastic      | Support Elasticsearch 7.13.0
| Dynamic Central     | Now on Dynamic Solution version 1.14.1
| Create Roles        | * Roles for internal services (logstash/metricbeat)
| Create Alerts       | * Alerts are created then disabled 
| Create Users        | * Users are created for internal services         

### 1.14.1

| Item                | Description
|---------------------|----------------------------------------------------------------------------------------------|
| Update Elastic      | Support Elasticsearch 7.12.1
| Dynamic Central     | Now on Dynamic Solution version 1.14.1
| Create Roles        | * Roles for internal services (logstash/metricbeat)
| Create Alerts       | * Alerts are created then disabled 
| Create Users        | * Users are created for internal services         

`* Requires DCSetupElastic version 0.1.10 or above

### 1.14.0

| Item                | Description
|---------------------|----------------------------------------------------------------------------------------------|
| Update Elastic      | Support Elasticsearch 7.12.0                                                                 |

### 1.13.1             

| Item                | Description
|---------------------|----------------------------------------------------------------------------------------------|
| APP-2212            | One alert for ALL communicators that are offline rather than one per communicator            |
| Nifi support        | Alerting and spaces also includes one for Nifi                                               |
| Version Update      | Support Elasticsearch 7.11.1                                                                 |
| Added Alert         | Multi-communicator alert with OpenVPN info (one alert covers all DComms)                     |
| Added Alert         | Delivery Processes with work but no consumers triggers an alert to Support                   |
| Specify Spaces      | Docker containers split into a 'user' and 'development' version                              |

### 1.13.0

| Item                | Description                                                                                  |
|---------------------|----------------------------------------------------------------------------------------------|
| Version Update      | Supports Elasticsearch 7.9.2                                                                 |
| Remove Dependency   | Removed Enhanced Table plugin from Kibana                                                    |
| Use Vanilla Kibana  | Kibana Container is pulled direct from Docker Hub, rather than being built by Displaydata    |
| DS-3893             | Displays that need investigating can be exported from saved searches                         |
| DS-3901             | Change logstash to improve the communicator disconnection alerts in Elasticsearch            |
| DS-3939             | Displays are grouped with dashboards to help manage displays across the entire enterprise    |
| DSAAS-47            | Internal script to create communicator alerts from a csv list of communicator serial numbers |
| DS-3953             | Document the upgrade process for Elasticsearch settings/Logstash and state indexes           |

## Cloud Hosted Deployments

27/08/2020 - Upgrade Zabka Dynamic Cloud production instance & ship them updated monitoring document

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
9. Delete all watchers/alerts from the system manually - this will stop Support receiving duplicate alerts
10. Run the upgrade steps below
    * Amend the existing documents to add new fields & values using 'update-by-query'
    * Use the PSModule to add new settings
      * Pay attention to any failures in uploading the new settings!
    * Use the Kibana UI to re-index all fields
    * Check Visualizations and Dashboards for errors
    * Check Saved searches for errors
11. Note any adjustments that need to be made for the production system

Depending on what version of Elastic Cloud the customer is going from-to there may be some issues and breaking changes which need to be taken into account. This is why running an upgrade on a clone from a customer snapshot is so valuable.

<span style="color:red">**WARNING**</span>: Do not forget to update the Logstash config and restart it, then check logstash for ingest errors!

## Carrying out the upgrade

1. Upgrade to the latest version of Elasticstack
2. Follow the same steps as you did in testing above
   * Amend the existing documents to add new fields & values using 'update-by-query'
    * Use the PSModule to add new settings
      * Pay attention to any failures in uploading the new settings!
    * Use the Kibana UI to re-index all fields
    * Check Visualizations and Dashboards for errors
    * Check Saved searches for errors
3. Change the logstash config files to have the same OUTPUT block as the target machine!
4. Make sure the line endings are correct if copying files from Windows machines to Linux hosts
5. Update the logstash pipeline config files
6. Restart Logstash and check the container logs output

This basically follows Section 10 in the 'Testing' process above with the additional step at the end of changing the Logstash configs, restarting Logstash and checking for ingest errors.

### Making modifications to existing state indexes (Dynamic-Display-* or Dynamic-Communicator-*)

Sometimes (usually due to changes in Logstash pipelines) new fields are introduced which also have a corresponding set of visualizations. What this means is that indexes holding documents about the "state" of displays or communicators need to be modified before they will show the relevant data in the associated visualizations.

If this is not done then these visualizations will not be entirely accurate until all the displays (or communicators) in their index have had some action performed on them. In the case of the dynamic-display-state index new fields need to be created using Elastics's _update_by_query API

#### Using the Logstash Pipeline code

Changes to documents using Logstash only happen when new activity prompts logstash to process a new change. This means that for *existing* documents there is no trigger to add new fields so these have to be added by running a painless script. Constructing this script is based off the logstash pipeline.yml file for that particular index - see the example below

dynamic-display-state.conf (part 1)
```painless
   if [MessageType] == "DisplayUpdateComplete" {
        if [Result] == "NoError" {
            mutate {
                add_field => {
                    "[DisplayUpdateComplete][LastSuccessTimestamp]" => "%{Timestamp}"
                    "[DisplayUpdateComplete][Timestamp]" => "%{Timestamp}"
                    "[DisplayUpdateComplete][Success]" => true
                    "EventTimestampContainerName" => "DisplayUpdateComplete"
                    "EventTimestampFieldName" => "LastSuccessTimestamp"
                }
            }
        } else if ([Result] in ["ImageUpdateStateAlreadyMet","ImageUpdateStaleImage"]) {
    # do not record this event because these are NOT actually changing what is on the display
    # either this event is being discarded or not actioned because the image won't change
            drop {}
        } else {
            mutate {
                add_field => {
                    "[DisplayUpdateComplete][LastFailureTimestamp]" => "%{Timestamp}"
                    "[DisplayUpdateComplete][Timestamp]" => "%{Timestamp}"
                    "[DisplayUpdateComplete][FailureResult]" => "%{Result}"
                    "[DisplayUpdateComplete][Success]" => false
                    "EventTimestampContainerName" => "DisplayUpdateComplete"
                    "EventTimestampFieldName" => "LastFailureTimestamp"
                }
            }
        }
        mutate {
            convert => { 
                "[DisplayUpdateComplete][Success]" => "boolean"
            }
        }
        mutate {
            remove_field => ["Result", "Success" ]
        }
    }
```
dynamic-display-state.conf (part 2)
```painless
   boolean assigned = ctx._source.ObjectIds != null && ctx._source.ObjectIds.length > 0; boolean updateSuccess = ctx._source.containsKey('DisplayUpdateComplete') ? ctx._source.DisplayUpdateComplete.Success : true; def storeHealth; if (assigned) { if (updateSuccess) { storeHealth = 'Last Image Update Success'; } else { storeHealth = 'Last Image Update Failure'; }}
```

Pipeline part 1 adds new fields based on whether the incoming (new) state is a successful Display Update or not. Part 2 looks at whether the display is assigned to a product or not and if so adds further new fields depending on whether the update was successful. It's important to recognise that both these parts deal with the incoming event. The Update_by_Query API has to deal with the **existing** document so although the script will refer to what logstash is changing it's actually pretty different!

#### Writing an Update_by_query painless script

This script has to amend the existing "state" documents. 

```painless
POST dynamic-display-state/_update_by_query
{
  "script": {
    "source": "def timestamp = ctx._source.Timestamp; def failureResult = ctx._source.Result; boolean updateSuccess = ctx._source.Success; boolean assigned = ctx._source.ObjectIds != null && ctx._source.ObjectIds.length > 0; def storeHealth; if (ctx._source.DisplayUpdateComplete == null) {  ctx._source.DisplayUpdateComplete = new LinkedHashMap() } if (ctx._source.MessageType == 'DisplayUpdateComplete') { if (updateSuccess) { ctx._source.DisplayUpdateComplete.LastSuccessTimestamp = ctx._source.Timestamp; ctx._source.DisplayUpdateComplete.Timestamp = timestamp; ctx._source.DisplayUpdateComplete.Success = true } else { ctx._source.DisplayUpdateComplete.LastFailureTimestamp = timestamp; ctx._source.DisplayUpdateComplete.Timestamp = timestamp; ctx._source.DisplayUpdateComplete.FailureResult = failureResult; ctx._source.DisplayUpdateComplete.Success = false } ctx._source.remove('Result'); ctx._source.remove('Success') } if (assigned) { if (updateSuccess) { storeHealth = 'Last Image Update Success' } else { storeHealth = 'Last Image Update Failure' }} if (ctx._source.StoreHealthDashboard == null) {  ctx._source.StoreHealthDashboard = new LinkedHashMap() }  if (storeHealth != ctx._source.StoreHealthDashboard.Health) { ctx._source.StoreHealthDashboard.Health = storeHealth; ctx._source.StoreHealthDashboard.LastChangedTimestamp = timestamp; } ctx._source.StoreHealthDashboard.Timestamp = timestamp; "
  },
  "query": {
    "match_all": {}
  }
}
```

The differences between the logstash pipeline config and this script are: 

1. The painless script will not reference params.event as this is from the 'incoming' document only, this may exist elsewhere in the logstash config but isn't relevant here
2. In this change (from 1.12.x to 1.13.0) we are grouping events so they can easily be found e.g. DisplayUpdateComplete.Timestamp/Success/FailureResult/etc. 
3. A new StoreHealthDashboard field is being created as this is explicitly being used in the visualizations
4. Fields are being defined first so they can be easily re-used

Any errors running something like this need to be addressed BEFORE running any sort of Elastic Cloud version upgrade on a snapshot based copy of the customer implementation

### Using PSModule or PSModule container to add new settings

1. Use the DCSetupElastic Module directly or it's container to setup Elasticsearch (indexes) and Kibana 
2. See the README.md in the powershell-modules-container repo for instructions on how to update these settings

Example commands:

Add new settings to Elasticsearch

`Import-ElasticSettingsToElasticCloud -ElasticId zabka-upgrade-test-3:ZXVyb3BlLXdlc3QzLmdjcC5jbG91ZC5lcy5pbyRhM2Y0NTUwOWUwNzg0OWIyYmQwOTllZTc3YTU2YTBiMiRjMDFkNzkzMjcxNzc0NmFiOGQxZWFlODMwNjRiZWQ1Zg== -Path 'C:\Users\rsweetman\Documents\app-dev\internal\view-dc-events\docker\elasticsearch\elasticsettings\' -Username elastic -Password 0G7MO4Qjmp7DEFfpqh8dl5zC`

Add new visualizations to Kibana

`Import-KibanaSavedObjects -Url https://c01d7932717746ab8d1eae83064bed5f.europe-west3.gcp.cloud.es.io:9243 -Path 'C:\Users\rsweetman\Documents\Project Management\Zabka\Upgrade_files\' -Username elastic -Password 0G7MO4Qjmp7DEFfpqh8dl5zC`


## Dealing with field mapping changes

It's sometimes the case that either data was automatically indexed into Elasticsearch *without* the index template previously existing or that the data type has been incorrectly defined. This may be the case for example where the customer's object Id's are very long indeed and we may have defined them as an int rather than a long. This is purely an example but still will cause a problem since those documents will not be indexed (lost) by Elasticsearch. These will appear as errors in the logstash log output

### Simple Re-Indexing of Elasticsearch mappings - adding a new field

This simple version will only handle adding new fields into the dynamic-display-state or dynamic-communicator-state indexes

Broadly the steps are: - 

1. Get the existing mapping for the index (GET _template/dynamic-display-state)
2. Check the field doesn't already exist 
3. POST the index template including the new setting back to Elasticsearch (POST _template/dynamic-display-state)
4. Go to the Kibana index management section of the Kibana UI and re-index the one which has just been updated

This process more fully described in the "Alerting" document in section 4.8

### Full Re-Indexing of Index mappings and moving indexes - amending existing fields

Follow this example to amend index mappings (field types) for the dynamic-display-state index 

It is not possible to make changes 'in-place' within Elasticsearch (unless doing scripted updates) so the alternative is to create a new (correct) index and re-index (copy) the existing documents from the existing (incorrect) index into the new one. Each document will then be "re-indexed" into the new index with the correct settings.

https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-reindex.html

Steps are: -

1. Get the existing mapping for the index
2. Use this is as the basis for creating a new one 
3. Make sure you have changed the field types you need to
4. Give it a name beginning with dynamic-display- because all of the associated Kibana index-patterns are looking for the format dynamic-display-*
5. Create the new elasticsearch index
6. Call the re-index api to copy documents from the old index to the new one
7. IMPORTANT: change the Logstash config for that particular pipeline to point to the new index name!!
8. Restart Logstash
9. Check that new documents are being indexed correctly
10. Delete the old index as there's no real reason to keep it around - it will only confuse

<!-- 

TODO: Include code examples for each of these steps? Is there a way to do highlighting in markdown in code comments?

-->