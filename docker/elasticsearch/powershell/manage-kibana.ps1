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

# TODO: Create a powershell module to include import and export functions
#     https://docs.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-script-module?view=powershell-6
#     Put the module into the following directory "/usr/local/share/powershell/Modules"
# TODO: Clean up pass / fail messages in imports
# TODO: Tidy up use of $Header expression in GET requests
# TODO: Combine this with manage-elastic.ps1

[CmdletBinding()]
param(
  [switch]$Import,
  [switch]$Export,
  [Parameter(Mandatory=$false)][string]$Url = "http://localhost:5601",
  [Parameter(Mandatory=$false)][string]$Path = "./kibanasettings/spaces",
  [Parameter(Mandatory=$false)][string]$Username = "elastic",
  [Parameter(Mandatory=$false)][string]$Password = "elastic"
)

Import-Module $PSScriptRoot/modules/elastic.psm1 -Verbose

Import-KibanaSavedObjects -Url $Url -Path $Path -Username $Username -Password $Password
