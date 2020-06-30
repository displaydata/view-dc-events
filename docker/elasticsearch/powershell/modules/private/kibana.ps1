<#
.SYNOPSIS
  Script enables import and export of Kibana "saved-objects" heirachy
.PARAMETER Import
  Declare to import a set of previously saved objects. Mutually exclusive with -Export
.PARAMETER Export
  Declare to export a set of Kibana saved_objects. Mutually exclusive with -Import
.PARAMETER Url
  URI of the kibana api endpoint e.g. "http://localhost:5601" (optional)
.PARAMETER Path
  Path to the directory containing the objects to import (optional)
.PARAMETER Username
  Kibana user name (optional)
.PARAMETER Password
  Kibana password (optional)

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

function Import-KibanaSettings {
    param(
        [switch]$Import,
        [switch]$Export,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Url,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Path,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Username,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Password
      )
        
    $global:KibanaUrl = ([Uri]$Url).AbsoluteUri
    $global:KibanaUrl = $global:KibanaUrl.trim('/')
    
    # Kibana's ElasticCloud API endpoint will NOT cope with -Credential in Invoke-RestMethod requests
    # This is because it is anticipating the Authorization header in an initial requests, something that -Credential does not do.
    # The following setting should also be set in the Kibana.yml via the ElasticCloud UI xpack.security.authc.providers: [basic]
    # Details of Kibana API and auth are here https://www.elastic.co/guide/en/kibana/current/using-api.html

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))

    $global:AuthHeader = @{Authorization=("Basic {0}" -f $base64AuthInfo)}
    If ($Export) {
        Write-Host "Exporting..."
        Export-AllSavedObjects -ExportObjectFolder $Path
      } Else {
        Write-Host "Importing"
        Import-AllSavedObjects -ImportObjectFolder $Path
      }
      
  }
  
<#
  As of Jan 2020 the following Kibana saved_objects types are exportable:
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
[string[]]$global:KibanaObjectTypes = @(
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
function Export-AllSavedObjects {
  Param(
    [parameter(Mandatory=$true)][string]$ExportObjectFolder
  )

  # Check we can communicate to kibana
  Wait-ForKibanaServer -Timeout 300

  Write-Host "Backup existing spaces folder: $ExportObjectFolder"
  $null = Backup-SpacesFolder -Path $ExportObjectFolder

  $KibanaSpaces = Get-KibanaSpacesList

  # Iterate thru the spaces and save the objects
  $KibanaSpaces | ForEach-Object {
    $KibanaSpace = $($_.id)
    Write-Host "Saving Kibana Space: $KibanaSpace"

    # Create a space directory if it doesn't already exist
    if ( -Not (Test-Path -Path "$ExportObjectFolder/$KibanaSpace" -PathType "Container") ) {
      $null = New-Item -ItemType Directory -Path "$ExportObjectFolder/$KibanaSpace"
    }

    # Save space details
    Write-Host "Saving spaces details: $ExportObjectFolder/$KibanaSpace/space-details.json"
    $_ | ConvertTo-Json -depth 100 | Out-File "$ExportObjectFolder/$KibanaSpace/space-details.json"

    # Get the objects we are interested in and save them
    $KibanaObjectTypes | ForEach-Object {
      $KibanaObjects = Find-KibanaObjects $KibanaSpace $_

      # Don't do anything if there are no objects
      if ($($KibanaObjects.saved_objects).Length -eq 0) {
        Write-Host "No $_ objects in space: $KibanaSpace. Moving on..."
        Return
      }

      # Create a object type directory if it doesn't already exist
      if ( -Not (Test-Path -Path "$ExportObjectFolder/$KibanaSpace/$_" -PathType "Container") ) {
        $null = New-Item -ItemType Directory -Path "$ExportObjectFolder/$KibanaSpace/$_"
      }

      Export-SavedObjects "$ExportObjectFolder/$KibanaSpace/$_" $KibanaObjects
    }

    # Get the default index for the space and save it
    $KibanaDefaultIndex = Get-DefaultKibanaIndex -Space $KibanaSpace
    If ($null -ne $KibanaDefaultIndex) {
      Write-Host "Default index for Space: $KibanaSpace is $KibanaDefaultIndex"
      $KibanaDefaultIndex | Out-File "$ExportObjectFolder/$KibanaSpace/default-index.txt"
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
function Import-AllSavedObjects {
  Param(
    [parameter(Mandatory=$true)][string]$ImportObjectFolder
  )
  Wait-ForKibanaServer -Timeout 300

  # Import default space first
  # Iterate thru all the object types e.g. dashboard, index-pattern, visualisation etc.
  Get-ChildItem -Path "$ImportObjectFolder/default" -Directory | Foreach-Object {
    $ObjectType = $($_.Name)
    If ($KibanaObjectTypes.Contains($ObjectType)) {
      Write-Host "Importing $ObjectType into space: default"
      Import-KibanaObjectsFromFolder -Space "default" -Path $_
    }
  }
  # Set the default index for the default space
  Set-DefaultKibanaIndex -FolderPath "$ImportObjectFolder/default"

  # Iterate thru all other folders in the spaces directory
  Get-ChildItem -Path $ImportObjectFolder -Directory -Exclude "default" | Foreach-Object {
    $KibanaSpace = $($_.Name)
    Write-Host "Creating Kibana space: $KibanaSpace"
    $response = New-KibanaSpace $KibanaSpace
    Write-Host $response

    # Iterate thru all the object types e.g. dashboard, index-pattern, visualisation etc.
    Get-ChildItem -Path $Path/$KibanaSpace -Directory | Foreach-Object {
      $ObjectType = $($_.Name)
      If ($KibanaObjectTypes.Contains($ObjectType)) {
        Write-Host "Importing $ObjectType into space: $KibanaSpace"
        Import-KibanaObjectsFromFolder -Space $KibanaSpace -Path $_
      }
    }

    # Set the default index for the space
    Set-DefaultKibanaIndex -FolderPath "$ImportObjectFolder/$KibanaSpace"
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

  Rename-Item -Path $Path -NewName "$BackupFolderName" -ErrorAction:Ignore
  $null = New-Item -ItemType Directory -Force -Path $Path

}

<#
.SYNOPSIS
  Function to issue an HTTP GET request to kibana
.EXAMPLE
  New-KibanaPostRequest -Controller "spaces/space" -Headers $headers -Body $Body
#>
function New-KibanaGetRequest {
  Param(
    [parameter(Mandatory=$true)][string]$Controller,
    [parameter(Mandatory=$false)]$Headers = @{}
  )

  $url = $KibanaUrl + '/' + $Controller
  $Headers.Add("kbn-xsrf", "true") # <== NOTE: should not be needed for GET
  $Headers = $Headers + $AuthHeader

  Write-Debug "GET Url: $url, Headers: $headers, Body:`r`n$Body"
  $response = Invoke-RestMethod -Uri $url -Method GET -Headers $Headers

  Write-Debug "New-KibanaGetRequest: $response"
  Return $response
}

<#
.SYNOPSIS
  Function to create issue an HTTP POST request to kibana
.EXAMPLE
  New-KibanaPostRequest -Controller "spaces/space" -Headers $headers -Body $Body
#>
function New-KibanaPostRequest {
  Param(
    [parameter(Mandatory=$true)][string]$Controller,
    [parameter(Mandatory=$true)]$Headers,
    [parameter(Mandatory=$true)]$Body
  )

  $url = $KibanaUrl + "/" + $Controller
  $Headers.Add("kbn-xsrf", "true")
  $Headers = $Headers + $AuthHeader

  Write-Debug "POST Url: $url, Headers: $headers, Body:`r`n$Body"
  $response = Invoke-RestMethod -Uri $url -Method POST -Headers $Headers -Body $Body

    Write-Debug "New-KibanaPostRequest: $response"
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

  $response = New-KibanaGetRequest -Controller $Controller -Headers $Headers

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
      $KibanaSpace = Get-Content -Raw -Path "$_/space-details.json"
    } Else {
      # Set some space details if no file present
      $KibanaSpace = @"
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
      $response = New-KibanaPostRequest -Controller $Controller -Headers $Headers -Body $KibanaSpace
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
  Find-KibanaObjects -Controller "spaces/space" -Space "default" -Type "dashboard"
#>
function Find-KibanaObjects {
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
    $response = New-KibanaGetRequest -Controller $Controller -Headers $Headers
  } Catch {
    # Ignore if no objects found
    If ($($_.Exception.Response.StatusCode) -ne 404) {
      Write-Host "Error: $($_.Exception.Message)"
    }
    $response = $null
  }
  Write-Debug "Find-KibanaObjects: $response"
  return $response
}

<#
.SYNOPSIS
  Function to POST a previously saved object via an HHTP request to Kibana
  for import
.EXAMPLE
  Import-KibanaObject -Space "default" -Body $BodyString
#>
function Import-KibanaObject {
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
    $response = New-KibanaPostRequest -Controller $Controller -Headers $Headers  -Body $Body
  }
  Catch {
    Write-Host "Error: $($_.Exception.Message)"
    $response = $null
  }

  Write-Debug "Import-KibanaObject: $response"
  Return $response
}

<#
.SYNOPSIS
  Function to create an HTTP request body from a previously saved object into
  a suitable format for Kibana to consume when importing
.EXAMPLE
  Import-KibanaObject -Path "./kibana/spaces/test/index-pattern/dcomm.json"
#>
function Set-SavedKibanaObjectBody {
  Param(
    [parameter(Mandatory=$true)]$Path
  )

  Write-Debug "Set-SavedKibanaObjectBody: $Path"
  # Kibana is very picky and needs any line feeds or carriage returns removed
  $filecontent = (Get-Content -Raw -Path "$Path").Replace("`r`n","").Replace("`n","").Replace("`r","")
  # Kibana also requires the filename in the request to end in .ndjson
  $filename = $($Path.Name).Replace(".json",".ndjson")
  # NOTE: Do not convert this body into a multiline string as it will fail on Windows hosts
  #       due to an extra <CR> being added in the .ps1 file by Windows!
  $ObjectBody = "--WebBoundary1234`r`nContent-Disposition: form-data; name=`"file`"; filename=`"$filename`"`r`nContent-Type: application/octet-stream`r`n`r`n$filecontent`r`n--WebBoundary1234--"

  Write-Debug "Set-SavedKibanaObjectBody: `r`n$ObjectBody"
  Return $ObjectBody
}

<#
.SYNOPSIS
  Function to get the current default index from kibana
.EXAMPLE
  Get-DefaultKibanaIndex
#>
function Get-DefaultKibanaIndex {
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
    $response = New-KibanaGetRequest -Controller $Controller -Headers $headers
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
  Set-DefaultKibanaIndex -FolderPath "./kibana/spaces/test"
#>
function Set-DefaultKibanaIndex {
  Param(
    [parameter(Mandatory=$true)]$FolderPath
  )

  # Set the default index if file is present
  $DefaultIndex = Get-ChildItem -Path $FolderPath -File -Filter "default-index.txt"
  if ($null -ne $DefaultIndex) {
    $KibanaIndex = (Get-Content -Raw -Path $DefaultIndex).Replace("`r`n","").Replace("`n","").Replace("`r","")
    $Space = Split-Path -Path $FolderPath -Leaf
    Write-Host "Setting default index for space: $Space to: $KibanaIndex"

    $Controller = "api/kibana/settings/defaultIndex"
    if ( $Space -ne "default" ) {
      $Controller = "s/$Space/$Controller"
    }

    $headers=@{}
    $headers.Add("content-type", "application/json")
    $body = "{`"value`":`"$KibanaIndex`"}"

    $response = New-KibanaPostRequest -Controller $Controller -Headers $headers -Body $body
    Write-Debug "Set-DefaultKibanaIndex: $response"
  }
}

<#
.SYNOPSIS
  Function to process and import objects from a folder into Kibana
.EXAMPLE
  Import-KibanaObjectsFromFolder -Space "Test" -Path "./kibana/spaces/test/visualization"
#>
function Import-KibanaObjectsFromFolder {
  Param(
    [parameter(Mandatory=$true)]$Space,
    [parameter(Mandatory=$true)]$Path
  )

  $ObjectType = $($_.Name)
  # Iterate thru the visualization definitions in the directory
  Get-ChildItem -Path $Path -File -Filter "*.json" | Foreach-Object {
    $ObjectName = $($_.Name)

    $Body = Set-SavedKibanaObjectBody $_
    Write-Host -NoNewline "Space: $Space, $ObjectType : $ObjectName, Response: "
    $response = Import-KibanaObject -Space $Space -Body $Body
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
    $status = New-KibanaGetRequest -Controller "api/status"
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

#If ($Export) {
#  Write-Host "Exporting..."
#  Export-AllSavedObjects -ExportObjectFolder $Path
#} Else {
#  Write-Host "Importing"
#  Import-AllSavedObjects -ImportObjectFolder $Path
#}
