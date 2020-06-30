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

[CmdletBinding()]
param(
  [switch]$Import,
  [switch]$Export,
  [Parameter(Mandatory=$false)][string]$Url = "http://localhost:5601",
  [Parameter(Mandatory=$false)][string]$Path = "/home/njones/Projects/view-dc-events/docker/elasticsearch/kibanasettings/spaces",
  [Parameter(Mandatory=$false)][string]$Username = "elastic",
  [Parameter(Mandatory=$false)][string]$Password = "elastic"
)

Import-Module $PSScriptRoot/modules/elastic.psm1 -Verbose

If ($Export) {
  Write-Host "Exporting..."
  Export-KibanaSavedObjects -Url $Url -Path $Path -Username $Username -Password $Password
} Else {
  Write-Host "Importing..."
  Import-KibanaSavedObjects -Url $Url -Path $Path -Username $Username -Password $Password
}
