## General

* decide whether this 'could' also include alerting settings
* where does the automated (set up alerts code go more generally)
* create another branch just for the logstash display-state index changes
* ultimately remove the top level 'docker' folder 'cause it's not needed  
* consider how to tackle logstash and custom configs
* rename files and restructure logs
* FIXME: Have an intermediate build container that calls the 'Backup/Restore' API's on the 'elasticbase' container and not use FILE/COPY

## Fix folder structure

* FIXME: remove un-necessary powershell commands (manage-elastic/manage-kibana) develop.sh
* does the develop.sh ingest command still have value?
* change file structure within elasticsearch UP

## Fix Powershell bits
* Put manage-elasticsearch and manage-powershell scripts into their own containers

## KIBANA container
* Init wait for elasticsearch to be available before start add this to the Dockerfile before reach CMD entrypoint

## Logstash
* Automatically provision filebeat to monitor logstash - make this configurable?

<!--
{
    "DisplayUpdateComplete": {
      "LastSuccessTimestamp": "2020-06-30T17:29:29.1174889Z",
    
      "FailureResult": "RFCommsFailure",
      "LastFailureTimestamp": "2020-06-30T17:29:29.1174889Z",
      "Success": "true",
      "Timestamp": "020-06-30T17:29:29.1174889Z"
    },
    "SystemHealthcheck": {
      "LastSuccessTimestamp": "2020-06-30T17:29:29.1174889Z",
    
      "FailureResult": "RFCommsFailure",
      "LastFailureTimestamp": "2020-06-30T17:29:29.1174889Z",
      "Success": "true",
      "Timestamp": "020-06-30T17:29:29.1174889Z"
    },
    "ConnectivityDashboardHealth" : {
      "Healthy": true,
      "Timestamp": "020-06-30T17:29:29.1174889Z"
    }
}

"def timestampFieldName = params.event.EventTimestampFieldName; 

if (ctx._source.containsKey(timestampFieldName)) { 
    Instant stored_change_time = Instant.parse(ctx._source[timestampFieldName]);
    Instant new_change_time = Instant.parse(params.event[timestampFieldName]);

    if (new_change_time.isBefore(stored_change_time)) { 
        ctx.op = 'none';
        return
    }
}; 

if (params.event[DisplayUpdateComplete][Success]==true && ctx._source[SystemHealthCheck][Success]==true) { 
    ctx._source[StoreHealthDashboard][Health] = Green; 
    ctx._source[StoreHealthDashboard][Timestamp] = new_change_time 
} elseif (params.event[DisplayUpdateComplete][Success]==true && ctx._source[SystemHealthCheck][Success]==false) { 
    ctx._source[StoreHealthDashboard][Health] = Amber;
    ctx._source[StoreHealthDashboard][Timestamp] = new_change_time
} else { 
    ctx._source[StoreHealthDashboard][Health] = Red;
    ctx._source[StoreHealthDashboard][Timestamp] = new_change_time
};

params.event.remove('EventTimestampFieldName');

for (entry in params.event.entrySet()) {
    def key = entry.getKey();
    ctx._source[key] = entry.getValue();
}"
>