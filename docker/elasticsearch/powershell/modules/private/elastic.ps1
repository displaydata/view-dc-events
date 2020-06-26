<#
.SYNOPSIS
  Script enables import and export of elastic objects
.PARAMETER Url
  URI of the elasicsearch api endpoint e.g. "http://localhost:9200" (optional)
.PARAMETER Path
  Path to the directory containing the objects to import (optional)
.PARAMETER Username
  Elastic user name (optional)
.PARAMETER Password
  Elastic password (optional)
.EXAMPLE
  manage-elastic.ps1
  manage-elastic.ps1 -Url "http://192.168.56.4:9200"
  manage-elastic.ps1 -Path "./temp"
#>

# ---------------- Operations ----------------

function Approve-ElasticId {
    param (
        [Parameter (Mandatory=$true)][ValidateNotNullOrEmpty()][string] $ElasticId
    )

    $split = $ElasticId.Split(":")
    if ($split.Count -ne 2) {
        return $false;
    }

    try {
        $decodedId = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($split[1]))
        $splitId = $decodedId.Split("$")
        return ($splitId.Count -eq 3)
    }
    catch {
        return $false
    }
}

function Get-ElasticUrlFromId {
    param (
        [Parameter (Mandatory=$true)][ValidateNotNullOrEmpty()][string] $ElasticId
    )

    $split = $ElasticId.Split(":")
    $decodedId = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($split[1]))
    $splitId = $decodedId.Split("$")

    $elasticUrl = "https://" + $splitId[1] + "." + $splitId[0]
    return $elasticUrl
}

function Get-KibanaUrlFromId {
    param (
        [Parameter (Mandatory=$true)][ValidateNotNullOrEmpty()][string] $ElasticId
    )

    $split = $ElasticId.Split(":")
    $decodedId = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($split[1]))
    $splitId = $decodedId.Split("$")

    $kibanaUrl = "https://" + $splitId[2] + "." + $splitId[0]
    return $kibanaUrl
}

<#
.SYNOPSIS
  Import all previously saved elastc objects
.PARAMETER ImportObjectFolder
  A folder containing the objects you want to import
.NOTES
  Scan folder structure
    For each file in  folder
      Import the object
#>
function Import-ElasticSavedObjects {
    Param(
      [parameter(Mandatory=$true)][string]$ImportObjectFolder
    )
    Wait-ForElasticServer -Timeout 120
  
    [string[]]$ElasticObjectTypes = @(
    "index-templates",
    "ingest-nodes"
    )
  
    # Import default space first
    # Iterate thru all the object types e.g. index-template etc.
    Get-ChildItem -Path "$ImportObjectFolder" -Directory | Foreach-Object {
      $ObjectType = $($_.Name)
      If ($ElasticObjectTypes.Contains($ObjectType)) {
        Write-Host "Importing $ObjectType"
        Import-ElasticObjectsFromFolder -Path $_
      }
    }
  }
  
  # ---------------- Functions -----------------
  
  <#
  .SYNOPSIS
    Function to save the objects retrieved from kibana
  .EXAMPLE
    Export-ElasticSavedObjects -Path "spaces/space" -Objects $Objects
  #>
  function Export-ElasticSavedObjects {
    Param(
      [parameter(Mandatory=$true)][string]$Path,
      [parameter(Mandatory=$true)]$Objects
    )
  
    $Objects.saved_objects | ForEach-Object {
      # Remove spaces at start & end and also remove '-*' from the filename
      $title = $($_.attributes.title) -replace '^ | $|\[|\]|-\*|&|\(|\)|\.' -replace ' ', '-' -replace '---|--', '-'
      $Filename = "$Path/" + $title + ".json"
      Write-Host "Saving file: $Filename"
      $_ | ConvertTo-Json -depth 100 | Out-File -FilePath $Filename
    }
  }
  
  <#
  .SYNOPSIS
    Function to issue an HTTP GET request to kibana
  .EXAMPLE
    New-ElasticGetRequest -Controller "_cluster/health" -Headers $headers -Body $Body
  #>
  function New-ElasticGetRequest {
    Param(
      [parameter(Mandatory=$true)][string]$Controller,
      [parameter(Mandatory=$false)]$Headers = @{},
      [parameter(Mandatory=$false)][string]$Body = "{}"
    )
  
    $url = $ElasticUrl + '/' + $Controller
    $Headers.Add("kbn-xsrf", "true")
    $Headers.Add("Content-Type", "application/json")
  
    Write-Debug "GET Url: $url, Headers: $headers, Body:`r`n$Body"
    $response = Invoke-RestMethod -AllowUnencryptedAuthentication `
      -Uri $url `
      -Credential $ElasticCreds `
      -Method GET `
      -Headers $Headers `
      -Body $Body
  
    Write-Debug "New-ElasticGetRequest: $response"
    Return $response
  }
  
  <#
  .SYNOPSIS
    Function to create issue an HTTP PUT request to kibana
  .EXAMPLE
    ElasticPostRequest -Controller "_template" -Headers $headers -Body $Body
  #>
  function New-ElasticPutRequest {
    Param(
      [parameter(Mandatory=$true)][string]$Controller,
      [parameter(Mandatory=$true)]$Headers,
      [parameter(Mandatory=$true)]$Body
    )
  
    $url = $ElasticUrl + "/" + $Controller
    $Headers.Add("kbn-xsrf", "true")
    $Headers.Add("Content-Type", "application/json")
  
    Write-Debug "PUT Url: $url, Headers: $headers, Body:`r`n$Body"
    $response = Invoke-RestMethod -AllowUnencryptedAuthentication `
      -Uri $url `
      -Credential $ElasticCreds `
      -Method PUT `
      -Headers $Headers `
      -Body $Body
  
    Write-Debug "New-ElasticPutRequest: $response"
    Return $response
  }
  
  <#
  .SYNOPSIS
    Function to POST a previously saved object via an HHTP request to elastic
    for import
  .EXAMPLE
    Import-ElasticObject -ObjectType index-templates -ObjectName "dynamic-user-*" -Body $BodyString
  #>
  function Import-ElasticObject {
    Param(
      [parameter(Mandatory=$true)]$ObjectType,
      [parameter(Mandatory=$true)]$ObjectName,
      [parameter(Mandatory=$true)]$Body
    )
  
    $Controller = "_template/" + $($ObjectName) -replace '\.json', '-*'
    $headers=@{}
  
    Try{
      $response = New-ElasticPutRequest -Controller $Controller -Headers $headers -Body $Body
    }
    Catch {
      Write-Host "Error: $($_.Exception.Message)"
      $response = $null
    }
  
    Return $response
  }
  
  <#
  .SYNOPSIS
    Function to process and import objects from a folder into elastic
  .EXAMPLE
    Import-ElasticObjectsFromFolder -Space "Test" -Path "./kibana/spaces/test/visualization"
  #>
  function Import-ElasticObjectsFromFolder {
    Param(
      [parameter(Mandatory=$true)]$Path
    )
  
    $ObjectType = $($_.Name)
    # Iterate thru the visualization definitions in the directory
    Get-ChildItem -Path $Path -File -Filter "*.json" | Foreach-Object {
      $ObjectName = $($_.Name)
  
      $Body = (Get-Content -Raw -Path "$_").Replace("`r`n","").Replace("`n","").Replace("`r","")
      Write-Host -NoNewline "$ObjectType : $ObjectName, Response: "
      $response = Import-ElasticObject -ObjectType $ObjectType -ObjectName $ObjectName -Body $Body
      If ($response.acknowledged -eq "True") {
        Write-Host -ForegroundColor Green "Success"
      } Else {
        Write-Host -ForegroundColor Red "$($response.errors[0].error.type)"
      }
    }
  }
  
  <#
  .SYNOPSIS
    Attempt to connect to server and return its readiness state
  .EXAMPLE
    If (0 -eq Get-ElasticServerStatus) {Write-Host "ready"}
  #>
  function Get-ElasticServerStatus {
    Try {
      $health = New-ElasticGetRequest -Controller "_cluster/health?wait_for_status=yellow&timeout=5s"
      $response = @{ "status" = 0; "description" = "ready"}
      If ($($health.status) -eq "yellow" -or $($health.status) -eq "green") {
        $response = @{ "status" = 0; "description" = "ready"}
      } Else {
        $response = @{ "status" = -1; "description" = $($health.status)}
      }
    } Catch {
      $response = @{ "status" = -2; "description" = $($_.Exception.Message)}
    }
    Write-Debug "Get-ElasticServerStatus: $response"
    return $response
  }
  
  <#
  .SYNOPSIS
    Check kibana server status and wait until it is ready to accept API
    commnds or times out
  .PARAMETER Timeout
    waittime in sconds to wait for server ready (default: 25)
  .EXAMPLE
    Wait-ForElasticServer -Timeout 25
  #>
  function Wait-ForElasticServer {
    Param(
      [parameter(Mandatory=$false)][int]$Timeout
    )
    $waittime = New-TimeSpan -Seconds $Timeout
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $loopcount = 0
    while ((Get-ElasticServerStatus).status -ne 0 -and $stopwatch.elapsed -lt $waittime) {
      if ($loopcount -eq 0) {
        Write-Host -NoNewline "Waiting for elasticsearch server"
      } else {
        Write-Host -NoNewline "."
      }
      $loopcount++
      Start-Sleep -Seconds 5
    }
  
    If ($stopwatch.elapsed -ge $waittime) {
      Write-Host "`nUnable to contact elasticsearch server. Exiting..."
      Exit -1
    } elseif ($loopcount -gt 0) {
      Write-Host "  Done"
    }
  }

  function Import-ElasticSettings {
    param(
      [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Url,
      [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Path,
      [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Username,
      [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Password
    )
  
    $global:ElasticUrl = ([Uri]$Url).AbsoluteUri
  
    $secpasswd = ConvertTo-SecureString $Password -AsPlainText -Force
    $global:ElasticCreds = New-Object System.Management.Automation.PSCredential ($Username, $secpasswd)
  
    Write-Host "Importing"
    Import-ElasticSavedObjects -ImportObjectFolder $Path
  }
  