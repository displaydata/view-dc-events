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


param(
  [switch]$Import,
  [switch]$Export,
  [Parameter(Mandatory=$false)][string]$Url = "http://localhost:5601",
  [Parameter(Mandatory=$false)][string]$Path = "./dynamic/kibana/spaces",
  [Parameter(Mandatory=$false)][string]$Username = "elastic",
  [Parameter(Mandatory=$false)][string]$Password = "elastic"
)

$global:KibanaUrl = $Url
$secpasswd = ConvertTo-SecureString $Username -AsPlainText -Force
$global:ElasticCreds = New-Object System.Management.Automation.PSCredential ($Password, $secpasswd)

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
[string[]]$global:ElasticObjectTypes = @(
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
function Export-Saved-Objects {
  Param(
    [parameter(Mandatory=$true)][string]$ExportObjectFolder
  )

  # Check we can communicate to kibana
  WaitForKibanaServer -Timeout 30

  Write-Host "Backup existing spaces folder: $ExportObjectFolder"
  $null = BackupSpacesFolder -Path $ExportObjectFolder

  $ElasticSpaces = ElasticGetSpaces

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
function Import-Saved-Objects {
  Param(
    [parameter(Mandatory=$true)][string]$ImportObjectFolder
  )
  WaitForKibanaServer -Timeout 30

  # Import default space first
  # Iterate thru all the object types e.g. dashboard, index-pattern, visualisation etc.
  Get-ChildItem -Path "$ImportObjectFolder/default" -Directory | Foreach-Object {
    $ObjectType = $($_.Name)
    If ($ElasticObjectTypes.Contains($ObjectType)) {
      Write-Host "Importing $ObjectType into space: default"
      ElasticImportObjectsFromFolder -Space "default" -Path $_
    }
  }
  # Set the default index for the default space
  ElasticSetDefaultIndex -FolderPath "$ImportObjectFolder/default"

  # Iterate thru all other folders in the spaces directory
  Get-ChildItem -Path $ImportObjectFolder -Directory -Exclude "default" | Foreach-Object {
    $ElasticSpace = $($_.Name)
    Write-Host "Creating elastic space: $ElasticSpace"
    $response = ElasticCreateSpace $ElasticSpace
    Write-Host $response

    # Iterate thru all the object types e.g. dashboard, index-pattern, visualisation etc.
    Get-ChildItem -Path $Path/$ElasticSpace -Directory | Foreach-Object {
      $ObjectType = $($_.Name)
      If ($ElasticObjectTypes.Contains($ObjectType)) {
        Write-Host "Importing $ObjectType into space: $ElasticSpace"
        ElasticImportObjectsFromFolder -Space $ElasticSpace -Path $_
      }
    }

    # Set the default index for the space
    ElasticSetDefaultIndex -FolderPath "$ImportObjectFolder/$ElasticSpace"
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
  ElasticPostRequest -Controller "spaces/space" -Headers $headers -Body $Body
#>
function ElasticGetRequest {
  Param(
    [parameter(Mandatory=$true)][string]$Controller,
    [parameter(Mandatory=$false)]$Headers = @{},
    [parameter(Mandatory=$false)][string]$Body = "{}"
  )

  $url = $global:KibanaUrl + '/' + $Controller
  $Headers.Add("kbn-xsrf", "true")
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
  Function to create issue an HTTP POST request to kibana
.EXAMPLE
  ElasticPostRequest -Controller "spaces/space" -Headers $headers -Body $Body
#>
function ElasticPostRequest {
  Param(
    [parameter(Mandatory=$true)][string]$Controller,
    [parameter(Mandatory=$true)]$Headers,
    [parameter(Mandatory=$true)]$Body
  )

  $url = $global:KibanaUrl + "/" + $Controller
  $Headers.Add("kbn-xsrf", "true")


  $response = Invoke-RestMethod -AllowUnencryptedAuthentication `
      -Uri $url `
      -Credential $global:ElasticCreds `
      -Method POST `
      -Headers $Headers `
      -Body $Body

  Return $response
}

<#
.SYNOPSIS
  Function to get the list of spaces from kibana
.EXAMPLE
  ElasticGetSpaces
#>
function ElasticGetSpaces {
  $Controller = "api/spaces/space"
  $headers=@{}
  $headers.Add("content-type", "application/json")

  $response = ElasticGetRequest -Controller $Controller -Headers $headers

  return $response
}

<#
.SYNOPSIS
  Function to create a space within kibana for importing further saved objects.
  If the space is set to "default" then no action is taken as this space will
  always exist.
.EXAMPLE
  ElasticCreateSpace -Space "Test"
#>
function ElasticCreateSpace {
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
      $response = ElasticPostRequest -Controller $Controller -Headers $headers -Body $ElasticSpace
    }
    Catch {
      # Ignore if space already exists
      If ($($_.Exception.Response.StatusCode) -ne 409) {
        Write-Host "Error: $($_.Exception.Message)"
      }
      $response = $null
    }
  }

  Return $response
}

<#
.SYNOPSIS
  Function to get the list of objects to save for a specific type fron kibana
.EXAMPLE
  ElasticFindObjects -Controller "spaces/space" -Space "default" -Type "dashboard"
#>
function ElasticFindObjects {
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
    $response = ElasticGetRequest -Controller $Controller -Headers $headers
  } Catch {
    # Ignore if no objects found
    If ($($_.Exception.Response.StatusCode) -ne 404) {
      Write-Host "Error: $($_.Exception.Message)"
    }
    $response = $null
  }
  return $response
}

<#
.SYNOPSIS
  Function to POST a previously saved object via an HHTP request to elastic
  for import
.EXAMPLE
  ElasticImportObject -Space "default" -Body $BodyString
#>
function ElasticImportObject {
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
    $response = ElasticPostRequest -Controller $Controller -Headers $headers -Body $Body
  }
  Catch {
    Write-Host "Error: $($_.Exception.Message)"
    $response = $null
  }

  Return $response
}

<#
.SYNOPSIS
  Function to create an HTTP request body from a previously saved object into
  a suitable format for elastic to consume when importing
.EXAMPLE
  ElasticImportObject -Path "./kibana/spaces/test/index-pattern/dcomm.json"
#>
function ElasticSetSavedObjectBody {
  Param(
    [parameter(Mandatory=$true)]$Path
  )

  # Kibana is very picky and needs any line feeds or carriage returns removed
  $filecontent = (Get-Content -Raw -Path "$Path").Replace("`r`n","").Replace("`n","")
  # Kibana also requires the filename in the request to end in .ndjson
  $filename = $($Path.Name).Replace(".json",".ndjson")
  $ObjectBody = @"
--WebBoundary1234`r
Content-Disposition: form-data; name=`"file`"; filename=`"$filename`"`r
Content-Type: application/octet-stream`r
`r
$filecontent`r
--WebBoundary1234--
"@

  Return $ObjectBody
}

<#
.SYNOPSIS
  Function to get the current default index from kibana
.EXAMPLE
  ElasticGetDefaultIndex
#>
function ElasticGetDefaultIndex {
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
    $response = ElasticGetRequest -Controller $Controller -Headers $headers
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
  ElasticSetDefaultIndex -FolderPath "./kibana/spaces/test"
#>
function ElasticSetDefaultIndex {
  Param(
    [parameter(Mandatory=$true)]$FolderPath
  )

  # Set the default index if file is present
  $DefaultIndex = Get-ChildItem -Path $FolderPath -File -Filter "default-index.txt"
  if ($null -ne $DefaultIndex) {
    $ElasticIndex = (Get-Content -Raw -Path $DefaultIndex).Replace("`r`n","").Replace("`n","")
    $Space = Split-Path -Path $FolderPath -Leaf
    Write-Host "Setting default index for space: $Space to: $ElasticIndex"

    $Controller = "api/kibana/settings/defaultIndex"
    if ( $Space -ne "default" ) {
      $Controller = "s/$Space/$Controller"
    }

    $headers=@{}
    $headers.Add("content-type", "application/json")
    $body = "{`"value`":`"$ElasticIndex`"}"

    $response = ElasticPostRequest -Controller $Controller -Headers $headers -Body $body
  }
}

<#
.SYNOPSIS
  Function to process and import objects from a folder into elastic
.EXAMPLE
  ElasticImportObjectsFromFolder -Space "Test" -Path "./kibana/spaces/test/visualization"
#>
function ElasticImportObjectsFromFolder {
  Param(
    [parameter(Mandatory=$true)]$Space,
    [parameter(Mandatory=$true)]$Path
  )

  $ObjectType = $($_.Name)
  # Iterate thru the visualization definitions in the directory
  Get-ChildItem -Path $Path -File -Filter "*.json" | Foreach-Object {
    $ObjectName = $($_.Name)

    $Body = ElasticSetSavedObjectBody $_
    Write-Host -NoNewline "Space: $Space, $ObjectType : $ObjectName, Response: "
    $response = ElasticImportObject -Space $Space -Body $Body
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
  If (0 -eq GetKibanaServerStatus) {Write-Host "ready"}
#>
function GetKibanaServerStatus {
  Try {
    $null = ElasticGetRequest -Controller "api/status"
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
  WaitForKibanaServer -Timeout 25
#>
function WaitForKibanaServer {
  Param(
    [parameter(Mandatory=$false)][int]$Timeout
  )
  $waittime = New-TimeSpan -Seconds $Timeout
  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  $loopcount = 0
  while ((GetKibanaServerStatus).status -ne 0 -and $stopwatch.elapsed -lt $waittime) {
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
}

# ---------------- Main Code -----------------

If ($Export) {
  Write-Host "Exporting..."
  Export-Saved-Objects -ExportObjectFolder $Path
} Else {
  Write-Host "Importing"
  Import-Saved-Objects -ImportObjectFolder $Path
}
