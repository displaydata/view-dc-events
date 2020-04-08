<#
.SYNOPSIS
  Script enables import and export of elastic "saved-objects" heirachy
.PARAMETER Import
  Declare to import a set of previously saved objects. Mutually exclusive with -Export
.PARAMETER Export
  Declare to export a set of elastic saved_objects. Mutually exclusive with -Import
.PARAMETER Url
  URI of the kibana api endpoint e.g. "http://localhost:5601" (optional)
.PARAMETER Path
  Path to the directory containing the objects to import (optional)
.PARAMETER Username
  Elastic user name (optional)
.PARAMETER Password
  Elastic password (optional)

.EXAMPLE
   manage-kibana.ps1 -Import
   manage-kibana.ps1 -Export -Url "http://192.168.56.4:5601"
   manage-kibana.ps1 -Import -Path "./temp"

.NOTES
  Scan kibana/spaces folder structure
  For each folder in spaces
  Create a space
  For each folder in space folder
    Import the objects
#>

# TODO: Change to use Invoke-WebRequest
# TODO: Create a powershell module to include import and export functions
#     https://docs.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-script-module?view=powershell-6
#     Put the module into the following directory "/usr/local/share/powershell/Modules"
# TODO: Clean up pass / fail messages in imports

[CmdletBinding()]
param(
  [switch]$Import,
  [switch]$Export,
  [Parameter(Mandatory=$false)][string]$Url = "http://localhost:5601",
  [Parameter(Mandatory=$false)][string]$Path = "./dynamic/kibana/spaces",
  [Parameter(Mandatory=$false)][string]$Username = "elastic",
  [Parameter(Mandatory=$false)][string]$Password = "elastic"
)

$KibanaUrl = $Url.trim('\')

$secpasswd = ConvertTo-SecureString $Password -AsPlainText -Force
$ElasticCreds = New-Object System.Management.Automation.PSCredential ($Username, $secpasswd)

<#
  As of Jan 2020 the following elastic saved_objects types are exportable:
  [
    'config',
    'graph-workspace',
    'map',
    'canvas-workpad',
    'index-pattern',
    'visualization',
    'search',
    'dashboard',
    'url',
  ]

  https://github.com/elastic/kibana/issues/34862
#>
# Create a list of objects we current manage
[string[]]$ElasticObjectTypes = @(
  "index-pattern",
  "dashboard",
  "visualization",
  "canvas-workpad",
  "graph-workspace",
  "search",
  "url"
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
function Export-SavedObjects {
  Param(
    [parameter(Mandatory=$true)][string]$ExportObjectFolder
  )

  # Check we can communicate to kibana
  Wait-ForKibanaServer -Timeout 300

  Write-Host "Backup existing spaces folder: $ExportObjectFolder"
  $null = Backup-SpacesFolder -Path $ExportObjectFolder

  $ElasticSpaces = Get-KibanaSpacesList

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
      $ElasticObjects = Find-ElasticObjects $ElasticSpace $_

      # Don't do anything if there are no objects
      if ($($ElasticObjects.saved_objects).Length -eq 0) {
        Write-Host "No $_ objects in space: $ElasticSpace. Moving on..."
        Return
      }

      # Create a object type directory if it doesn't already exist
      if ( -Not (Test-Path -Path "$ExportObjectFolder/$ElasticSpace/$_" -PathType "Container") ) {
        $null = New-Item -ItemType Directory -Path "$ExportObjectFolder/$ElasticSpace/$_"
      }

      Export-SavedObjects "$ExportObjectFolder/$ElasticSpace/$_" $ElasticObjects
    }

    # Get the default index for the space and save it
    $ElasticDefaultIndex = Get-DefaultElasticIndex -Space $ElasticSpace
    If ($null -ne $ElasticDefaultIndex) {
      Write-Host "Default index for Space: $ElasticSpace is $ElasticDefaultIndex"
      $ElasticDefaultIndex | Out-File "$ExportObjectFolder/$ElasticSpace/default-index.txt"
    }
  }
}

<#
.SYNOPSIS
  Import all previously saved kibana objects
.PARAMETER ImportObjectFolder
  A folder containing the saved_object spaces you want to import
.NOTES
  Scan kibana/spaces folder structure
    For each folder in spaces folder
    Create a space
    For each folder in space folder
      Import the objects
#>
function Import-SavedObjects {
  Param(
    [parameter(Mandatory=$true)][string]$ImportObjectFolder
  )
  Wait-ForKibanaServer -Timeout 300

  # Import default space first
  # Iterate thru all the object types e.g. dashboard, index-pattern, visualisation etc.
  Get-ChildItem -Path "$ImportObjectFolder/default" -Directory | Foreach-Object {
    $ObjectType = $($_.Name)
    If ($ElasticObjectTypes.Contains($ObjectType)) {
      Write-Host "Importing $ObjectType into space: default"
      Import-ElasticObjectsFromFolder -Space "default" -Path $_
    }
  }
  # Set the default index for the default space
  Set-DefaultElasticIndex -FolderPath "$ImportObjectFolder/default"

  # Iterate thru all other folders in the spaces directory
  Get-ChildItem -Path $ImportObjectFolder -Directory -Exclude "default" | Foreach-Object {
    $ElasticSpace = $($_.Name)
    Write-Host "Creating elastic space: $ElasticSpace"
    $response = New-KibanaSpace $ElasticSpace
    Write-Host $response

    # Iterate thru all the object types e.g. dashboard, index-pattern, visualisation etc.
    Get-ChildItem -Path $Path/$ElasticSpace -Directory | Foreach-Object {
      $ObjectType = $($_.Name)
      If ($ElasticObjectTypes.Contains($ObjectType)) {
        Write-Host "Importing $ObjectType into space: $ElasticSpace"
        Import-ElasticObjectsFromFolder -Space $ElasticSpace -Path $_
      }
    }

    # Set the default index for the space
    Set-DefaultElasticIndex -FolderPath "$ImportObjectFolder/$ElasticSpace"
  }
}

# ---------------- Functions -----------------

<#
.SYNOPSIS
  Function to save the objects retrieved from kibana
.EXAMPLE
  Export-SavedObjects -Path "spaces/space" -Objects $Objects
#>
function Export-SavedObjects {
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
  Backup-SpacesFolder -Path "./dcomm/kibana/spaces"
#>
function Backup-SpacesFolder {
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
  New-ElasticPostRequest -Controller "spaces/space" -Headers $headers -Body $Body
#>
function New-ElasticGetRequest {
  Param(
    [parameter(Mandatory=$true)][string]$Controller,
    [parameter(Mandatory=$false)]$Headers = @{},
    [parameter(Mandatory=$false)][string]$Body = "{}"
  )

  $url = $KibanaUrl + '/' + $Controller
  $Headers.Add("kbn-xsrf", "true")

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
  Function to create issue an HTTP POST request to kibana
.EXAMPLE
  New-ElasticPostRequest -Controller "spaces/space" -Headers $headers -Body $Body
#>
function New-ElasticPostRequest {
  Param(
    [parameter(Mandatory=$true)][string]$Controller,
    [parameter(Mandatory=$true)]$Headers,
    [parameter(Mandatory=$true)]$Body
  )

  $url = $KibanaUrl + "/" + $Controller
  $Headers.Add("kbn-xsrf", "true")


  Write-Debug "POST Url: $url, Headers: $headers, Body:`r`n$Body"
  $response = Invoke-RestMethod -AllowUnencryptedAuthentication `
    -Uri $url `
    -Credential $ElasticCreds `
    -Method POST `
    -Headers $Headers `
    -Body $Body

    Write-Debug "New-ElasticPostRequest: $response"
    Return $response
}

<#
.SYNOPSIS
  Function to get the list of spaces from kibana
.EXAMPLE
  Get-KibanaSpacesList
#>
function Get-KibanaSpacesList {
  $Controller = "api/spaces/space"
  $headers=@{}
  $headers.Add("content-type", "application/json")

  $response = New-ElasticGetRequest -Controller $Controller -Headers $headers

  Write-Debug "Get-KibanaSpacesList: $response"
  return $response
}

<#
.SYNOPSIS
  Function to create a space within kibana for importing further saved objects.
  If the space is set to "default" then no action is taken as this space will
  always exist.
.EXAMPLE
  New-KibanaSpace -Space "Test"
#>
function New-KibanaSpace {
  Param(
    [parameter(Mandatory=$true)]$Space
  )

  # Only create non-default spaces
  If ($Space -ne "default") {
    If ((Test-Path -Path "$_/space-details.json")) {
      $ElasticSpace = Get-Content -Raw -Path "$_/space-details.json"
    } Else {
      # Set some space details if no file present
      $ElasticSpace = @"
{
  `"id`": `"$Space`",
  `"name`": `"$Space`",
  `"color`": `"#aabbcc`",
  `"disabledFeatures`": [ `"indexPatterns`",`"timelion`", `"graph`", `"monitoring`", `"ml`", `"apm`", `"canvas`",`"infrastructure`", `"siem`" ]}
"@
    }

    $Controller = "api/spaces/space"
    $headers=@{}
    $headers.Add("content-type", "application/json")

    Try {
      $response = New-ElasticPostRequest -Controller $Controller -Headers $headers -Body $ElasticSpace
    }
    Catch {
      # Ignore if space already exists
      If ($($_.Exception.Response.StatusCode) -ne 409) {
        Write-Host "Error: $($_.Exception.Message)"
      }
      $response = $null
    }
  }
  Write-Debug "New-KibanaSpace: $response"
  Return $response
}

<#
.SYNOPSIS
  Function to get the list of objects to save for a specific type fron kibana
.EXAMPLE
  Find-ElasticObjects -Controller "spaces/space" -Space "default" -Type "dashboard"
#>
function Find-ElasticObjects {
  Param(
    [parameter(Mandatory=$true)][string]$Space,
    [parameter(Mandatory=$true)][string]$Type
  )

  # Treat the default space differently
  $Controller = "api/saved_objects/_find?type=$Type&per_page=10000"
  if ( $Space -ne "default" ) {
    $Controller = "s/$Space/$Controller"
  }
  $headers=@{}
  $headers.Add("content-type", "application/json")

  Try {
    $response = New-ElasticGetRequest -Controller $Controller -Headers $headers
  } Catch {
    # Ignore if no objects found
    If ($($_.Exception.Response.StatusCode) -ne 404) {
      Write-Host "Error: $($_.Exception.Message)"
    }
    $response = $null
  }
  Write-Debug "Find-ElasticObjects: $response"
  return $response
}

<#
.SYNOPSIS
  Function to POST a previously saved object via an HHTP request to elastic
  for import
.EXAMPLE
  Import-ElasticObject -Space "default" -Body $BodyString
#>
function Import-ElasticObject {
  Param(
    [parameter(Mandatory=$true)][string]$Space,
    [parameter(Mandatory=$true)]$Body
  )

  $Controller = "api/saved_objects/_import?overwrite=true"
  if ( $Space -ne "default" ) {
    $Controller = "s/$Space/$Controller"
  }
  $headers=@{}
  $headers.Add("content-type", "multipart/form-data; boundary=WebBoundary1234")

  Try{
    $response = New-ElasticPostRequest -Controller $Controller -Headers $headers -Body $Body
  }
  Catch {
    Write-Host "Error: $($_.Exception.Message)"
    $response = $null
  }

  Write-Debug "Import-ElasticObject: $response"
  Return $response
}

<#
.SYNOPSIS
  Function to create an HTTP request body from a previously saved object into
  a suitable format for elastic to consume when importing
.EXAMPLE
  Import-ElasticObject -Path "./kibana/spaces/test/index-pattern/dcomm.json"
#>
function Set-SavedElasticObjectBody {
  Param(
    [parameter(Mandatory=$true)]$Path
  )

  Write-Debug "Set-SavedElasticObjectBody: $Path"
  # Kibana is very picky and needs any line feeds or carriage returns removed
  $filecontent = (Get-Content -Raw -Path "$Path").Replace("`r`n","").Replace("`n","").Replace("`r","")
  # Kibana also requires the filename in the request to end in .ndjson
  $filename = $($Path.Name).Replace(".json",".ndjson")
  # NOTE: Do not convert this body into a multiline string as it will fail on Windows hosts
  #       due to an extra <CR> being added in the .ps1 file by Windows!
  $ObjectBody = "--WebBoundary1234`r`nContent-Disposition: form-data; name=`"file`"; filename=`"$filename`"`r`nContent-Type: application/octet-stream`r`n`r`n$filecontent`r`n--WebBoundary1234--"

  Write-Debug "Set-SavedElasticObjectBody: `r`n$ObjectBody"
  Return $ObjectBody
}

<#
.SYNOPSIS
  Function to get the current default index from kibana
.EXAMPLE
  Get-DefaultElasticIndex
#>
function Get-DefaultElasticIndex {
  Param(
    [parameter(Mandatory=$true)]$Space
  )

  $Controller = "api/kibana/settings"
  if ( $Space -ne "default" ) {
    $Controller = "s/$Space/$Controller"
  }
  $headers=@{}
  $headers.Add("content-type", "application/json")

  Try {
    $response = New-ElasticGetRequest -Controller $Controller -Headers $headers
  } Catch {
    return $null
  }

  $index = $($response.settings.defaultIndex.userValue)
  return $index
}

<#
.SYNOPSIS
  Function to process and set a default index for a space if a default-index.txt
  file exists.
.EXAMPLE
  Set-DefaultElasticIndex -FolderPath "./kibana/spaces/test"
#>
function Set-DefaultElasticIndex {
  Param(
    [parameter(Mandatory=$true)]$FolderPath
  )

  # Set the default index if file is present
  $DefaultIndex = Get-ChildItem -Path $FolderPath -File -Filter "default-index.txt"
  if ($null -ne $DefaultIndex) {
    $ElasticIndex = (Get-Content -Raw -Path $DefaultIndex).Replace("`r`n","").Replace("`n","").Replace("`r","")
    $Space = Split-Path -Path $FolderPath -Leaf
    Write-Host "Setting default index for space: $Space to: $ElasticIndex"

    $Controller = "api/kibana/settings/defaultIndex"
    if ( $Space -ne "default" ) {
      $Controller = "s/$Space/$Controller"
    }

    $headers=@{}
    $headers.Add("content-type", "application/json")
    $body = "{`"value`":`"$ElasticIndex`"}"

    $response = New-ElasticPostRequest -Controller $Controller -Headers $headers -Body $body
    Write-Debug "Set-DefaultElasticIndex: $response"
  }
}

<#
.SYNOPSIS
  Function to process and import objects from a folder into elastic
.EXAMPLE
  Import-ElasticObjectsFromFolder -Space "Test" -Path "./kibana/spaces/test/visualization"
#>
function Import-ElasticObjectsFromFolder {
  Param(
    [parameter(Mandatory=$true)]$Space,
    [parameter(Mandatory=$true)]$Path
  )

  $ObjectType = $($_.Name)
  # Iterate thru the visualization definitions in the directory
  Get-ChildItem -Path $Path -File -Filter "*.json" | Foreach-Object {
    $ObjectName = $($_.Name)

    $Body = Set-SavedElasticObjectBody $_
    Write-Host -NoNewline "Space: $Space, $ObjectType : $ObjectName, Response: "
    $response = Import-ElasticObject -Space $Space -Body $Body
    If ($response.success -eq "True") {
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
  If (0 -eq Get-KibanaServerStatus) {Write-Host "ready"}
#>
function Get-KibanaServerStatus {
  Try {
    $status = New-ElasticGetRequest -Controller "api/status"
    If ($($status.status.overall.state) -eq "green") {
      $response = @{ "status" = 0; "description" = "ready"}
    } Else {
      $response = @{ "status" = -1; "description" = $($status.status.overall.state)}
    }
  } Catch {
    $response = @{ "status" = -2; "description" = $($_.Exception.Message)}
  }
  Write-Debug "Get-KibanaServerStatus: $response"
  return $response
}

<#
.SYNOPSIS
  Check kibana server status and wait until it is ready to accept API
  commnds or times out
.PARAMETER Timeout
  waittime in seconds to wait for server ready (default: 25)
.EXAMPLE
  Wait-ForKibanaServer -Timeout 25
#>
function Wait-ForKibanaServer {
  Param(
    [parameter(Mandatory=$true)][int]$Timeout
  )
  $waittime = New-TimeSpan -Seconds $Timeout
  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  $loopcount = 0
  while ((Get-KibanaServerStatus).status -ne 0 -and $stopwatch.Elapsed -lt $waittime) {
    if ($loopcount -eq 0) {
      Write-Host -NoNewline "Waiting for kibana server"
    } else {
      Write-Host -NoNewline "."
    }
    $loopcount++
    Start-Sleep -Seconds 5
  }

  If ($stopwatch.elapsed -ge $waittime) {
    Write-Host "`nUnable to contact kibana server. Exiting..."
    Exit -1
  } elseif ($loopcount -gt 0) {
    Write-Host "  Done"
  }
  If ($loopcount -ge 1) {
    Start-Sleep 10
  }
}

# ---------------- Main Code -----------------

If ($Export) {
  Write-Host "Exporting..."
  Export-SavedObjects -ExportObjectFolder $Path
} Else {
  Write-Host "Importing"
  Import-SavedObjects -ImportObjectFolder $Path
}
