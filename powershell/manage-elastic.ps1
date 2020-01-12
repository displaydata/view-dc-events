<#
.SYNOPSIS
  Script enables import and export of elastic objects
.PARAMETER Import
  Declare to import a set of previously saved objects. Mutually exclusive with -Export
.PARAMETER Export
  Declare to export a set of elastic objects. Mutually exclusive with -Import
.PARAMETER Url
  URI of the elasicsearch api endpoint e.g. "http://localhost:9200" (optional)
.PARAMETER Path
  Path to the directory containing the objects to import (optional)
.PARAMETER Username
  Elastic user name (optional)
.PARAMETER Password
  Elastic password (optional)
.EXAMPLE
   manage-elastic.ps1 -Import
   manage-elastic.ps1 -Export -Url "http://192.168.56.4:9200"
   manage-elastic.ps1 -Import -Path "./temp"
#>

# TODO: Add exporting of index-templates
# TODO: Refactor import code to be more generic

param(
  [switch]$Import,
  [switch]$Export,
  [Parameter(Mandatory=$false)][string]$Url = "http://localhost:9200",
  [Parameter(Mandatory=$false)][string]$Path = "./dynamic/elasticsearch",
  [Parameter(Mandatory=$false)][string]$Username = "elastic",
  [Parameter(Mandatory=$false)][string]$Password = "elastic"
)

$global:ElasticUrl = $Url
$secpasswd = ConvertTo-SecureString $Username -AsPlainText -Force
$global:ElasticCreds = New-Object System.Management.Automation.PSCredential ($Password, $secpasswd)

# Create a list of objects we manage
[string[]]$global:ElasticObjectTypes = @(
  "index-templates",
  "ingest-nodes"
)


# ---------------- Operations ----------------

<#
.SYNOPSIS
  Export the saved objects from kibana we are interested in saving
.PARAMETER ExportObjectFolder
  A folder where you want to export the spaces/saved_objects to
.NOTES
  Get spaces from kibana
    For each space create a folder
    Get saved_objects from the kibana sapce
    For each saved_object type create a folder
      Export the saved_objects to the folder
#>
function Export-Saved-Objects {
  Param(
    [parameter(Mandatory=$true)][string]$ExportObjectFolder
  )

  # Check we can communicate to kibana
  WaitForElasticServer -Timeout 40

  Write-Host "Backup existing spaces folder: $ExportObjectFolder"
  $null = BackupSpacesFolder -Path $ExportObjectFolder

  # Iterate thru the spaces and save the objects
  $ElasticSpaces | ForEach-Object {
    $ElasticSpace = $($_.id)
    Write-Host "Saving Elastic Space: $ElasticSpace"

    # Create a space directory if it doesn't already exist
    if ( -Not (Test-Path -Path "$ExportObjectFolder/$ElasticSpace" -PathType "Container") ) {
      $null = New-Item -ItemType Directory -Path "$ExportObjectFolder/$ElasticSpace"
    }

    # Save space details
    Write-Host "Saving spaces details: $ExportObjectFolder/$ElasticSpace/space-details.json"
    $_ | ConvertTo-Json -depth 100 | Out-File "$ExportObjectFolder/$ElasticSpace/space-details.json"

    # Get the objects we are interested in and save them
    $ElasticObjectTypes | ForEach-Object {
      $ElasticObjects = ElasticFindObjects $ElasticSpace $_

      # Don't do anything if there are no objects
      if ($($ElasticObjects.saved_objects).Length -eq 0) {
        Write-Host "No $_ objects in space: $ElasticSpace. Moving on..."
        Return
      }

      # Create a object type directory if it doesn't already exist
      if ( -Not (Test-Path -Path "$ExportObjectFolder/$ElasticSpace/$_" -PathType "Container") ) {
        $null = New-Item -ItemType Directory -Path "$ExportObjectFolder/$ElasticSpace/$_"
      }

      SaveObjects "$ExportObjectFolder/$ElasticSpace/$_" $ElasticObjects
    }

    # Get the default index for the space and save it
    $ElasticDefaultIndex = ElasticGetDefaultIndex -Space $ElasticSpace
    If ($null -ne $ElasticDefaultIndex) {
      Write-Host "Default index for Space: $ElasticSpace is $ElasticDefaultIndex"
      $ElasticDefaultIndex | Out-File "$ExportObjectFolder/$ElasticSpace/default-index.txt"
    }
  }
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
function Import-Saved-Objects {
  Param(
    [parameter(Mandatory=$true)][string]$ImportObjectFolder
  )
  WaitForElasticServer -Timeout 30

  # Import default space first
  # Iterate thru all the object types e.g. index-template etc.
  Get-ChildItem -Path "$ImportObjectFolder" -Directory | Foreach-Object {
    $ObjectType = $($_.Name)
    If ($ElasticObjectTypes.Contains($ObjectType)) {
      Write-Host "Importing $ObjectType"
      ElasticImportObjectsFromFolder -Path $_
    }
  }
}

# ---------------- Functions -----------------

<#
.SYNOPSIS
  Function to save the objects retrieved from kibana
.EXAMPLE
  SaveObjects -Path "spaces/space" -Objects $Objects
#>
function SaveObjects {
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
  Function to backup an existing spaces folder
.PARAMETER Path
  Path of folder to backup
.EXAMPLE
  BackupSpacesFolder -Path "./dcomm/kibana/spaces"
#>
function BackupSpacesFolder {
  Param(
    [parameter(Mandatory=$true)][string]$Path
  )

  $FolderPath = Split-Path -Path $Path
  $BackupFolderName = (Split-Path -Path $Path -Leaf) + '~'
  # Remove any previously backuped up folder
  If (Test-Path -Path "$FolderPath/$BackupFolderName") {
    Remove-Item -Path "$FolderPath/$BackupFolderName" -Force -Recurse
  }

  Rename-Item -Path $Path -NewName "$BackupFolderName"
  $null = New-Item -ItemType Directory -Force -Path $Path

}

<#
.SYNOPSIS
  Function to issue an HTTP GET request to kibana
.EXAMPLE
  ElasticGetRequest -Controller "_cluster/health" -Headers $headers -Body $Body
#>
function ElasticGetRequest {
  Param(
    [parameter(Mandatory=$true)][string]$Controller,
    [parameter(Mandatory=$false)]$Headers = @{},
    [parameter(Mandatory=$false)][string]$Body = "{}"
  )

  $url = $global:ElasticUrl + '/' + $Controller
  $Headers.Add("kbn-xsrf", "true")
  $Headers.Add("Content-Type", "application/json")
  # Write-Host "Uri: $url"

  $response = Invoke-RestMethod -AllowUnencryptedAuthentication `
      -Uri $url `
      -Credential $global:ElasticCreds `
      -Method GET `
      -Headers $Headers `
      -Body $Body

  Return $response
}

<#
.SYNOPSIS
  Function to create issue an HTTP PUT request to kibana
.EXAMPLE
  ElasticPostRequest -Controller "_template" -Headers $headers -Body $Body
#>
function ElasticPutRequest {
  Param(
    [parameter(Mandatory=$true)][string]$Controller,
    [parameter(Mandatory=$true)]$Headers,
    [parameter(Mandatory=$true)]$Body
  )

  $url = $global:ElasticUrl + "/" + $Controller
  $Headers.Add("kbn-xsrf", "true")
  $Headers.Add("Content-Type", "application/json")

  $response = Invoke-RestMethod -AllowUnencryptedAuthentication `
      -Uri $url `
      -Credential $global:ElasticCreds `
      -Method PUT `
      -Headers $Headers `
      -Body $Body

  Return $response
}

<#
.SYNOPSIS
  Function to POST a previously saved object via an HHTP request to elastic
  for import
.EXAMPLE
  ElasticImportObject -ObjectType index-templates -ObjectName "dynamic-user-*" -Body $BodyString
#>
function ElasticImportObject {
  Param(
    [parameter(Mandatory=$true)]$ObjectType,
    [parameter(Mandatory=$true)]$ObjectName,
    [parameter(Mandatory=$true)]$Body
  )

  If ($ObjectType -eq "index-templates") {
    $Controller = "_template/" + $($ObjectName) -replace '\.json', '-*'
  } ElseIf ($ObjectType -eq "ingest-node") {
    $Controller = "_ingest/pipeline/" + $($ObjectName) -replace '\.json'
  } Else {
    return $null
  }
  $headers=@{}

  Try{
    $response = ElasticPutRequest -Controller $Controller -Headers $headers -Body $Body
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
  ElasticImportObjectsFromFolder -Space "Test" -Path "./kibana/spaces/test/visualization"
#>
function ElasticImportObjectsFromFolder {
  Param(
    [parameter(Mandatory=$true)]$Path
  )

  $ObjectType = $($_.Name)
  # Iterate thru the visualization definitions in the directory
  Get-ChildItem -Path $Path -File -Filter "*.json" | Foreach-Object {
    $ObjectName = $($_.Name)

    $Body = (Get-Content -Raw -Path "$_").Replace("`r`n","").Replace("`n","")
    Write-Host -NoNewline "$ObjectType : $ObjectName, Response: "
    $response = ElasticImportObject -ObjectType $ObjectType -ObjectName $ObjectName -Body $Body
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
  If (0 -eq GetElasticServerStatus) {Write-Host "ready"}
#>
function GetElasticServerStatus {
  Try {
    $null = ElasticGetRequest -Controller "_cluster/health?wait_for_status=green&timeout=5s"
    $response = @{ "status" = 0; "description" = "ready"}
  } Catch {
    $response = @{ "status" = -1; "description" = $($_.Exception.Message)}
  }
  return $response
}

<#
.SYNOPSIS
  Check kibana server status and wait until it is ready to accept API
  commnds or times out
.PARAMETER Timeout
  waittime in sconds to wait for server ready (default: 25)
.EXAMPLE
  WaitForElasticServer -Timeout 25
#>
function WaitForElasticServer {
  Param(
    [parameter(Mandatory=$false)][int]$Timeout
  )
  $waittime = New-TimeSpan -Seconds $Timeout
  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  $loopcount = 0
  while ((GetElasticServerStatus).status -ne 0 -and $stopwatch.elapsed -lt $waittime) {
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

# ---------------- Main Code -----------------

If ($Export) {
  Write-Host "Exporting..."
  Export-Saved-Objects -ExportObjectFolder $Path
} Else {
  Write-Host "Importing"
  Import-Saved-Objects -ImportObjectFolder $Path
}
