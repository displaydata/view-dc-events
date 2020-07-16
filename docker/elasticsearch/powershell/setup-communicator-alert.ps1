<#
.SYNOPSIS
  Script enables creation of communicator alerts
.PARAMETER Communicator
  Declare to set up an alert for a communicator by serial number
.PARAMETER Export
  Declare to export a set of elastic saved_objects. Mutually exclusive with -Import
.PARAMETER Url
  URI of the kibana api endpoint e.g. "http://localhost:5601" (optional)
.PARAMETER Username
  Elastic user name (optional)
.PARAMETER Password
  Elastic password (optional)
.PARAMETER Email
  Recipient for alert email
  #FIXME: might be more than one recipient(?)

.EXAMPLE
  setup-communicator-alert.ps1 -Communicator ZC00003472 -Url "https://192.168.56.4:5601" -Username elastic -Password 'fgefliferihf'

.NOTES
  Creates an alert per communicator that triggers every hour and fires if the communicator is either Disconnected or Connecting and if the 'LastConnected' timestamp value is older than 30 minutes ago
#>



function Set-CommunicatorAlert {

    param(
    [Parameter(Mandatory=$false)][string]$Url = "http://localhost:9200",
    [Parameter(Mandatory=$false)]$Communicators,
    [Parameter(Mandatory=$false)][string]$Username = "elastic",
    [Parameter(Mandatory=$false)][string]$Password = "elastic"
    )

$alert='
    {
    "trigger": {
        "schedule": {
            "interval": "60m"
        }
    },
    "input": {
        "search": {
            "request": {
                "search_type": "query_then_fetch",
                "indices": [
                "dynamic-communicator-state"
            ],
            "rest_total_hits_as_int": true,
            "body": {
                "size": 1,
                "query": {
                    "bool": {
                        "must": [
                            {
                            "terms": {
                                "Result": [
                                    "CommunicatorDisconnected",
                                    "CommunicatorConnecting"
                                ]
                            }
                        },
                    {
                    "match": {
                        "CommunicatorSerialNumber": "ZC00000000"
                    }
                            }
                            ]
                        }
                    }
                }
            }
        }
    },
    "condition": {
        "compare": {
            "ctx.payload.hits.hits.0._source.LastConnectedTimestamp": {
                "lte": "<{now-30m}>"
            }
        }
    },
        "actions": {
            "send_email": {
                "email": {
                    "profile": "standard",
                    "to": [
                    "support@displaydata.com"
                    ],
                    "subject": "Communicator {{ctx.payload.hits.hits.0._source.CommunicatorSerialNumber}} is offline at Location {{ctx.payload.hits.hits.0._source.LocationName}}",
                    "body": {
                        "text": "Communicator {{ctx.payload.hits.hits.0._source.CommunicatorSerialNumber}} is offline at Location {{ctx.payload.hits.hits.0._source.LocationName}}"
                    }
                }
            }
        }
    }'

    # Uses Elasticsearch API endpoint to PUT a new Watch(alert)
    $secpasswd = ConvertTo-SecureString $Password -AsPlainText -Force
    $global:ElasticCreds = New-Object System.Management.Automation.PSCredential ($Username, $secpasswd)

    $Headers = @{}

    $headers.Add("content-type", "application/json")

    foreach ($Communicator in $Communicators) {
        
        $newAlert = ($alert).Replace('ZC00000000',$Communicator)

        Invoke-RestMethod -Method PUT -Uri "$Url/_watcher/watch/$Communicator" -Body $newAlert -Headers $Headers -Credential $global:ElasticCreds
    }

}
