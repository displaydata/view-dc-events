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
param(
  [Parameter(Mandatory=$false)][string]$Url = "http://localhost:9200",
  [Parameter(Mandatory=$false)][string]$Path = "./elasticsettings/",
  [Parameter(Mandatory=$false)][string]$Username = "elastic",
  [Parameter(Mandatory=$false)][string]$Password = "elastic"
)

Import-Module $PSScriptRoot/modules/elastic.psm1 -Verbose

Import-ElasticSettingsToUrl -Url $Url -Path $Path -Username $Username -Password $Password
