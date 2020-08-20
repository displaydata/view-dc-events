# Release Notes

Current Supported versions:
Dynamic Solution >= 1.12.0
Elastic Stack >= 7.8.1   

These release notes are part of the view-dc-events repo and are currently for internal use only

Since Elasticsearch is fast becoming more tightly integrated into the Support and Testing workflows keeping track of changes is becoming more important

Areas of change covered are linked to Elastic Co releasing new features, Displaydata support for more use-cases and changes to what is considered 'standard' i.e. given out to ever customer.

For the most part this document deals with Elastic Cloud but of course some areas are applicable to customers hosting their own Elasticsearch instances

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

This section specifically addresses deploying new visualizations/dashboards and changes to index mappings (as well as new fields) which are part of improving the Support/troubleshooting process as well as monitoring of Dynamic Solution.

### Testing

### Using PSModule or PSModule container to add new settings

### Re-Indexing if Elasticsearch Index Template mappings have to change

### Making modifications to existing state indexes (Dynamic-Display-* or Dynamic-Communicator-*)