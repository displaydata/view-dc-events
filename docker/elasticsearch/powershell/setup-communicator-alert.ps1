<#
.SYNOPSIS
  Script enables creation of communicator alerts that are sent to support@displaydata.com
.PARAMETER Communicator
  Declare to set up an alert for a communicator by serial number
.PARAMETER Url
  URI of the elasticsearch api endpoint e.g. "http://localhost:9200" (optional)
.PARAMETER Username
  Elastic user name (optional)
.PARAMETER Password
  Elastic password (optional)
.EXAMPLE
  Set-CommunicatorAlert -Communicator ZC00003472 -Url "https://192.168.56.4:9200" -Username elastic -Password 'fgefliferihf'
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
                            "exists": {
                                "field": "disconnectedTimestamp"
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
            "ctx.payload.hits.hits.0._source.disconnectedTimestamp": {
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

<#
.SYNOPSIS
  Script enables creation of communicator alerts from a Csv file
.PARAMETER Filepath
  Location of CSV file containing communicator 'Serial Number' heading
.PARAMETER Url
  URI of the elasticsearch api endpoint e.g. "http://localhost:9200"
.PARAMETER Username
  Elastic user name (optional)
.PARAMETER Password
  Elastic password (optional)

.EXAMPLE
  Set-CommunicatorAlertFromCsv -Filepath C:\Username\Downloads\communicators.csv -Url "https://192.168.56.4:9200" -Username elastic -Password 'fgefliferihf'

.NOTES
  Creates an alert per communicator that triggers every hour and fires if the communicator is either Disconnected or Connecting and if the 'LastConnected' timestamp value is older than 30 minutes ago
#>
function Set-CommunicatorAlertFromCsv {

    param(
        [Parameter(Mandatory=$true)]$Filepath,
        [Parameter(Mandatory=$false)][string]$Url = "http://localhost:9200",
        [Parameter(Mandatory=$false)][string]$Username = "elastic",
        [Parameter(Mandatory=$false)][string]$Password = "elastic"
    )

    Import-Csv -Path $Filepath -Delimiter ',' | Select-Object -Property 'Serial Number' | ForEach-Object { Set-CommunicatorAlert -Url $Url -Communicators ($_.'Serial Number') -Username $Username -Password $Password}

}
